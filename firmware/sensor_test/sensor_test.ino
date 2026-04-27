/**
 *  Sensor & Relay Test Sketch
 *  --------------------------
 *  Used to verify that all hardware is functioning correctly before
 *  uploading the main firmware.
 *
 *  WHAT IT DOES:
 *   1) I2C scan — lists all detected addresses
 *   2) BME280 (0x76) — inner temperature / humidity / pressure
 *   3) BME280 (0x77) — outer temperature / humidity / pressure
 *   4) BH1750 (0x23) — illuminance in lux
 *   5) LM393 (GPIO35) — digital light output 0/1
 *   6) Soil moisture (GPIO34) — raw ADC value + percentage
 *   7) Relay test — cycles pump and fan ON for 1 s each, then OFF
 *
 *  Required libraries (Library Manager):
 *    - Adafruit BME280 Library
 *    - Adafruit Unified Sensor
 *    - BH1750 (Christopher Laws)
 *
 *  Board: ESP32 Dev Module · Baud: 115200
 */

#include <Wire.h>
#include <Adafruit_BME280.h>
#include <BH1750.h>

// ---- Pins (same as main firmware) ----
#define PIN_SDA          21
#define PIN_SCL          22
#define PIN_SOIL         34
#define PIN_LDR_D        35
#define PIN_RELAY_PUMP   26
#define PIN_RELAY_FAN    27
#define RELAY_ACTIVE_LOW 1

// ---- Soil moisture calibration ----
#define SOIL_RAW_DRY   3000
#define SOIL_RAW_WET   1200

// ---- I2C addresses ----
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
  Serial.println("\n--- I2C Scan ---");
  int found = 0;
  for (uint8_t addr = 1; addr < 127; addr++) {
    Wire.beginTransmission(addr);
    if (Wire.endTransmission() == 0) {
      Serial.printf("  0x%02X found", addr);
      switch (addr) {
        case 0x76: Serial.print("  (BME280 inner expected)"); break;
        case 0x77: Serial.print("  (BME280 outer expected)"); break;
        case 0x23: Serial.print("  (BH1750 expected)");       break;
        case 0x5C: Serial.print("  (BH1750 ADDR=HIGH)");      break;
      }
      Serial.println();
      found++;
    }
  }
  if (found == 0) Serial.println("  NO DEVICES FOUND! Check wiring, pull-ups, and power supply.");
  else            Serial.printf("  Total: %d device(s)\n", found);
  Serial.println("--------------------\n");
}

// ============ RELAY TEST ============
static inline int relayLevel(int onOff) {
#if RELAY_ACTIVE_LOW
  return onOff ? LOW : HIGH;
#else
  return onOff ? HIGH : LOW;
#endif
}

void relayTest() {
  Serial.println("\n--- Relay Test ---");
  Serial.println("  Pump ON (1 s)...");
  digitalWrite(PIN_RELAY_PUMP, relayLevel(1));
  delay(1000);
  digitalWrite(PIN_RELAY_PUMP, relayLevel(0));
  Serial.println("  Pump OFF");
  delay(500);

  Serial.println("  Fan ON (1 s)...");
  digitalWrite(PIN_RELAY_FAN, relayLevel(1));
  delay(1000);
  digitalWrite(PIN_RELAY_FAN, relayLevel(0));
  Serial.println("  Fan OFF");
  Serial.println("--------------------\n");
}

// ============ SETUP ============
void setup() {
  Serial.begin(115200);
  delay(300);
  Serial.println("\n==================================");
  Serial.println("  GREENHOUSE HARDWARE TEST SKETCH");
  Serial.println("==================================");

  // Relay pins — all OFF at startup
  pinMode(PIN_RELAY_PUMP, OUTPUT);
  pinMode(PIN_RELAY_FAN,  OUTPUT);
  digitalWrite(PIN_RELAY_PUMP, relayLevel(0));
  digitalWrite(PIN_RELAY_FAN,  relayLevel(0));

  // Analog / digital inputs
  analogReadResolution(12);
  pinMode(PIN_SOIL,  INPUT);
  pinMode(PIN_LDR_D, INPUT);

  // Initialise I2C and scan
  Wire.begin(PIN_SDA, PIN_SCL);
  delay(100);
  i2cScan();

  // BME280 #1 (inner - 0x76)
  bmeInnerOK = bmeInner.begin(BME_INNER_ADDR);
  Serial.printf("[BME280 inner 0x%02X] %s\n", BME_INNER_ADDR, bmeInnerOK ? "OK" : "NOT FOUND");

  // BME280 #2 (outer - 0x77)
  bmeOuterOK = bmeOuter.begin(BME_OUTER_ADDR);
  Serial.printf("[BME280 outer 0x%02X] %s\n", BME_OUTER_ADDR, bmeOuterOK ? "OK" : "NOT FOUND");
  if (!bmeOuterOK) {
    Serial.println("  ! Have you connected the SDO pin of the outer BME280 to 3.3V?");
  }

  // BH1750
  bhOK = lightMeter.begin();
  Serial.printf("[BH1750 0x%02X] %s\n", BH1750_ADDR, bhOK ? "OK" : "NOT FOUND");

  Serial.println();
  relayTest();

  Serial.println("Continuous reading starting (every 2 s)...\n");
}

// ============ LOOP ============
void loop() {
  Serial.println("----- MEASUREMENT -----");

  // BME280 inner
  if (bmeInnerOK) {
    float t  = bmeInner.readTemperature();
    float h  = bmeInner.readHumidity();
    float p  = bmeInner.readPressure() / 100.0f;
    Serial.printf("BME280 inner : T=%.2f °C  H=%.2f %%  P=%.1f hPa\n", t, h, p);
  } else {
    Serial.println("BME280 inner : --");
  }

  // BME280 outer
  if (bmeOuterOK) {
    float t = bmeOuter.readTemperature();
    float h = bmeOuter.readHumidity();
    float p = bmeOuter.readPressure() / 100.0f;
    Serial.printf("BME280 outer : T=%.2f °C  H=%.2f %%  P=%.1f hPa\n", t, h, p);
  } else {
    Serial.println("BME280 outer : --");
  }

  // BH1750
  if (bhOK) {
    float lx = lightMeter.readLightLevel();
    Serial.printf("BH1750       : %.1f lx\n", lx);
  } else {
    Serial.println("BH1750       : --");
  }

  // LM393
  int ldr = digitalRead(PIN_LDR_D);
  Serial.printf("LM393 DO     : %d  (%s)\n", ldr, ldr == LOW ? "bright" : "dark");

  // Soil moisture
  int soilRaw = analogRead(PIN_SOIL);
  float soilPct = 100.0f * (float)(SOIL_RAW_DRY - soilRaw) /
                  (float)(SOIL_RAW_DRY - SOIL_RAW_WET);
  if (soilPct < 0)   soilPct = 0;
  if (soilPct > 100) soilPct = 100;
  Serial.printf("Soil moisture : raw=%d  %%=%.1f\n", soilRaw, soilPct);
  Serial.println("  ! Calibration: measure in air and submerged, then update SOIL_RAW_DRY / SOIL_RAW_WET.\n");

  delay(2000);
}