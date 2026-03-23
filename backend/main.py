import firebase_admin
from firebase_admin import credentials, db
import time
import math
import os
import google.generativeai as genai

# --- Yapılandırma ---
CERT_PATH = "serviceAccountKey.json"
GEMINI_API_KEY = "AIzaSyBXhB8n33_guRAFCy3JBwsyP0_VRePPzHI" 

# Gemini Kurulumu
genai.configure(api_key=GEMINI_API_KEY)
model = genai.GenerativeModel('gemini-1.5-flash')

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

def get_gemini_advice(temp, hum, soil, vpd, et_rate):
    """Verileri Gemini'ye gönderir ve profesyonel tavsiye alır."""
    prompt = f"""
    Sen akıllı bir sera yönetim sisteminin ziraat mühendisi yapay zekasısın. 
    Şu anki veriler:
    - İç Sıcaklık: {temp}°C
    - İç Nem: %{hum}
    - Toprak Nemi: %{soil}
    - VPD Değeri: {vpd} kPa
    - Tahmini Buharlaşma (ET): {et_rate}

    Bu verilere dayanarak sera sahibine çok kısa, teknik ama anlaşılır bir tavsiye ver. 
    Eğer değerler kritikteyse hemen ne yapması gerektiğini söyle. Maksimum 20 kelime olsun.
    """
    try:
        response = model.generate_content(prompt)
        return response.text.strip()
    except Exception as e:
        print(f"Gemini Hatası: {e}")
        return "Veriler analiz ediliyor, lütfen koşulları takip edin."

def handle_sensor_change(event):
    data = event.data
    if data is None or not isinstance(data, dict): return
        
    print(f"\n--- Analiz Başladı ({time.strftime('%H:%M:%S')}) ---")
    
    # 1. Verileri Hazırla
    temp = float(data.get('temp_inner', 25))
    hum = float(data.get('humidity_inner', 50))
    soil = float(data.get('soil_moisture', 40))
    
    # 2. Matematiksel Hesaplamalar
    vpd = calculate_vpd(temp, hum)
    et_rate = round(vpd * 0.4, 2)
    
    # 3. AI Yorumu Al
    print("[*] Gemini'den tavsiye alınıyor...")
    ai_advice = get_gemini_advice(temp, hum, soil, vpd, et_rate)
    
    # 4. Firebase'e Yaz
    try:
        analysis_ref = db.reference('Greenhouse/AI_Analysis')
        analysis_ref.update({
            'advice': ai_advice,
            'et_rate': et_rate,
            'vpd_val': vpd,
            'last_sync': time.strftime('%H:%M:%S')
        })
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