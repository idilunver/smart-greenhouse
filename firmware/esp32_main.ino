#include <Arduino.h>
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <Wire.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_BME280.h>
#include <BH1750.h>
#include <WiFiManager.h> 

// Firebase Eklentileri
#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"

/* 1. FIREBASE VE BAGLANTI BILGILERI */
#define API_KEY "BURAYA_FIREBASE_API_KEY_YAZILACAK"
#define DATABASE_URL "BURAYA_FIREBASE_DATABASE_URL_YAZILACAK"

/* 2. PIN TANIMLAMALARI (Rapora Uygun) */
#define FAN_PIN 18
#define PUMP_PIN 19
#define SOIL_PIN 34   // Analog Pin
#define SDA_PIN 21
#define SCL_PIN 22

/* 3. SENSOR VE KONTROL OBJELERI */
Adafruit_BME280 bme; 
BH1750 lightMeter;
FirebaseData fbdo;
FirebaseData fbdoStream;
FirebaseAuth auth;
FirebaseConfig config;

unsigned long dataMillis = 0;
bool isOffline = false;

// Global sensor degerleri
float current_temp = 25.0;
float current_hum = 50.0;
float current_soil = 50.0;
float current_lux = 500.0;

/* 4. YEREL MANTIK (OFFLINE MODE) - 4.3.1 */
void checkLocalLogic() {
  // İnternet koptuğunda ESP32'nin kendi başına alacağı kararlar
  if (current_soil < 30.0) { // Toprak çok kuruysa
    digitalWrite(PUMP_PIN, HIGH);
    Serial.println("[OFFLINE] Toprak kuru, pompa ACILDI.");
  } else if (current_soil > 60.0) {
    digitalWrite(PUMP_PIN, LOW);
  }

  if (current_temp > 32.0) { // Çok sıcaksa
    digitalWrite(FAN_PIN, HIGH);
    Serial.println("[OFFLINE] Sicaklik yuksek, fan ACILDI.");
  } else if (current_temp < 28.0) {
     digitalWrite(FAN_PIN, LOW);
  }
}

void streamCallback(FirebaseStream data) {
  if (isOffline) return; // Offline iken callback'leri yoksay

  Serial.printf("Stream callback: %s %s %s\n", data.dataPath().c_str(), data.dataType().c_str(), data.payload().c_str());

  if (data.dataPath() == "/fan") {
    digitalWrite(FAN_PIN, data.boolData() ? HIGH : LOW);
  } 
  else if (data.dataPath() == "/pump") {
    digitalWrite(PUMP_PIN, data.boolData() ? HIGH : LOW);
  }
}

void streamTimeoutCallback(bool timeout) {
  if (timeout) Serial.println("Stream timeout, resume...");
}

void readSensors() {
  // BME280 Oku
  float t = bme.readTemperature();
  float h = bme.readHumidity();
  if (!isnan(t)) current_temp = t;
  if (!isnan(h)) current_hum = h;

  // BH1750 LUX Oku
  current_lux = lightMeter.readLightLevel();

  // Toprak Nemi Oku (Kapasitif Sensor Kalibrasyonu Gerekli)
  int rawSoil = analogRead(SOIL_PIN);
  current_soil = map(rawSoil, 3200, 1500, 0, 100); // 3200=Kuru, 1500=Islak (Ornektir)
  current_soil = constrain(current_soil, 0, 100);
}

void setup() {
  Serial.begin(115200);
  pinMode(FAN_PIN, OUTPUT);
  pinMode(PUMP_PIN, OUTPUT);

  // I2C Baslat
  Wire.begin(SDA_PIN, SCL_PIN);
  
  if (!bme.begin(0x76, &Wire)) {
    Serial.println("BME280 bulunamadi, kablolari kontrol et!");
  }
  
  if (!lightMeter.begin(BH1750::CONTINUOUS_HIGH_RES_MODE)) {
    Serial.println("BH1750 bulunamadi!");
  }

  // WiFiManager
  WiFiManager wm;
  if (!wm.autoConnect("AkilliSera-Kurulum")) {
    Serial.println("WiFi baglanamadi!");
    // Eger baglanamazsa direkt offline modda basla veya restart et
  }

  // Firebase
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  if (Firebase.signUp(&config, &auth, "", "")) {
    Serial.println("Firebase Auth Basarili");
  }

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  if (Firebase.RTDB.beginStream(&fbdoStream, "/Greenhouse/Controls")) {
    Firebase.RTDB.setStreamCallback(&fbdoStream, streamCallback, streamTimeoutCallback);
  }
}

void loop() {
  // 1. Sensorleri periyodik oku
  readSensors();

  // 2. Baglanti Kontrolu (4.3.1 Connectivity Fail-Safe)
  if (WiFi.status() != WL_CONNECTED || !Firebase.ready()) {
    if (!isOffline) {
      Serial.println(">>> BAGLANTI KOPTU: Offline Mode Aktif!");
      isOffline = true;
    }
    checkLocalLogic(); // Yerel kararlar devreye girer
  } else {
    if (isOffline) {
      Serial.println(">>> BAGLANTI SAGLANDI: Cloud Mode Aktif!");
      isOffline = false;
    }
  }

  // 3. Buluta Veri Gonder (15 saniyede bir)
  if (!isOffline && (millis() - dataMillis > 15000 || dataMillis == 0)) {
    dataMillis = millis();
    FirebaseJson json;
    json.set("temp_inner", current_temp);
    json.set("humidity_inner", current_hum);
    json.set("soil_moisture", current_soil);
    json.set("light_lux", current_lux);
    json.set("CO2", 400); // Ornek sabit deger
    json.set("last_ping", "Online");
    
    if (Firebase.RTDB.updateNode(&fbdo, "/Greenhouse/Sensors", &json)) {
      Serial.println("[Cloud] Sensorler guncellendi.");
    }
  }
  
  delay(1000); 
}

