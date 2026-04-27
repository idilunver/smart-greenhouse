/**
 *  Smart Greenhouse Control System — ESP32 Firmware
 *  -------------------------------------------------
 *  Project : smart-greenhouse-9fb8e
 *  Hardware:
 *    - ESP32 DevKit V1
 *    - 2× BME280  (0x76 inner, 0x77 outer)
 *    - BH1750    (0x23)
 *    - LM393     (digital light switch)
 *    - Capacitive soil moisture sensor (analog)
 *    - 5V 2-channel relay → 12V pump + 12V fan
 *
 *  Mode: HYBRID  (auto_mode=1 autonomous, auto_mode=0 manual)
 *
 *  ==== ARDUINO IDE SETUP ====
 *  1) Boards Manager → install "esp32 by Espressif Systems"
 *  2) Tools → Board → select "ESP32 Dev Module"
 *  3) Install via Library Manager:
 *       - Adafruit BME280 Library         (Adafruit)
 *       - Adafruit Unified Sensor         (installed automatically)
 *       - BH1750                          (Christopher Laws)
 *       - Firebase Arduino Client Library for ESP8266 and ESP32  (Mobizt)
 *  4) Fill in FIREBASE_AUTH in secrets.h
 *  5) Upload!
 */

#include "config.h"
#include "secrets.h"
#include "wifi_time.h"
#include "sensors.h"
#include "actuators.h"
#include "firebase_io.h"

static SensorData   gSensors;
static ControlState gControl;   // default: auto_mode=1, all others 0

static unsigned long tLastRead = 0;
static unsigned long tLastPush = 0;
static unsigned long tLastPoll = 0;

void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println("\n==============================");
  Serial.println("  Smart Greenhouse ESP32 Firmware");
  Serial.println("==============================");

  actuators_init();
  sensors_init();
  wifi_connect();
  ntp_init();
  firebase_init();
}

void loop() {
  const unsigned long now = millis();

  // Reconnect if WiFi drops
  if (!wifi_is_connected()) {
    static unsigned long tLastRetry = 0;
    if (now - tLastRetry >= 10000UL) {
      tLastRetry = now;
      Serial.println("[WiFi] connection lost — retrying");
      wifi_connect();
    }
  }

  // 1) Read sensors
  if (now - tLastRead >= SENSOR_READ_MS) {
    tLastRead = now;
    sensors_read(gSensors);
    gSensors.CO2       = mock_co2();
    gSensors.timestamp = time_epoch();
    print_sensors(gSensors);
  }

  // 2) Fetch control state from Firebase
  if (now - tLastPoll >= CONTROL_POLL_MS) {
    tLastPoll = now;
    firebase_poll_control(gControl);
  }

  // 3) Hybrid decision logic
  if (gControl.auto_mode == 1) {
    apply_auto_control(gSensors, gControl);
  }

  // 4) Update relays
  apply_actuators(gControl);

  // 5) Write data to Firebase
  if (now - tLastPush >= FIREBASE_PUSH_MS) {
    tLastPush = now;
    firebase_push_sensors(gSensors);
    // Allow the frontend to observe the real state in autonomous mode
    if (gControl.auto_mode == 1) {
      firebase_push_control_state(gControl);
    }
  }
}