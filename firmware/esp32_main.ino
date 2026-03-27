#include <Arduino.h>
#include <WiFi.h>
#include <Firebase_ESP_Client.h>

// WiFiManager için
#include <WiFiManager.h> 

// Firebase Eklentileri
#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"

/* 1. FIREBASE BİLGİLERİ */
#define API_KEY "BURAYA_FIREBASE_API_KEY_YAZILACAK"
#define DATABASE_URL "BURAYA_FIREBASE_DATABASE_URL_YAZILACAK"

/* 2. PIN TANIMLAMALARI (Örnek) */
#define FAN_PIN 18
#define PUMP_PIN 19
#define SOIL_PIN 34
// BME280 ve diğer I2C sensörler SDA(21), SCL(22) üzerinden bağlanır.

/* 3. FIREBASE NESNELERİ */
FirebaseData fbdo;
FirebaseData fbdoStream; // Dinleme için ayrı data objesi
FirebaseAuth auth;
FirebaseConfig config;

unsigned long dataMillis = 0;

void streamCallback(FirebaseStream data) {
  // Controls/ altındaki değişiklikleri dinler
  Serial.printf("Stream event: %s, type: %s, value: %s\n", 
                data.dataPath().c_str(), 
                data.dataType().c_str(), 
                data.payload().c_str());

  if (data.dataPath() == "/fan") {
    bool state = data.boolData();
    digitalWrite(FAN_PIN, state ? HIGH : LOW);
    Serial.println(state ? "Fan AÇILDI" : "Fan KAPATILDI");
  } 
  else if (data.dataPath() == "/pump") {
    bool state = data.boolData();
    digitalWrite(PUMP_PIN, state ? HIGH : LOW);
    Serial.println(state ? "Pompa AÇILDI" : "Pompa KAPATILDI");
  }
}

void streamTimeoutCallback(bool timeout) {
  if (timeout)
    Serial.println("Stream timeout, resuming...\n");
}

void setup() {
  Serial.begin(115200);

  // Pin Modları
  pinMode(FAN_PIN, OUTPUT);
  pinMode(PUMP_PIN, OUTPUT);

  // ----------------------------------------------------
  // WiFi Kurulumu (WiFiManager)
  // ----------------------------------------------------
  WiFiManager wm;
  // wm.resetSettings(); // Temizlemek istersen açabilirsin
  
  // "AkilliSera-Kurulum" adında bir ağ açar
  bool res = wm.autoConnect("AkilliSera-Kurulum"); 
  if(!res) {
      Serial.println("WiFi baglantisi basarisiz!");
      ESP.restart();
  } 
  Serial.println("WiFi'a baglanildi!");

  // ----------------------------------------------------
  // Firebase Kurulumu
  // ----------------------------------------------------
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  
  // Anonim giriş veya Email/Şifre kullanabilirsin
  if (Firebase.signUp(&config, &auth, "", "")) {
    Serial.println("Firebase Auth basaliri");
  } else {
    Serial.printf("%s\n", config.signer.signupError.message.c_str());
  }

  config.token_status_callback = tokenStatusCallback; 
  
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  // Stream Başlat
  if (!Firebase.RTDB.beginStream(&fbdoStream, "/Greenhouse/Controls")) {
    Serial.printf("Stream basarisiz: %s\n", fbdoStream.errorReason().c_str());
  }
  Firebase.RTDB.setStreamCallback(&fbdoStream, streamCallback, streamTimeoutCallback);
}

void loop() {
  // Her 5 saniyede bir veri gönder
  if (Firebase.ready() && (millis() - dataMillis > 5000 || dataMillis == 0)) {
    dataMillis = millis();

    // 1. Sensörleri Oku (SİMÜLE EDİLMİŞ VERİ)
    // Donanım bağlandığında buralara gerçek analogRead() ve kütüphane okumaları gelecek.
    float temp = 24.5; 
    float hum = 55.2;
    float soil = map(analogRead(SOIL_PIN), 0, 4095, 0, 100); // Örnek analog okuma

    // 2. JSON Formatında Paketle
    FirebaseJson json;
    json.set("temp_inner", temp);
    json.set("humidity_inner", hum);
    json.set("soil_moisture", soil);
    json.set("light_lux", 550);
    json.set("CO2", 600);
    
    // Sabit / Dış veriler
    json.set("temp_outer", 18.0);
    json.set("humidity_outer", 45.0);

    // 3. Firebase'e Toplu Gönder
    Serial.printf("Sensor verileri gonderiliyor... ");
    if (Firebase.RTDB.updateNode(&fbdo, "/Greenhouse/Sensors", &json)) {
      Serial.println("BASARILI!");
    } else {
      Serial.println(fbdo.errorReason());
    }
  }
}
