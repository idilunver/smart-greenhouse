import firebase_admin
from firebase_admin import credentials, db
import random
import time
import os
from dotenv import load_dotenv

# --- Çevresel Değişkenleri Yükle ---
load_dotenv()

CERT_PATH = os.getenv("SERVICE_ACCOUNT_KEY_PATH", "serviceAccountKey.json")
FIREBASE_DB_URL = os.getenv("FIREBASE_DATABASE_URL")

def initialize_firebase():
    if not firebase_admin._apps:
        abs_path = os.path.abspath(CERT_PATH)
        if not os.path.exists(abs_path):
            print(f"HATA: {abs_path} bulunamadı!")
            return False
        cred = credentials.Certificate(abs_path)
        firebase_admin.initialize_app(cred, {'databaseURL': FIREBASE_DB_URL})
    return True

def send_fake_data():
    print(">>> Test Veri Gönderici (Phase 2) Aktif...")
    sensors_ref = db.reference('Greenhouse/Sensors')
    
    try:
        while True:
            data = {
                "temp_inner": round(random.uniform(22, 28), 1),
                "humidity_inner": round(random.uniform(40, 70), 1),
                "soil_moisture": round(random.uniform(30, 60), 1),
                "temp_outer": 18.0,
                "humidity_outer": 45.0,
                "light_lux": random.randint(400, 600),
                "CO2": random.randint(500, 700),
                "timestamp": int(time.time())
            }
            sensors_ref.update(data)
            print(f"[*] Firebase'e veri basıldı: T={data['temp_inner']}, N={data['humidity_inner']}")
            time.sleep(5)
    except KeyboardInterrupt:
        print("\nDurduruldu.")

if __name__ == "__main__":
    if initialize_firebase():
        send_fake_data()
