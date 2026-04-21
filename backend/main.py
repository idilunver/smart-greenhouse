import firebase_admin
from firebase_admin import credentials, db
import time
import math
import os
import google.generativeai as genai
from dotenv import load_dotenv

# --- Çevresel Değişkenleri Yükle ---
load_dotenv()

# --- Yapılandırma (Çevresel Değişkenlerden) ---
CERT_PATH = os.getenv("SERVICE_ACCOUNT_KEY_PATH", "serviceAccountKey.json")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
FIREBASE_DB_URL = os.getenv("FIREBASE_DATABASE_URL")

# --- KOTA YÖNETİMİ: Zaman Eşikleri ---
AI_COOLDOWN = 300           # Normal: en fazla saatte ~12 Gemini isteği
CRITICAL_AI_COOLDOWN = 60   # Kritik: en fazla saatte ~60 Gemini isteği
HISTORY_INTERVAL = 600      # 10 dakikada bir geçmiş kayıt
PROCESSING_INTERVAL = 30    # En az 30 saniyede bir backend işlemesi

last_ai_time = 0
last_history_time = 0
last_processing_time = 0
last_known_temp = None       # Delta tabanlı tetikleme için
cached_settings = {}         # Settings verisini önbellekte tutmak için

# Gemini Kurulumu - Kota dostu model
genai.configure(api_key=GEMINI_API_KEY)
model = genai.GenerativeModel('gemini-flash-lite-latest')

def initialize_firebase():
    if not firebase_admin._apps:
        abs_cert_path = os.path.abspath(CERT_PATH)
        if not os.path.exists(abs_cert_path):
            print(f"HATA: {abs_cert_path} bulunamadı! Lütfen Service Account JSON dosyasını kontrol edin.")
            return False
        
        cred = credentials.Certificate(abs_cert_path)
        firebase_admin.initialize_app(cred, {
            'databaseURL': FIREBASE_DB_URL
        })
    print(">>> AI Destekli Sera Backend Sistemi (Cloud Mode) Aktif...")
    return True

def calculate_vpd(temp, humidity):
    """VPD (Buhar Basıncı Açığı) hesaplar."""
    svp = 0.61078 * math.exp((17.27 * temp) / (temp + 237.3))
    avp = svp * (humidity / 100)
    return round(svp - avp, 2)

def get_gemini_advice(temp, hum, soil, vpd, et_rate, plants):
    """Verileri ve geçmiş trendleri Gemini'ye gönderir."""
    clean_plants = [p.split(" ")[0] for p in plants] if plants else ["genel bitkiler"]
    plants_text = ", ".join(clean_plants)
    
    # Trend analizi için geçmişi çek
    trend_text = "Stabil"
    try:
        history = db.reference('Greenhouse/History').order_by_child('timestamp').limit_to_last(10).get()
        if history and len(history) >= 2:
            items = list(history.values())
            temp_diff = items[-1]['temp'] - items[0]['temp']
            if temp_diff > 1: trend_text = "Yükselme eğiliminde (Isınıyor)"
            elif temp_diff < -1: trend_text = "Düşme eğiliminde (Soğuyor)"
            else: trend_text = "Stabil seyrediyor"
    except: pass

    prompt = f"""
    Sen bu akıllı seranın yaşayan zekası ve dijital koruyucususun. Bir ziraat uzmanının bilgisine 
    ve bir doğa dostunun sıcaklığına sahipsin. Bitkileri seven, onların dilinden anlayan bir yardımcı gibi konuş.
    
    Şu an yetiştirilen bitkiler: {plants_text}
    Veriler: Sıcaklık {temp}°C (Trend: {trend_text}), Nem %{hum}, Toprak Nemi %{soil}, VPD: {vpd} kPa.

    Kritik Kurallar ve Talimatlar:
    1. Sensör Hatası Sensörü: Eğer herhangi bir sensör verisi 0, çok düşük veya mantıksız derecede yüksekse (örn: Sıcaklık 0 veya 99, Nem 0), doğrudan şu uyarıyı yap: "Sensör bağlantılarında bir hata algıladım, lütfen kabloları kontrol et."
    2. Bitkiye Özel Yaklaşım: '{plants_text}' bitkisinin genel karakteristiklerini düşün (örn. marul serinliği sever, domates ışığı ve sıcağı). Yorumunu o bitkiye tam uyacak şekilde yap.
    3. Kişi isimleri kullanma. Samimi ("Selam", "Merhaba" vb.) bir giriş yap.
    4. Teknik verileri doğalca yedir ama sadece durum için en kritik olan 1 veya 2 veriyi seç, hepsini sayma.
    5. UI Tasarım Kuralı: Cevabı KESİNLİKLE EN FAZLA 2 KISA CÜMLE ile sınırla. Kesinlikle fazla uzatma.
    """
    try:
        response = model.generate_content(prompt)
        return response.text.strip()
    except Exception as e:
        print(f"Gemini Hatası (get_gemini_advice): {e}")
        if "429" in str(e):
            return "Günlük AI kotası doldu. Veriler normal şekilde izlenmeye devam ediyor."
        return "Veriler analiz ediliyor, lütfen trendi takip edin."

# --- Bitki Kütüphanesi & İdeal Değerler ---
PLANT_RULES = {
    "Domates": {"temp": (18, 28), "hum": (60, 80), "soil": (40, 60)},
    "Biber": {"temp": (20, 30), "hum": (50, 70), "soil": (30, 50)},
    "Marul": {"temp": (15, 22), "hum": (70, 90), "soil": (50, 70)},
    "Salatalık": {"temp": (22, 30), "hum": (70, 90), "soil": (40, 60)},
    "genel bitkiler": {"temp": (20, 30), "hum": (50, 80), "soil": (30, 60)}
}

sensor_state = {
    'temp_inner': 25.0,
    'humidity_inner': 50.0,
    'soil_moisture': 40.0,
    'light_lux': 0.0,
    'CO2': 0.0
}

def handle_sensor_change(event):
    global last_ai_time, last_history_time, last_processing_time, last_known_temp, sensor_state
    
    print(f"[*] Firebase'den tetik geldi! Path: {event.path}, Data: {event.data}", flush=True)

    if event.data is None:
        return

    # Eğer Data dict ise, tüm değerler gelmiş / güncellenmiş demektir
    if isinstance(event.data, dict):
        for key, value in event.data.items():
            if key in sensor_state:
                sensor_state[key] = float(value)
    # Eğer Data dict değilse, spesifik bir yol (path) gelmiş demektir (ör: /temp_inner)
    else:
        path_key = event.path.strip("/")
        if path_key in sensor_state:
            sensor_state[path_key] = float(event.data)

    # Güncel değerleri kullan
    temp = sensor_state['temp_inner']
    hum = sensor_state['humidity_inner']
    soil = sensor_state['soil_moisture']

    # --- VERİ DOĞRULAMA & GÜVENLİ MOD (FAIL-SAFE) ---
    if temp < 0 or temp > 60 or hum < 0 or hum > 100 or soil < 0 or soil > 100:
        print(f"[!!!] KRİTİK HATA: Anormal veri tespit edildi (Temp: {temp}, Hum: {hum}, Soil: {soil}). Güvenli moda geçiliyor...")
        try:
            db.reference('Greenhouse/System_Status').update({'error_log': 'SENSOR_ERROR'})
            # Fan, pompa ve ışığı acil kapat (0 veya False yollanabilir)
            db.reference('Greenhouse/Controls').update({'fan': 0, 'pump': 0, 'light': 0})
        except Exception as e:
            pass
        return  # Hatalı veri ile işlem yapmamak için fonksiyonu sonlandır
    else:
        # Sensör okumaları normale döndüğünde hata bayrağını temizle
        try:
            db.reference('Greenhouse/System_Status').update({
                'error_log': 'No errors',
                'is_online': True,
                'last_ping': time.strftime('%d-%m-%Y %H:%M')
            })
        except:
            pass



    # ─────────────────────────────────────────────────────
    # KOTA YÖNETİMİ - KATMAN 2: İşleme Throttle
    # Kritik durum her zaman işlenir. Normal durumda 30sn bekleriz.
    # ─────────────────────────────────────────────────────
    is_critical = (temp > 32 or soil < 20 or hum < 40)
    current_time = time.time()

    if not is_critical and (current_time - last_processing_time < PROCESSING_INTERVAL):
        # Kritik değil ve 30 saniye dolmadı — bu tetiklenmeyi atla
        return

    last_processing_time = current_time
    print(f"\n--- Veri İşleniyor ({time.strftime('%H:%M:%S')}) ---")

    # Güncel Ayarları Çek (Önbellekten)
    global cached_settings
    selected_plants = cached_settings.get('plants', [])
    auto_mode = cached_settings.get('auto_mode', False)

    # Matematiksel Hesaplamalar
    vpd = calculate_vpd(temp, hum)
    et_rate = round(vpd * 0.4, 2)

    actions = {}
    # Akıllı Otomasyon (The Brain)
    if auto_mode:
        plant_name = "genel bitkiler"
        if selected_plants and isinstance(selected_plants, list) and len(selected_plants) > 0:
            first_plant = str(selected_plants[0])
            plant_name = first_plant.split(" ")[0]

        target_rule = PLANT_RULES.get(plant_name, PLANT_RULES["genel bitkiler"])
        controls_ref = db.reference('Greenhouse/Controls')

        # Sıcaklık Kontrolü (Fan)
        if temp > target_rule["temp"][1]: actions['fan'] = True
        elif temp < target_rule["temp"][0] + 2: actions['fan'] = False

        # Toprak Nemi (Pompa)
        if soil < target_rule["soil"][0]: actions['pump'] = True
        elif soil > target_rule["soil"][1]: actions['pump'] = False

        # Nem Kontrolü (Işık/Sisleme)
        if hum < target_rule["hum"][0]: actions['light'] = True

        if actions:
            controls_ref.update(actions)
            for act, val in actions.items():
                log_msg = f"{selected_plants[0] if selected_plants else 'Sistem'} için {act} {'AÇILDI' if val else 'KAPATILDI'}"
                print(f"[OTOMASYON] {log_msg}")
                try:
                    db.reference('Greenhouse/Logs').push({
                        'msg': log_msg,
                        'timestamp': int(time.time()),
                        'type': act
                    })
                except: pass

    # ─────────────────────────────────────────────────────
    # KOTA YÖNETİMİ - KATMAN 3: Delta + Cooldown ile AI Çağrı Kontrolü
    # ─────────────────────────────────────────────────────
    MIN_TEMP_DELTA = 1.5  # Bu kadardan az değişimde AI çağırma
    temp_changed_enough = (
        last_known_temp is None or
        abs(temp - last_known_temp) >= MIN_TEMP_DELTA
    )
    last_known_temp = temp

    time_since_last_ai = current_time - last_ai_time
    should_call_ai = False

    if is_critical:
        if time_since_last_ai > CRITICAL_AI_COOLDOWN:
            should_call_ai = True
            print("[!] KRİTİK DURUM: Acil AI tavsiyesi alınıyor...")
    else:
        if time_since_last_ai > AI_COOLDOWN and temp_changed_enough:
            should_call_ai = True
            print("[*] Periyodik AI tavsiyesi alınıyor...")

    ai_advice = None
    if should_call_ai:
        ai_advice = get_gemini_advice(temp, hum, soil, vpd, et_rate, selected_plants)
        last_ai_time = current_time

    # Geçmiş Veri Kaydı (Her 10 dakikada bir)
    if current_time - last_history_time > HISTORY_INTERVAL:
        try:
            db.reference('Greenhouse/History').push({
                'temp': temp,
                'hum': hum,
                'soil': soil,
                'lux': sensor_state.get('light_lux', 0.0),
                'co2': sensor_state.get('CO2', 0.0),
                'voltage': 12.4,
                'ai_advice': ai_advice, 
                'ai_decision': "Sula" if actions.get('pump') else "Bekle", 
                'timestamp': int(current_time)
            })
            last_history_time = current_time
            print("[*] Geçmiş veri Firebase'e kaydedildi (AI destekli).")
        except Exception as e:
            print(f"History Hatası: {e}")

    # Firebase'e Yaz (Analiz)
    try:
        analysis_ref = db.reference('Greenhouse/AI_Analysis')
        update_data = {
            'et_rate': float(et_rate),
            'vpd_val': float(vpd),
            'last_sync': time.strftime('%H:%M:%S')
        }
        if ai_advice:
            update_data['advice'] = ai_advice

        analysis_ref.update(update_data)
        if ai_advice:
            print(f"[*] AI Tavsiyesi: {ai_advice}")
        print(f"[*] VPD={vpd} kPa, ET={et_rate} mm/h | Sıcaklık={temp}°C, Nem={hum}%, Toprak={soil}%")
    except Exception as e:
        print(f"Hata: {e}")


def on_settings_change(event):
    """Ayarlar güncellendiğinde önbelleği günceller."""
    global cached_settings
    if event.data is not None and isinstance(event.data, dict):
        cached_settings = event.data
    elif event.data is not None and isinstance(event.data, bool) or isinstance(event.data, str):
         # Spesifik bir değer güncellendiğinde
         path = event.path.strip("/")
         if path:
             cached_settings[path] = event.data
             
def start_with_reconnect():
    """
    Stream bağlantısını kurar. Kopunca otomatik yeniden bağlanır.
    Bu fonksiyon sayesinde backend sonsuza kadar ayakta kalır.
    """
    sensors_ref = db.reference('Greenhouse/Sensors')
    settings_ref = db.reference('Greenhouse/Settings')
    retry_delay = 5  # İlk bekleme süresi

    while True:
        try:
            print(f">>> Stream bağlantısı kuruluyor... (Greenhouse/Sensors & Settings)")
            sensor_listener = sensors_ref.listen(handle_sensor_change)
            settings_listener = settings_ref.listen(on_settings_change)
            print(">>> Stream aktif. Veri bekleniyor...")

            # Stream çalıştığı sürece burada bekle
            while True:
                time.sleep(1)

        except KeyboardInterrupt:
            print("\n>>> Durduruldu.")
            if 'sensor_listener' in locals():
                sensor_listener.close()
            if 'settings_listener' in locals():
                settings_listener.close()
            break
        except Exception as e:
            print(f"[!] Stream hatası: {e}")
            print(f"[!] {retry_delay} saniye sonra yeniden bağlanılıyor...")
            time.sleep(retry_delay)
            retry_delay = min(retry_delay * 2, 60)  # Exponential backoff, max 60sn


if __name__ == "__main__":
    if initialize_firebase():
        start_with_reconnect()
