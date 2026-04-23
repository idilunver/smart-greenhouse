/**
 *  Sensör & Röle Test Sketch'i
 *  ----------------------------
 *  Ana firmware'i yüklemeden önce bütün donanımın çalıştığını doğrulamak için.
 *
 *  NE YAPAR:
 *   1) I2C taraması — bağlı tüm adresleri listeler
 *   2) BME280 (0x76) — iç sıcaklık/nem/basınç
 *   3) BME280 (0x77) — dış sıcaklık/nem/basınç
 *   4) BH1750 (0x23) — lüks
 *   5) LM393 (GPIO35) — dijital ışık 0/1
 *   6) Toprak nem (GPIO34) — ham ADC + %
 *   7) Röle testi — pompa ve fanı sırayla 1 sn açıp kapatır
 *
 *  Gerekli kütüphaneler (Library Manager):
 *    - Adafruit BME280 Library
 *    - Adafruit Unified Sensor
 *    - BH1750 (Christopher Laws)
 *
 *  Board: ESP32 Dev Module · Baud: 115200
 */

#include <Wire.h>
#include <Adafruit_BME280.h>
#include <BH1750.h>

// ---- Pinler (ana firmware ile aynı) ----
#define PIN_SDA          21
#define PIN_SCL          22
#define PIN_SOIL         34
#define PIN_LDR_D        35
#define PIN_RELAY_PUMP   26
#define PIN_RELAY_FAN    27
#define RELAY_ACTIVE_LOW 1

// ---- Toprak nem kalibrasyon ----
#define SOIL_RAW_DRY   3000
#define SOIL_RAW_WET   1200

// ---- I2C adresleri ----
#define BME_INNER_ADDR 0x76
#define BME_OUTER_ADDR 0x77
#define BH1750_ADDR    0x23

Adafruit_BME280 bmeInner;
Adafruit_BME280 bmeOuter;
BH1750          lightMeter(BH1750_ADDR);

bool bmeInnerOK = false;
bool bmeOuterOK = false;
bool bhOK       = false;

// ============ I2C SCANNER ============
void i2cScan() {
  Serial.println("\n--- I2C Tarama ---");
  int found = 0;
  for (uint8_t addr = 1; addr < 127; addr++) {
    Wire.beginTransmission(addr);
    if (Wire.endTransmission() == 0) {
      Serial.printf("  0x%02X bulundu", addr);
      switch (addr) {
        case 0x76: Serial.print("  (BME280 iç beklenti)"); break;
        case 0x77: Serial.print("  (BME280 dış beklenti)"); break;
        case 0x23: Serial.print("  (BH1750 beklenti)");    break;
        case 0x5C: Serial.print("  (BH1750 ADDR=HIGH)");   break;
      }
      Serial.println();
      found++;
    }
  }
  if (found == 0) Serial.println("  HİÇ CİHAZ YOK! Kablo/pull-up/güç kontrol et.");
  else            Serial.printf("  Toplam: %d cihaz\n", found);
  Serial.println("--------------------\n");
}

// ============ RÖLE TEST ============
static inline int relayLevel(int onOff) {
#if RELAY_ACTIVE_LOW
  return onOff ? LOW : HIGH;
#else
  return onOff ? HIGH : LOW;
#endif
}

void relayTest() {
  Serial.println("\n--- Röle Testi ---");
  Serial.println("  Pompa AÇ (1 sn)...");
  digitalWrite(PIN_RELAY_PUMP, relayLevel(1));
  delay(1000);
  digitalWrite(PIN_RELAY_PUMP, relayLevel(0));
  Serial.println("  Pompa KAPAT");
  delay(500);

  Serial.println("  Fan AÇ (1 sn)...");
  digitalWrite(PIN_RELAY_FAN, relayLevel(1));
  delay(1000);
  digitalWrite(PIN_RELAY_FAN, relayLevel(0));
  Serial.println("  Fan KAPAT");
  Serial.println("--------------------\n");
}

// ============ SETUP ============
void setup() {
  Serial.begin(115200);
  delay(300);
  Serial.println("\n==================================");
  Serial.println("  SERA DONANIM TEST SKETCH'İ");
  Serial.println("==================================");

  // Röle pinleri + başlangıçta kapalı
  pinMode(PIN_RELAY_PUMP, OUTPUT);
  pinMode(PIN_RELAY_FAN,  OUTPUT);
  digitalWrite(PIN_RELAY_PUMP, relayLevel(0));
  digitalWrite(PIN_RELAY_FAN,  relayLevel(0));

  // Analog/dijital giriş
  analogReadResolution(12);
  pinMode(PIN_SOIL,  INPUT);
  pinMode(PIN_LDR_D, INPUT);

  // I2C başlat + tara
  Wire.begin(PIN_SDA, PIN_SCL);
  delay(100);
  i2cScan();

  // BME280 #1 (iç - 0x76)
  bmeInnerOK = bmeInner.begin(BME_INNER_ADDR);
  Serial.printf("[BME280 iç  0x%02X] %s\n", BME_INNER_ADDR, bmeInnerOK ? "OK" : "YOK");

  // BME280 #2 (dış - 0x77)
  bmeOuterOK = bmeOuter.begin(BME_OUTER_ADDR);
  Serial.printf("[BME280 dış 0x%02X] %s\n", BME_OUTER_ADDR, bmeOuterOK ? "OK" : "YOK");
  if (!bmeOuterOK) {
    Serial.println("  ! Dış BME280'in SDO pinini 3.3V'a bağladın mı?");
  }

  // BH1750
  bhOK = lightMeter.begin();
  Serial.printf("[BH1750 0x%02X] %s\n", BH1750_ADDR, bhOK ? "OK" : "YOK");

  Serial.println();
  relayTest();

  Serial.println("Sürekli okuma başlıyor (2 sn'de bir)...\n");
}

// ============ LOOP ============
void loop() {
  Serial.println("----- ÖLÇÜM -----");

  // BME280 iç
  if (bmeInnerOK) {
    float t  = bmeInner.readTemperature();
    float h  = bmeInner.readHumidity();
    float p  = bmeInner.readPressure() / 100.0f;
    Serial.printf("BME280 iç  : T=%.2f °C  H=%.2f %%  P=%.1f hPa\n", t, h, p);
  } else {
    Serial.println("BME280 iç  : --");
  }

  // BME280 dış
  if (bmeOuterOK) {
    float t = bmeOuter.readTemperature();
    float h = bmeOuter.readHumidity();
    float p = bmeOuter.readPressure() / 100.0f;
    Serial.printf("BME280 dış : T=%.2f °C  H=%.2f %%  P=%.1f hPa\n", t, h, p);
  } else {
    Serial.println("BME280 dış : --");
  }

  // BH1750
  if (bhOK) {
    float lx = lightMeter.readLightLevel();
    Serial.printf("BH1750     : %.1f lx\n", lx);
  } else {
    Serial.println("BH1750     : --");
  }

  // LM393
  int ldr = digitalRead(PIN_LDR_D);
  Serial.printf("LM393 DO   : %d  (%s)\n", ldr, ldr == LOW ? "aydınlık" : "karanlık");

  // Toprak nem
  int soilRaw = analogRead(PIN_SOIL);
  float soilPct = 100.0f * (float)(SOIL_RAW_DRY - soilRaw) /
                  (float)(SOIL_RAW_DRY - SOIL_RAW_WET);
  if (soilPct < 0)   soilPct = 0;
  if (soilPct > 100) soilPct = 100;
  Serial.printf("Toprak nem : raw=%d  %%=%.1f\n", soilRaw, soilPct);
  Serial.println("  ! Kalibrasyon: havada/suya batırıp SOIL_RAW_DRY / SOIL_RAW_WET'i güncelle.\n");

  delay(2000);
}
