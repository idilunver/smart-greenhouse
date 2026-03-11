import firebase_admin
from firebase_admin import credentials
from firebase_admin import db
import time
import random

# --- Yapılandırma ---
CERT_PATH = "serviceAccountKey.json"

# Firebase'e bağlan
cred = credentials.Certificate(CERT_PATH)
firebase_admin.initialize_app(cred, {
    'databaseURL': 'https://smart-greenhouse-9fb8e-default-rtdb.europe-west1.firebasedatabase.app'
})

print(">>> Sahte ESP32 Baslatildi! Veriler gonderiliyor...")
sensors_ref = db.reference('Greenhouse/Sensors')

# Rastgele veri üretip gönderen döngü
try:
    while True:
        # 20 ile 35 derece arası rastgele sıcaklık
        fake_temp = round(random.uniform(20.0, 35.0), 1) 
        # %10 ile %80 arası rastgele nem
        fake_moisture = random.randint(10, 80)           

        yeni_veri = {
            'temp': fake_temp,
            'soil_moisture': fake_moisture,
            'light_lux': random.randint(100, 1000)
        }

        # Veriyi Firebase'e yaz
        sensors_ref.set(yeni_veri)
        print(f"[+] Gonderildi -> Sicaklik: {fake_temp}°C | Nem: %{fake_moisture}")
        
        # 5 saniyede bir yeni veri gönder
        time.sleep(5) 
except KeyboardInterrupt:
    print("\n>>> Sahte ESP32 durduruldu.")