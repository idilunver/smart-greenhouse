#pragma once

struct SensorData;
struct ControlState;

void firebase_init();
bool firebase_is_ready();
void firebase_push_sensors(const SensorData& d);
void firebase_push_control_state(const ControlState& s);  // state feedback in auto mode
void firebase_poll_control(ControlState& s);