import firebase_admin
from firebase_admin import credentials, db
import random
import time
import os
from dotenv import load_dotenv

# --- Çevresel Değişkenleri Yükle ---
load_dotenv()

# --- Firebase Bağlantısı ---
CERT_PATH = os.getenv("SERVICE_ACCOUNT_KEY_PATH", "serviceAccountKey.json")
FIREBASE_DB_URL = os.getenv("FIREBASE_DATABASE_URL")

if not firebase_admin._apps:
    abs_cert_path = os.path.abspath(CERT_PATH)
    if not os.path.exists(abs_cert_path):
        print(f"HATA: {abs_cert_path} bulunamadı!")
        exit(1)
        
    cred = credentials.Certificate(abs_cert_path)
    firebase_admin.initialize_app(cred, {
        'databaseURL': FIREBASE_DB_URL
    })

# --- Dijital İkiz Durumu (State) ---
state = {
    "temp_inner": 24.5,
    "humidity_inner": 55.0,
    "soil_moisture": 45.0,
    "fan_on": False,
    "pump_on": False,
    "light_on": False
}

def on_control_change(event):
    """Firebase'den gelen kontrol emirlerini dinler."""
    global state
    controls = db.reference('Greenhouse/Controls').get() or {}
    state["fan_on"] = controls.get('fan', False)
    state["pump_on"] = controls.get('pump', False)
    state["light_on"] = controls.get('light', False)
    print(f"[*] Kontrol Güncellendi: Fan={state['fan_on']}, Pompa={state['pump_on']}")

def update_physics():
    """Gerçek dünya fiziğini simüle eder."""
    global state
    
    ambient_temp = 18.2 # Dış ortam sıcaklığı
    ambient_hum = 45.0  # Dış ortam nemi
    
    # ---------------------------------------------------------
    # NOT: ARKADAŞIN SUNUCUYU AÇIP DATALARI GÖNDERMEYE BAŞLADIĞINDA,
    # BU DOSYAYI ÇALIŞTIRMAYI DURDUR! Aksi halde çakışma olur.
    # ---------------------------------------------------------

    # 1. Sıcaklık Fiziği 
    if state["fan_on"]:
        # Fan açılınca sıcaklık daha hızlı düşer
        state["temp_inner"] -= random.uniform(0.1, 0.2) 
    else:
        # Fan kapalıyken, sıcaklık dış ortam sıcaklığına yavaşça uyum sağlar
        # veya gündüzse/güneşliyse artar (biz hafif artış simüle edelim)
        if state["temp_inner"] > ambient_temp:
            state["temp_inner"] -= random.uniform(0.01, 0.03) # Yavaşça soğur
        else:
            state["temp_inner"] += random.uniform(0.01, 0.05) # Veya sabit kalmaya çalışır
    
    # İçeride kendi ısınma faktörü (cihazlar, güneş) sebebiyle ufak eklemeler
    state["temp_inner"] += random.uniform(0.00, 0.02)
    
    # 2. Toprak Nemi Fiziği
    if state["pump_on"]:
        state["soil_moisture"] += random.uniform(0.5, 1.2) # Pompa çalışınca su artar
    else:
        state["soil_moisture"] -= random.uniform(0.02, 0.08) # Doğal buharlaşma
        
    # 3. Nem Fiziği (Işık/Sisleme simülasyonu ve Dış ortama uyum)
    if state["light_on"]:
        state["humidity_inner"] += random.uniform(0.5, 1.0) # Nem cihazı / sisleme çalışıyor
    elif state["fan_on"]:
        # Fan çalışınca nem kurur ve dış ortama yaklaşır
        state["humidity_inner"] -= random.uniform(0.2, 0.5)
    else:
        # Doğal dalgalanma
        if state["humidity_inner"] > ambient_hum:
            state["humidity_inner"] -= random.uniform(0.02, 0.05)
        else:
            state["humidity_inner"] += random.uniform(0.02, 0.05)

    # Sınırları Koru
    state["temp_inner"] = max(15.0, min(40.0, state["temp_inner"]))
    state["soil_moisture"] = max(5.0, min(95.0, state["soil_moisture"]))
    state["humidity_inner"] = max(20.0, min(95.0, state["humidity_inner"]))

def start_simulating():
    print(">>> Akıllı Simülatör (Digital Twin) Aktif...")
    sensors_ref = db.reference('Greenhouse/Sensors')
    
    # Kontrolleri dinlemeye başla
    db.reference('Greenhouse/Controls').listen(on_control_change)
    
    try:
        while True:
            update_physics()
            
            data = {
                "temp_inner": round(state["temp_inner"], 1),
                "temp_outer": 18.2, # Sabit dış sıcaklık
                "humidity_inner": round(state["humidity_inner"], 1),
                "humidity_outer": 45,
                "soil_moisture": round(state["soil_moisture"], 1),
                "light_lux": 500 + random.randint(-50, 50),
                "CO2": 600 + random.randint(-20, 20),
            }
            
            sensors_ref.update(data)
            print(f"[Dijital İkiz] Veri: T={data['temp_inner']}, Nem={data['humidity_inner']}, Toprak={data['soil_moisture']}")
            time.sleep(5) 
    except KeyboardInterrupt:
        print("\n>>> Simülatör durduruldu.")

if __name__ == "__main__":
    start_simulating()