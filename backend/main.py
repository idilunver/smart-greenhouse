import firebase_admin
from firebase_admin import credentials
from firebase_admin import db
import os
import time

# --- Yapılandırma ---
CERT_PATH = "serviceAccountKey.json"

def initialize_firebase():
    """Firebase bağlantısını başlatır."""
    if not os.path.exists(CERT_PATH):
        print(f"HATA: {CERT_PATH} dosyası bulunamadı!")
        print("Lütfen Firebase Console'dan indirdiğiniz anahtar dosyasını 'backend' klasörüne ekleyin.")
        return False
    
    try:
        cred = credentials.Certificate(CERT_PATH)
        # databaseURL kısmını senin gerçek Firebase URL'n ile güncelledim.
        firebase_admin.initialize_app(cred, {
            'databaseURL': 'https://smart-greenhouse-9fb8e-default-rtdb.europe-west1.firebasedatabase.app'
        })
        print(">>> Sera Backend Sistemi Başlatıldı...")
        return True
    except Exception as e:
        print(f"Bağlantı Hatası: {e}")
        return False

def handle_sensor_change(event):
    """Sensör verileri her değiştiğinde bu fonksiyon tetiklenir."""
    data = event.data
    if data is None:
        return
        
    print(f"\n--- Yeni Veri Geldi ---")
    
    # Basit Zeka / Mantık Kontrolleri
    if 'temp' in data:
        temp = data['temp']
        print(f"[*] Sıcaklık: {temp}°C")
        if temp > 30:
            print("⚠️  UYARI: Kritik sıcaklık! Soğutma gerekebilir.")
            
    if 'soil_moisture' in data:
        moisture = data['soil_moisture']
        print(f"[*] Toprak Nemi: %{moisture}")
        if moisture < 30:
            print("💧  UYARI: Toprak kurumuş! Su pompası tetiklenebilir.")

def start_listening():
    """Veritabanındaki sensör verilerini dinlemeye başlar."""
    print(">>> Sensörler dinleniyor (Greenhouse/Sensors)...")
    sensors_ref = db.reference('Greenhouse/Sensors')
    sensors_ref.listen(handle_sensor_change)

if __name__ == "__main__":
    if initialize_firebase():
        start_listening()
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            print("\n>>> Backend durduruldu.")
