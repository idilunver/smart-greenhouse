#include <WiFi.h>
#include <FirebaseESP32.h>

// WiFi Bağlantı Bilgileri (Wokwi simülasyonu için sabit)
#define WIFI_SSID "Wokwi-GUEST"
#define WIFI_PASSWORD ""

// Senin Firebase Bilgilerin
#define API_KEY "AIzaSyB5VTUokAVSnmQUocsT1Ub7pOoxtCXKr4w" 
#define DATABASE_URL "https://smart-greenhouse-9fb8e-default-rtdb.europe-west1.firebasedatabase.app" 

// Firebase nesneleri
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

void setup() {
  Serial.begin(115200);

  // WiFi bağlantısı
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("WiFi'ye baglaniliyor...");
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(300);
  }
  Serial.println("\nWiFi baglandi!");

  // Firebase Yapılandırması
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
}

void loop() {
  // 1. JSON OBJESİ OLUŞTURMA 
  FirebaseJson json;

  // Şimdilik sensörler bağlı olmadığı için test değerleri gönderiyoruz
  // Gerçek sensörler bağlandığında buradaki rakamlar değişkenle değiştirilecek
  json.set("temp", 26.8);          // Sıcaklık
  json.set("humidity", 44.5);      // Nem
  json.set("lux", 550);            // Işık şiddeti
  json.set("soil_moisture", 65);   // Toprak nemi
  json.set("CO2", 415);            // Karbon dioksit

  // 2. TÜM PAKETİ TEK SEFERDE GÖNDERME
  if (Firebase.set(fbdo, "/Greenhouse/Sensors", json)) {
    Serial.println(">>> Tüm sensör verileri başarıyla paketiyle gönderildi!");
  } else {
    Serial.println("Hata: " + fbdo.errorReason());
  }

  // 3. KONTROL DÜĞMESİNİ DİNLEME 
  if (Firebase.getInt(fbdo, "/Greenhouse/Controls/pump")) {
    int pumpStatus = fbdo.intData();
    if (pumpStatus == 1) {
      Serial.println("--- UYARI: Su Pompası AKTİF ---");
    } else {
      Serial.println("--- Su Pompası KAPALI ---");
    }
  }

  delay(5000); // 5 saniyede bir güncelleme 
}