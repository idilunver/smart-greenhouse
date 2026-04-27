#pragma once

// ===================== PIN MAP =====================
// ESP32 DevKit V1 (38 pin)
#define PIN_SDA          21   // I2C data
#define PIN_SCL          22   // I2C clock
#define PIN_SOIL         34   // ADC1_CH6 — capacitive soil moisture (input-only)
#define PIN_LDR_D        35   // LM393 digital output (input-only)
#define PIN_RELAY_PUMP   26   // Relay channel 1 → 12V water pump
#define PIN_RELAY_FAN    27   // Relay channel 2 → 12V fan

// Relay logic — most inexpensive 5V 2-channel modules are ACTIVE-LOW
// 1 = LOW signal ACTIVATES the relay, 0 = HIGH signal DEACTIVATES it
// Set to 0 if the module behaves in reverse
#define RELAY_ACTIVE_LOW 1

// ===================== I2C ADDRESSES =====================
#define BME_INNER_ADDR   0x76   // Inner sensor: SDO → GND
#define BME_OUTER_ADDR   0x77   // Outer sensor: SDO → 3.3V
#define BH1750_ADDR      0x23   // ADDR → GND (default)

// ===================== TIMING (ms) =====================
#define SENSOR_READ_MS    2000   // read sensors every 2 s
#define FIREBASE_PUSH_MS  5000   // write to Firebase every 5 s
#define CONTROL_POLL_MS   2000   // read /control path every 2 s

// ===================== SOIL MOISTURE CALIBRATION =====================
// Measure sensor in air → SOIL_RAW_DRY; submerge in a cup of water → SOIL_RAW_WET
// Update with your own measured values!
#define SOIL_RAW_DRY     3000
#define SOIL_RAW_WET     1200

// ===================== AUTONOMOUS MODE THRESHOLDS =====================
// Pump — soil moisture with hysteresis
#define AUTO_PUMP_SOIL_BELOW       35.0f   // < 35% → pump ON
#define AUTO_PUMP_SOIL_ABOVE       60.0f   // > 60% → pump OFF

// Fan — inner temperature or inner humidity threshold
#define AUTO_FAN_TEMP_ABOVE        28.0f   // > 28°C → fan ON
#define AUTO_FAN_TEMP_BELOW        25.0f   // < 25°C → fan OFF
#define AUTO_FAN_HUMIDITY_ABOVE    80.0f   // > 80% humidity → fan ON

// ===================== NTP (TIMESTAMP) =====================
#define NTP_SERVER            "pool.ntp.org"
#define GMT_OFFSET_SEC        (3 * 3600)   // UTC+3 (Turkey)
#define DAYLIGHT_OFFSET_SEC   0

// ===================== FIREBASE PATHS =====================
#define FB_PATH_SENSORS   "/sensors"
#define FB_PATH_CONTROL   "/control"