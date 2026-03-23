import firebase_admin
from firebase_admin import credentials, db
import time
import math
import os
import google.generativeai as genai

# --- Yapılandırma ---
CERT_PATH = "serviceAccountKey.json"
GEMINI_API_KEY = "AIzaSyBXhB8n33_guRAFCy3JBwsyP0_VRePPzHI" 
AI_COOLDOWN = 300  # 5 dakika (Saniye cinsinden)
last_ai_time = 0

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
    """Verileri Gemini'ye gönderir ve profesyonel tavsiye alır."""
    # Emojileri temizle (opsiyonel ama daha temiz olur)
    clean_plants = [p.split(" ")[0] for p in plants] if plants else ["genel bitkiler"]
    plants_text = ", ".join(clean_plants)
    
    prompt = f"""
    Sen akıllı bir sera yönetim sisteminin ziraat mühendisi yapay zekasısın. 
    Serada şu an yetiştirilen bitkiler: {plants_text}
    
    Şu anki veriler:
    - İç Sıcaklık: {temp}°C
    - İç Nem: %{hum}
    - Toprak Nemi: %{soil}
    - VPD Değeri: {vpd} kPa
    - Tahmini Buharlaşma (ET): {et_rate}

    Bu verilere ve seçili bitki türlerine dayanarak sera sahibine çok kısa, teknik ama anlaşılır bir tavsiye ver. 
    Eğer değerler kritikteyse hemen ne yapması gerektiğini söyle. Maksimum 20 kelime olsun.
    """
    try:
        response = model.generate_content(prompt)
        return response.text.strip()
    except Exception as e:
        print(f"Gemini Hatası (get_gemini_advice): {e}")
        if "429" in str(e):
            return "Günlük AI kotası doldu. Veriler normal şekilde izlenmeye devam ediyor."
        return "Veriler analiz ediliyor, lütfen koşulları takip edin."

def handle_sensor_change(event):
    global last_ai_time
    data = event.data
    if data is None or not isinstance(data, dict): return
        
    print(f"\n--- Veri Geldi ({time.strftime('%H:%M:%S')}) ---")
    
    # 1. Verileri Hazırla
    temp = float(data.get('temp_inner', 25))
    hum = float(data.get('humidity_inner', 50))
    soil = float(data.get('soil_moisture', 40))
    
    # 2. Güncel Bitki Listesini Firebase'den Çek
    try:
        plants_snapshot = db.reference('Greenhouse/Settings/plants').get()
        selected_plants = plants_snapshot if plants_snapshot else []
    except:
        selected_plants = []
    
    # 3. Matematiksel Hesaplamalar
    vpd = calculate_vpd(temp, hum)
    et_rate = round(vpd * 0.4, 2)
    
    # 4. Kritik Durum Kontrolü
    # Not: Histerezis veya daha geniş limitler eklenebilir
    is_critical = temp > 32 or soil < 20 or hum < 40
    current_time = time.time()
    
    # AI Tavsiyesi Gerekiyor mu?
    # - 5 dakika geçtiyse
    # - VEYA Kritik bir durum varsa
    should_call_ai = (current_time - last_ai_time > AI_COOLDOWN) or is_critical

    ai_advice = None
    if should_call_ai:
        print(f"[*] Gemini'den {selected_plants} için tavsiye alınıyor...")
        ai_advice = get_gemini_advice(temp, hum, soil, vpd, et_rate, selected_plants)
        last_ai_time = current_time
    
    # 5. Firebase'e Yaz
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
