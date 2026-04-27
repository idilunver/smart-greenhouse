#include "sensors.h"
#include "config.h"
#include <Wire.h>
#include <Adafruit_BME280.h>
#include <BH1750.h>

static Adafruit_BME280 bmeInner;
static Adafruit_BME280 bmeOuter;
static BH1750 lightMeter(BH1750_ADDR);

static bool bmeInnerOK = false;
static bool bmeOuterOK = false;
static bool bhOK       = false;

void sensors_init() {
  Wire.begin(PIN_SDA, PIN_SCL);

  bmeInnerOK = bmeInner.begin(BME_INNER_ADDR);
  Serial.printf("[BME280 inner 0x%02X] %s\n", BME_INNER_ADDR, bmeInnerOK ? "OK" : "NOT FOUND");

  bmeOuterOK = bmeOuter.begin(BME_OUTER_ADDR);
  Serial.printf("[BME280 outer 0x%02X] %s\n", BME_OUTER_ADDR, bmeOuterOK ? "OK" : "NOT FOUND");

  bhOK = lightMeter.begin();
  Serial.printf("[BH1750 0x%02X] %s\n", BH1750_ADDR, bhOK ? "OK" : "NOT FOUND");

  analogReadResolution(12);         // 0-4095
  pinMode(PIN_SOIL,  INPUT);
  pinMode(PIN_LDR_D, INPUT);

  // Seed for mock CO2
  randomSeed(esp_random());
}

void sensors_read(SensorData& d) {
  if (bmeInnerOK) {
    d.temp_inner     = bmeInner.readTemperature();
    d.humidity_inner = bmeInner.readHumidity();
  }
  if (bmeOuterOK) {
    d.temp_outer     = bmeOuter.readTemperature();
    d.humidity_outer = bmeOuter.readHumidity();
  }
  if (bhOK) {
    float lx = lightMeter.readLightLevel();
    d.light_lux = (lx >= 0) ? (int)lx : 0;
  }

  // LM393: on most modules DO=LOW above the potentiometer threshold (light present),
  // DO=HIGH below the threshold (dark). Change to == HIGH if behaviour is inverted.
  d.light_digital = (digitalRead(PIN_LDR_D) == LOW) ? 1 : 0;

  // Capacitive soil moisture — dry=high raw value, wet=low raw value
  int raw = analogRead(PIN_SOIL);
  float pct = 100.0f * (float)(SOIL_RAW_DRY - raw) /
              (float)(SOIL_RAW_DRY - SOIL_RAW_WET);
  if (pct < 0)   pct = 0;
  if (pct > 100) pct = 100;
  d.soil_moisture = pct;

  // TODO: read when voltage divider is connected
  d.voltage = 0.0f;
}

int mock_co2() {
  // Realistic greenhouse CO2: 900-1500 ppm, slightly fluctuating random walk
  static int base = 1200;
  base += random(-25, 26);
  if (base < 900)  base = 900;
  if (base > 1500) base = 1500;
  return base;
}

void print_sensors(const SensorData& d) {
  Serial.printf(
    "[SENS] T_in=%.1f T_out=%.1f H_in=%.1f H_out=%.1f "
    "soil=%.1f%% lux=%d ld=%d CO2=%d V=%.2f ts=%ld\n",
    d.temp_inner, d.temp_outer,
    d.humidity_inner, d.humidity_outer,
    d.soil_moisture, d.light_lux, d.light_digital,
    d.CO2, d.voltage, d.timestamp);
}