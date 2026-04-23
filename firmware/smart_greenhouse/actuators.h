#pragma once
#include <Arduino.h>

struct SensorData;   // forward decl

struct ControlState {
  int auto_mode = 1;   // 1 = otonom, 0 = manuel (Firebase)
  int fan       = 0;
  int pump      = 0;
  int light     = 0;   // sözlükte var, donanım yok — yalnızca state
};

void actuators_init();
void apply_actuators(const ControlState& s);
void apply_auto_control(const SensorData& d, ControlState& s);
