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
    
    # Sıcaklık Fiziği
    if state["fan_on"] == True:
        state["temp_inner"] -= 0.15 # Fan soğutur (Daha dengeli)
    else:
        state["temp_inner"] += random.uniform(0.01, 0.05) # Güneş ısıtır (Daha yavaş)
    
    # Toprak Nemi Fiziği
    if state["pump_on"] == True:
        state["soil_moisture"] += 0.8 # Pompa sular (Taşmayı önler)
    else:
        state["soil_moisture"] -= 0.05 # Buharlaşma (Daha stabil)
        
    # Nem Fiziği (Işık/Sisleme simülasyonu)
    if state["light_on"] == True:
        state["humidity_inner"] += 0.8
    else:
        state["humidity_inner"] += random.uniform(-0.5, 0.5)

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