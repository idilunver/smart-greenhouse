#include "wifi_time.h"
#include "config.h"
#include "secrets.h"
#include <WiFi.h>
#include <time.h>

void wifi_connect() {
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  Serial.printf("[WiFi] connecting to %s", WIFI_SSID);

  unsigned long t0 = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - t0 < 20000UL) {
    delay(300);
    Serial.print(".");
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf(" OK  IP=%s  RSSI=%d\n",
                  WiFi.localIP().toString().c_str(), WiFi.RSSI());
  } else {
    Serial.println(" FAILED — will retry in 10 s");
  }
}

bool wifi_is_connected() {
  return WiFi.status() == WL_CONNECTED;
}

void ntp_init() {
  configTime(GMT_OFFSET_SEC, DAYLIGHT_OFFSET_SEC, NTP_SERVER);
  Serial.print("[NTP] awaiting synchronisation");
  unsigned long t0 = millis();
  while (time(nullptr) < 1700000000L && millis() - t0 < 10000UL) {
    delay(200);
    Serial.print(".");
  }
  time_t now = time(nullptr);
  Serial.printf(" epoch=%ld\n", (long)now);
}

long time_epoch() {
  return (long) time(nullptr);
}