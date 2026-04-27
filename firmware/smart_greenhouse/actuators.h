#pragma once
#include <Arduino.h>

struct SensorData;   // forward decl

struct ControlState {
  int auto_mode = 1;   // 1 = autonomous, 0 = manual (Firebase)
  int fan       = 0;
  int pump      = 0;
  int light     = 0;   // present in schema, no hardware — state only
};

void actuators_init();
void apply_actuators(const ControlState& s);
void apply_auto_control(const SensorData& d, ControlState& s);