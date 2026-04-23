#include "firebase_io.h"
#include "sensors.h"
#include "actuators.h"
#include "config.h"
#include "secrets.h"

#include <Firebase_ESP_Client.h>
#include <addons/TokenHelper.h>

static FirebaseData   fbdo;
static FirebaseAuth   auth;
static FirebaseConfig config;

void firebase_init() {
  config.database_url = FIREBASE_HOST;
  config.api_key      = FIREBASE_API_KEY;
  config.token_status_callback = tokenStatusCallback;

  Firebase.reconnectWiFi(true);

  // Anonymous auth — Firebase Console'da "Anonymous" sign-in metodu AÇIK olmalı
  Serial.print("[Firebase] anonim giriş deneniyor");
  if (Firebase.signUp(&config, &auth, "", "")) {
    Serial.println(" OK");
  } else {
    Serial.printf(" HATA: %s\n", config.signer.signupError.message.c_str());
    Serial.println("  ! Firebase Console → Authentication → Sign-in method →");
    Serial.println("    Anonymous'u ENABLE yapmayı unutma.");
  }

  Firebase.begin(&config, &auth);
  Serial.println("[Firebase] init tamam");
}

bool firebase_is_ready() { return Firebase.ready(); }

void firebase_push_sensors(const SensorData& d) {
  if (!Firebase.ready()) {
    Serial.println("[Firebase] hazır değil, /sensors atlandı");
    return;
  }
  FirebaseJson j;
  j.set("temp_inner",     d.temp_inner);
  j.set("temp_outer",     d.temp_outer);
  j.set("humidity_inner", d.humidity_inner);
  j.set("humidity_outer", d.humidity_outer);
  j.set("soil_moisture",  d.soil_moisture);
  j.set("light_lux",      d.light_lux);
  j.set("light_digital",  d.light_digital);
  j.set("CO2",            d.CO2);
  j.set("voltage",        d.voltage);
  j.set("timestamp",      (int)d.timestamp);

  if (Firebase.RTDB.setJSON(&fbdo, FB_PATH_SENSORS, &j)) {
    Serial.println("[Firebase] /sensors OK");
  } else {
    Serial.printf("[Firebase] /sensors HATA: %s\n", fbdo.errorReason().c_str());
  }
}

void firebase_push_control_state(const ControlState& s) {
  if (!Firebase.ready()) return;
  FirebaseJson j;
  j.set("auto_mode", s.auto_mode);
  j.set("fan",       s.fan);
  j.set("pump",      s.pump);
  j.set("light",     s.light);
  // updateNode: sadece var olan key'leri günceller, diğerlerine dokunmaz
  if (!Firebase.RTDB.updateNode(&fbdo, FB_PATH_CONTROL, &j)) {
    Serial.printf("[Firebase] /control feedback HATA: %s\n", fbdo.errorReason().c_str());
  }
}

void firebase_poll_control(ControlState& s) {
  if (!Firebase.ready()) return;

  // auto_mode HER zaman okunur
  if (Firebase.RTDB.getInt(&fbdo, String(FB_PATH_CONTROL) + "/auto_mode")) {
    s.auto_mode = fbdo.to<int>();
  }

  // fan & pump sadece manuel mod'da Firebase'den alınır
  // (auto mode'da ESP32'nin kendi hesapladığı değer geçerli)
  if (s.auto_mode == 0) {
    if (Firebase.RTDB.getInt(&fbdo, String(FB_PATH_CONTROL) + "/fan")) {
      s.fan = fbdo.to<int>();
    }
    if (Firebase.RTDB.getInt(&fbdo, String(FB_PATH_CONTROL) + "/pump")) {
      s.pump = fbdo.to<int>();
    }
  }

  // light donanım yok ama state okunabilir
  if (Firebase.RTDB.getInt(&fbdo, String(FB_PATH_CONTROL) + "/light")) {
    s.light = fbdo.to<int>();
  }
}
