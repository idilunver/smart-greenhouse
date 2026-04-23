#pragma once
#include <Arduino.h>

void wifi_connect();
bool wifi_is_connected();
void ntp_init();
long time_epoch();   // Unix epoch saniye (10 haneli)
