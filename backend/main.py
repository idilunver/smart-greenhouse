import firebase_admin
from firebase_admin import credentials, db
import time
import math
import os
import google.generativeai as genai

# --- Yapılandırma ---
CERT_PATH = "serviceAccountKey.json"
GEMINI_API_KEY = "AIzaSyBXhB8n33_guRAFCy3JBwsyP0_VRePPzHI" 
AI_COOLDOWN = 300  # 5 dakika (Normal mod)
CRITICAL_AI_COOLDOWN = 60 # 1 dakika (Kritik mod)
HISTORY_INTERVAL = 600 # 10 dakika (Geçmiş veri kaydı için)
last_ai_time = 0
last_history_time = 0

# Gemini Kurulumu - Kota dostu LITE model
genai.configure(api_key=GEMINI_API_KEY)
model = genai.GenerativeModel('gemini-flash-lite-latest')

def initialize_firebase():
    if not firebase_admin._apps:
        if not os.path.exists(CERT_PATH):
            print(f"HATA: {CERT_PATH} bulunamadı!")
            return False
        cred = credentials.Certificate(CERT_PATH)
        firebase_admin.initialize_app(cred, {
            'databaseURL': 'https://smart-greenhouse-9fb8e-default-rtdb.europe-west1.firebasedatabase.app'
        })
    print(">>> AI Destekli Sera Backend Sistemi Aktif...")
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
    Sen akıllı bir sera yönetim sisteminin ziraat mühendisi yapay zekasısın. 
    Serada şu an yetiştirilen bitkiler: {plants_text}
    
    Şu anki veriler:
    - İç Sıcaklık: {temp}°C (Trend: {trend_text})
    - İç Nem: %{hum}
    - Toprak Nemi: %{soil}
    - VPD Değeri: {vpd} kPa
    - Tahmini Buharlaşma (ET): {et_rate}

    Bu verilere, trend bilgilerine ve seçili bitki türlerine dayanarak bir tahminleme yap ve tavsiye ver. 
    Eğer değerler kötüye gidiyorsa (trend kritikse) hemen uyar. Maksimum 20 kelime.
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

def handle_sensor_change(event):
    global last_ai_time, last_history_time
    data = event.data
    if data is None or not isinstance(data, dict): return
        
    print(f"\n--- Veri Geldi ({time.strftime('%H:%M:%S')}) ---")
    
    # 1. Verileri Hazırla
    temp = float(data.get('temp_inner', 25))
    hum = float(data.get('humidity_inner', 50))
    soil = float(data.get('soil_moisture', 40))
    
    # 2. Güncel Ayarları Çek (Bitkiler + Auto Mode)
    try:
        settings = db.reference('Greenhouse/Settings').get() or {}
        selected_plants = settings.get('plants', [])
        auto_mode = settings.get('auto_mode', False)
    except:
        selected_plants, auto_mode = [], False
    
    # 3. Matematiksel Hesaplamalar
    vpd = calculate_vpd(temp, hum)
    et_rate = round(vpd * 0.4, 2)
    
    # 4. Geçmiş Veri Kaydı (Her 10 dakikada bir)
    current_time = time.time()
    if current_time - last_history_time > HISTORY_INTERVAL:
        try:
            db.reference('Greenhouse/History').push({
                'temp': temp,
                'hum': hum,
                'soil': soil,
                'lux': float(data.get('light_lux', 0)),
                'co2': float(data.get('CO2', 0)),
                'voltage': 12.4, # Simüle voltaj
                'timestamp': int(current_time)
            })
            last_history_time = current_time
            print("[*] Geçmiş veri Firebase'e kaydedildi.")
        except Exception as e:
            print(f"History Hatası: {e}")

    # 5. Akıllı Otomasyon (The Brain)
    if auto_mode:
        # En kısıtlı bitkiye göre (veya ilkine göre) kural belirle
        plant_name = "genel bitkiler"
        if selected_plants and isinstance(selected_plants, list) and len(selected_plants) > 0:
            first_plant = str(selected_plants[0])
            plant_name = first_plant.split(" ")[0]
            
        target_rule = PLANT_RULES.get(plant_name, PLANT_RULES["genel bitkiler"])
        
        controls_ref = db.reference('Greenhouse/Controls')
        actions = {}
        
        # Sıcaklık Kontrolü (Fan)
        if temp > target_rule["temp"][1]: actions['fan'] = True
        elif temp < target_rule["temp"][0] + 2: actions['fan'] = False
        
        # Toprak Nemi (Pompa)
        if soil < target_rule["soil"][0]: actions['pump'] = True
        elif soil > target_rule["soil"][1]: actions['pump'] = False
        
        # Nem Kontrolü (Opsiyonel Işık/Sisleme simülasyonu)
        if hum < target_rule["hum"][0]: actions['light'] = True # Işığı sisleme gibi simüle edelim
        
        if actions:
            controls_ref.update(actions)
            # Olay Günlüğü Logla
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

    # 6. AI Tavsiyesi Gerekiyor mu?
    is_critical = (temp > 32 or soil < 20 or hum < 40)
    
    # KOTA KORUMASI: Kritik durumda bile en az 1 dakika geçmeli
    time_since_last_ai = current_time - last_ai_time
    
    should_call_ai = False
    if is_critical:
        # Kritik durumda 1 dakika (60 sn) bekliyoruz
        if time_since_last_ai > CRITICAL_AI_COOLDOWN:
            should_call_ai = True
            print("[!] KRITIK DURUM: Acil AI tavsiyesi alınıyor...")
    else:
        # Normal durumda 5 dakika (300 sn) bekliyoruz
        if time_since_last_ai > AI_COOLDOWN:
            should_call_ai = True
            print("[*] Periyodik AI tavsiyesi alınıyor...")

    ai_advice = None
    if should_call_ai:
        ai_advice = get_gemini_advice(temp, hum, soil, vpd, et_rate, selected_plants)
        last_ai_time = current_time
    
    # 7. Firebase'e Yaz (Analiz)
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
        print(f"[*] Sistem Verileri: VPD={vpd}, ET={et_rate}")
    except Exception as e:
        print(f"Hata: {e}")

if __name__ == "__main__":
    if initialize_firebase():
        sensors_ref = db.reference('Greenhouse/Sensors')
        sensors_ref.listen(handle_sensor_change)
        try:
            while True: time.sleep(1)
        except KeyboardInterrupt: print("\n>>> Durduruldu.")
