import firebase_admin
from firebase_admin import credentials, db
import random
import time
import os

# --- Firebase Bağlantısı ---
CERT_PATH = "serviceAccountKey.json"

if not firebase_admin._apps:
    cred = credentials.Certificate(CERT_PATH)
    firebase_admin.initialize_app(cred, {
        'databaseURL': 'https://smart-greenhouse-9fb8e-default-rtdb.europe-west1.firebasedatabase.app'
    })

def generate_sensor_data():
    """Mantıklı sera verileri üretir."""
    return {
        "temp_inner": round(random.uniform(22.0, 35.0), 1), # Arada 32'yi geçsin ki alert görelim
        "temp_outer": round(random.uniform(15.0, 20.0), 1),
        "humidity_inner": random.randint(40, 70),
        "humidity_outer": random.randint(30, 50),
        "soil_moisture": random.randint(15, 60), # Arada 20'nin altına düşsün
        "light_lux": random.randint(200, 800),
        "CO2": random.randint(400, 1000),
    }

def start_simulating():
    print(">>> Simülatör Başlatıldı: Firebase'e veri gönderiliyor...")
    sensors_ref = db.reference('Greenhouse/Sensors')
    
    try:
        while True:
            data = generate_sensor_data()
            sensors_ref.update(data)
            print(f"[Simülatör] Gönderilen Veri: {data}")
            time.sleep(5) # 5 saniyede bir güncelle
    except KeyboardInterrupt:
        print("\n>>> Simülatör durduruldu.")

if __name__ == "__main__":
    start_simulating()