/**
 *  Akıllı Sera Kontrol Sistemi — ESP32 Firmware
 *  ---------------------------------------------
 *  Proje : smart-greenhouse-9fb8e
 *  Donanım:
 *    - ESP32 DevKit V1
 *    - 2× BME280  (0x76 iç, 0x77 dış)
 *    - BH1750    (0x23)
 *    - LM393     (dijital ışık anahtarı)
 *    - Kapasitif toprak nem sensörü (analog)
 *    - 5V 2 kanallı röle → 12V pompa + 12V fan
 *
 *  Mod: HİBRİT  (auto_mode=1 otonom, auto_mode=0 manuel)
 *
 *  ==== ARDUINO IDE KURULUMU ====
 *  1) Boards Manager → "esp32 by Espressif Systems" kur
 *  2) Tools → Board → "ESP32 Dev Module" seç
 *  3) Library Manager'dan kur:
 *       - Adafruit BME280 Library         (Adafruit)
 *       - Adafruit Unified Sensor         (otomatik gelir)
 *       - BH1750                          (Christopher Laws)
 *       - Firebase Arduino Client Library for ESP8266 and ESP32  (Mobizt)
 *  4) secrets.h dosyasındaki FIREBASE_AUTH'u doldur
 *  5) Upload!
 */

#include "config.h"
#include "secrets.h"
#include "wifi_time.h"
#include "sensors.h"
#include "actuators.h"
#include "firebase_io.h"

static SensorData   gSensors;
static ControlState gControl;   // default: auto_mode=1, diğerleri 0

static unsigned long tLastRead = 0;
static unsigned long tLastPush = 0;
static unsigned long tLastPoll = 0;

void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println("\n==============================");
  Serial.println("  Akıllı Sera ESP32 Firmware");
  Serial.println("==============================");

  actuators_init();
  sensors_init();
  wifi_connect();
  ntp_init();
  firebase_init();
}

void loop() {
  const unsigned long now = millis();

  // WiFi düşerse yeniden bağlan
  if (!wifi_is_connected()) {
    static unsigned long tLastRetry = 0;
    if (now - tLastRetry >= 10000UL) {
      tLastRetry = now;
      Serial.println("[WiFi] bağlantı kopuk — yeniden deneniyor");
      wifi_connect();
    }
  }

  // 1) Sensörleri oku
  if (now - tLastRead >= SENSOR_READ_MS) {
    tLastRead = now;
    sensors_read(gSensors);
    gSensors.CO2       = mock_co2();
    gSensors.timestamp = time_epoch();
    print_sensors(gSensors);
  }

  // 2) Firebase'den kontrol durumunu al
  if (now - tLastPoll >= CONTROL_POLL_MS) {
    tLastPoll = now;
    firebase_poll_control(gControl);
  }

  // 3) Hibrit karar mantığı
  if (gControl.auto_mode == 1) {
    apply_auto_control(gSensors, gControl);
  }

  // 4) Röleleri güncelle
  apply_actuators(gControl);

  // 5) Firebase'e verileri yaz
  if (now - tLastPush >= FIREBASE_PUSH_MS) {
    tLastPush = now;
    firebase_push_sensors(gSensors);
    // Otonom mod'da frontend gerçek durumu görebilsin
    if (gControl.auto_mode == 1) {
      firebase_push_control_state(gControl);
    }
  }
}
