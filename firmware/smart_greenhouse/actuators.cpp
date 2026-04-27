#include "actuators.h"
#include "sensors.h"
#include "config.h"

static inline int relayLevel(int onOff) {
#if RELAY_ACTIVE_LOW
  return onOff ? LOW : HIGH;
#else
  return onOff ? HIGH : LOW;
#endif
}

void actuators_init() {
  pinMode(PIN_RELAY_PUMP, OUTPUT);
  pinMode(PIN_RELAY_FAN,  OUTPUT);
  // All outputs OFF at startup
  digitalWrite(PIN_RELAY_PUMP, relayLevel(0));
  digitalWrite(PIN_RELAY_FAN,  relayLevel(0));
  Serial.println("[Actuators] init OK (pump+fan OFF)");
}

void apply_actuators(const ControlState& s) {
  digitalWrite(PIN_RELAY_PUMP, relayLevel(s.pump));
  digitalWrite(PIN_RELAY_FAN,  relayLevel(s.fan));
  // s.light → no hardware, ignored
}

// Autonomous mode: pump/fan decision based on sensor data — with hysteresis
void apply_auto_control(const SensorData& d, ControlState& s) {
  // Pump (soil moisture)
  if (d.soil_moisture < AUTO_PUMP_SOIL_BELOW)      s.pump = 1;
  else if (d.soil_moisture > AUTO_PUMP_SOIL_ABOVE) s.pump = 0;

  // Fan (inner temperature or humidity)
  bool tempHigh = d.temp_inner     > AUTO_FAN_TEMP_ABOVE;
  bool humHigh  = d.humidity_inner > AUTO_FAN_HUMIDITY_ABOVE;
  bool tempLow  = d.temp_inner     < AUTO_FAN_TEMP_BELOW;

  if (tempHigh || humHigh)            s.fan = 1;
  else if (tempLow && !humHigh)       s.fan = 0;
}