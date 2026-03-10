import firebase_admin
from firebase_admin import credentials
from firebase_admin import db
import os
import time

# --- Yapılandırma ---
# serviceAccountKey.json dosyasının yolunu belirtin.
# Bu dosyanın .gitignore içinde olduğundan emin olun!
CERT_PATH = "serviceAccountKey.json"

def initialize_firebase():
    """Firebase bağlantısını başlatır."""
    if not os.path.exists(CERT_PATH):
        print(f"HATA: {CERT_PATH} dosyası bulunamadı!")
        print("Lütfen Firebase Console'dan indirdiğiniz anahtar dosyasını 'backend' klasörüne ekleyin.")
        return False
    
    try:
        cred = credentials.Certificate(CERT_PATH)
        # databaseURL kısmını kendi Firebase URL'niz ile değiştirin.
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
    # Greenhouse/Sensors altındaki tüm veriler event.data içinde gelir
    data = event.data
    if data is None:
        return
        
    print(f"\n--- Yeni Veri Geldi ---")
    
    # Sıcaklık kontrolü
    if 'temp' in data:
        temp = data['temp']
        print(f"[*] Sıcaklık: {temp}°C")
        if temp > 30:
            print("⚠️  KRİTİK UYARI: Sıcaklık çok yüksek! Soğutma sistemleri kontrol ediliyor...")
        elif temp < 15:
            print("❄️  UYARI: Düşük sıcaklık! Isıtıcılar aktif edilebilir.")
            
    # Diğer sensörlerin takibi (Örnek)
    if 'humidity' in data:
        print(f"[*] Nem: %{data['humidity']}")
        
    if 'soil_moisture' in data:
        print(f"[*] Toprak Nemi: %{data['soil_moisture']}")
        if data['soil_moisture'] < 30:
            print("💧  UYARI: Toprak kurumuş! Su pompası tetiklenebilir.")

def start_listening():
    """Veritabanındaki sensör verilerini dinlemeye başlar."""
    print(">>> Sensörler dinleniyor...")
    
    # 'Greenhouse/Sensors' yolunu dinliyoruz
    sensors_ref = db.reference('Greenhouse/Sensors')
    sensors_ref.listen(handle_sensor_change)

if __name__ == "__main__":
    if initialize_firebase():
        start_listening()
        
        # Programın kapanmaması için sonsuz döngü (listen arka planda çalışır)
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            print("\n>>> Backend durduruldu.")
