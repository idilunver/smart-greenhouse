#pragma once
#include <Arduino.h>

// Single data packet read from all sensors — transmitted to Firebase
struct SensorData {
  float temp_inner     = 0;
  float temp_outer     = 0;
  float humidity_inner = 0;
  float humidity_outer = 0;
  float soil_moisture  = 0;   // percentage (0-100)
  int   light_lux      = 0;   // BH1750 (actual illuminance)
  int   light_digital  = 0;   // LM393 (0 = dark, 1 = bright)
  int   CO2            = 0;   // ppm — no physical sensor, mocked
  float voltage        = 0;   // V — voltage divider not yet connected (0)
  long  timestamp      = 0;   // Unix epoch (seconds)
};

void sensors_init();
void sensors_read(SensorData& d);
int  mock_co2();
void print_sensors(const SensorData& d);