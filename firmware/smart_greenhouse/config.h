#pragma once

// ===================== PIN HARİTASI =====================
// ESP32 DevKit V1 (38 pin)
#define PIN_SDA          21   // I2C veri
#define PIN_SCL          22   // I2C saat
#define PIN_SOIL         34   // ADC1_CH6 — kapasitif toprak nem (input-only)
#define PIN_LDR_D        35   // LM393 dijital çıkış (input-only)
#define PIN_RELAY_PUMP   26   // Röle kanal 1 → 12V su pompası
#define PIN_RELAY_FAN    27   // Röle kanal 2 → 12V fan

// Röle mantığı — çoğu ucuz 5V 2-kanallı modül ACTIVE-LOW'dur
// 1 = LOW sinyali röleyi AÇAR, 0 = HIGH sinyali KAPATIR
// Modülün ters çalışıyorsa bunu 0 yap
#define RELAY_ACTIVE_LOW 0

// ===================== I2C ADRESLERİ =====================
#define BME_INNER_ADDR   0x76   // İç sensör: SDO → GND
#define BME_OUTER_ADDR   0x77   // Dış sensör: SDO → 3.3V
#define BH1750_ADDR      0x23   // ADDR → GND (default)

// ===================== ZAMANLAMALAR (ms) =====================
#define SENSOR_READ_MS    2000   // sensörleri 2 sn'de bir oku
#define FIREBASE_PUSH_MS  5000   // 5 sn'de bir Firebase'e yaz
#define CONTROL_POLL_MS   2000   // 2 sn'de bir /control yolunu oku

// ===================== TOPRAK NEM KALİBRASYONU =====================
// Sensörü havada ölç → SOIL_RAW_DRY; bir bardak suya batır → SOIL_RAW_WET
// Kendi değerlerinle güncelle!
#define SOIL_RAW_DRY     3000
#define SOIL_RAW_WET     1200

// ===================== OTONOM MOD EŞİKLERİ =====================
// Pompa — toprak nemi histerezisli
#define AUTO_PUMP_SOIL_BELOW       35.0f   // < %35 → pompa AÇ
#define AUTO_PUMP_SOIL_ABOVE       60.0f   // > %60 → pompa KAPAT

// Fan — iç sıcaklık veya iç nem eşiği
#define AUTO_FAN_TEMP_ABOVE        28.0f   // > 28°C → fan AÇ
#define AUTO_FAN_TEMP_BELOW        25.0f   // < 25°C → fan KAPAT
#define AUTO_FAN_HUMIDITY_ABOVE    80.0f   // > %80 nem → fan AÇ

// ===================== NTP (ZAMAN DAMGASI) =====================
#define NTP_SERVER            "pool.ntp.org"
#define GMT_OFFSET_SEC        (3 * 3600)   // UTC+3 (Türkiye)
#define DAYLIGHT_OFFSET_SEC   0

// ===================== FIREBASE YOLLARI =====================
#define FB_PATH_SENSORS   "/sensors"
#define FB_PATH_CONTROL   "/control"
