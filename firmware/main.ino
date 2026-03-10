#include <WiFi.h>
#include <FirebaseESP32.h>

// WiFi Bağlantı Bilgileri 
#define WIFI_SSID "WIFI_ADINI_BURAYA_YAZ"
#define WIFI_PASSWORD "WIFI_SIFRESINI_BURAYA_YAZ"

// Firebase Bilgileri
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
  // ÖRNEK TEST: Firebase'deki sıcaklık değerini 25 olarak güncelle
  // Gerçek sensör bağlandığında "25" yerine sensör değişkenini yazacak.
  if (Firebase.setFloat(fbdo, "/Greenhouse/Sensors/temp", 25.5)) {
    Serial.println("Veri basariyla gonderildi: Greenhouse/Sensors/temp");
  } else {
    Serial.println("Hata: " + fbdo.errorReason());
  }

  delay(10000); // 10 saniyede bir gönder
}