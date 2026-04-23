#pragma once
#include <Arduino.h>

// Tüm sensörlerden okunan tek paket — Firebase'e bu gider
struct SensorData {
  float temp_inner     = 0;
  float temp_outer     = 0;
  float humidity_inner = 0;
  float humidity_outer = 0;
  float soil_moisture  = 0;   // yüzde (0-100)
  int   light_lux      = 0;   // BH1750 (gerçek ışık şiddeti)
  int   light_digital  = 0;   // LM393 (0 = karanlık, 1 = aydınlık)
  int   CO2            = 0;   // ppm — sensör yok, mock
  float voltage        = 0;   // V — gerilim bölücü eklenmedi (0)
  long  timestamp      = 0;   // Unix epoch (saniye)
};

void sensors_init();
void sensors_read(SensorData& d);
int  mock_co2();
void print_sensors(const SensorData& d);
