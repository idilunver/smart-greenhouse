# 🛠️ Akıllı Sera - Donanım Kurulum Rehberi

Bu döküman, donanım montajını yapacak ekip arkadaşı için hazırlanmıştır.
ESP32 kodunun (`firmware/esp32_main.ino`) sorunsuz çalışması için aşağıdaki adımların izlenmesi gerekmektedir.

---

## 1. Arduino IDE Ayarları

### Board (Kart) Seçimi
- **Arduino IDE > Tools > Board** menüsünden `ESP32 Dev Module` seçilmelidir.
- Eğer ESP32 boardları görünmüyorsa:
  1. **File > Preferences** > "Additional Boards Manager URLs" bölümüne şu linki yapıştırın:
     ```
     https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
     ```
  2. **Tools > Board > Boards Manager** → "esp32" aratıp **"esp32 by Espressif Systems"** paketini kurun.

### Upload Ayarları
| Ayar | Değer |
| :--- | :--- |
| Board | ESP32 Dev Module |
| Upload Speed | 115200 |
| Flash Frequency | 80MHz |
| Partition Scheme | Default 4MB |
| Port | ESP32'nin bağlı olduğu COM portu |

---

## 2. Gerekli Arduino Kütüphaneleri

**Arduino IDE > Sketch > Include Library > Manage Libraries** menüsünden aşağıdaki kütüphanelerin **en güncel sürümlerini** kurmalısınız:

| # | Kütüphane Adı | Yazar | Ne İçin? |
| :--- | :--- | :--- | :--- |
| 1 | **Firebase ESP Client** | Mobizt | Firebase bağlantısı (RTDB Stream) |
| 2 | **WiFiManager** | tzapu | İlk WiFi kurulumunu tarayıcıdan yapmak |
| 3 | **Adafruit BME280 Library** | Adafruit | Sıcaklık + Nem sensörü okuma |
| 4 | **Adafruit Unified Sensor** | Adafruit | BME280'in bağımlılığı, otomatik istenecek |
| 5 | **BH1750** | Christopher Laws | Işık şiddeti (Lux) sensörü |

> **NOT:** `Adafruit BME280 Library` kurulurken Arduino IDE otomatik olarak `Adafruit Unified Sensor`'u da kurmayı önerecektir. "Install All" diyerek ikisini aynı anda kurun.

---

## 3. Firebase Bilgilerini Koda Girme

`firmware/esp32_main.ino` dosyasının üst kısmındaki şu iki satırı kendi Firebase projenizin bilgileriyle değiştirin:

```cpp
#define API_KEY "BURAYA_FIREBASE_API_KEY_YAZILACAK"
#define DATABASE_URL "BURAYA_FIREBASE_DATABASE_URL_YAZILACAK"
```

- **API_KEY:** Firebase Console > Project Settings > Web API Key
- **DATABASE_URL:** Firebase Console > Realtime Database > URL (Örn: `https://smart-greenhouse-xxxxx.europe-west1.firebasedatabase.app`)

---

## 4. Pin Bağlantı Şeması (ESP32 DevKit V1)

```
                    ┌─────────────────────┐
                    │     ESP32 DevKit     │
                    │                     │
   BME280 SDA ──────┤ GPIO 21 (SDA)       │
   BME280 SCL ──────┤ GPIO 22 (SCL)       │
   BH1750 SDA ──────┤ GPIO 21 (paralel)   │
   BH1750 SCL ──────┤ GPIO 22 (paralel)   │
   Toprak Nemi ─────┤ GPIO 34 (ADC)       │
   Röle Fan ────────┤ GPIO 18             │
   Röle Pompa ──────┤ GPIO 19             │
                    │                     │
                    └─────────────────────┘
```

### Detaylı Tablo

| Bileşen | ESP32 Pini | Bağlantı Tipi | Notlar |
| :--- | :--- | :--- | :--- |
| **BME280** (Sıcaklık/Nem) SDA | GPIO **21** | I2C | 3.3V ile beslenir |
| **BME280** (Sıcaklık/Nem) SCL | GPIO **22** | I2C | 3.3V ile beslenir |
| **BME280** VCC | **3.3V** | Güç | Kesinlikle 5V vermeyin! |
| **BME280** GND | **GND** | Toprak | |
| **BH1750** (Işık) SDA | GPIO **21** | I2C | BME280 ile aynı hattan paralel |
| **BH1750** (Işık) SCL | GPIO **22** | I2C | BME280 ile aynı hattan paralel |
| **BH1750** VCC | **3.3V** | Güç | |
| **BH1750** GND | **GND** | Toprak | |
| **Toprak Nemi Sensörü** (Analog) | GPIO **34** | ADC1 | Kapasitif sensör önerilir |
| **Toprak Nemi VCC** | **3.3V** | Güç | |
| **Röle Modülü - Fan** IN | GPIO **18** | Dijital Çıkış | Aktif HIGH |
| **Röle Modülü - Pompa** IN | GPIO **19** | Dijital Çıkış | Aktif HIGH |
| **Röle Modülü** VCC | **5V (Harici Adaptör)** | Güç | ESP32'den beslemeyin! |
| **Röle Modülü** GND | **GND (Ortak)** | Toprak | ESP32 + Adaptör GND birleşik |

### ⚠️ Güç Kaynağı Uyarısı

> **KRİTİK:** Pompa motoru ve fan yüksek akım çekebilir (~500mA+). ESP32'nin USB'sinden veya 3.3V/5V pininden beslemek ESP32'yi yakabilir!
> 
> **Doğru Yöntem:**
> 1. Röle modülünü ayrı bir **5V DC adaptör** ile besleyin.
> 2. ESP32'nin **GND** pini ile adaptörün **GND** ucunu birleştirin.
> 3. Fan/Pompa besleme kablosunu rölenin **COM** ve **NO** terminallerinden geçirin.

---

## 5. Toprak Nemi Sensörü Kalibrasyonu

Koddaki `readSensors()` fonksiyonunda şu satır var:

```cpp
current_soil = map(rawSoil, 3200, 1500, 0, 100);
```

Bu değerler **örnek değerlerdir** ve kendi sensörünüze göre ayarlanmalıdır:

### Kalibrasyon Adımları:

1. **Kuru Değer:** Sensörü havada tutun → Serial Monitor'de `rawSoil` değerini okuyun (Örn: `3400`)
2. **Islak Değer:** Sensörü bir bardak suya batırın → Serial Monitor'de `rawSoil` değerini okuyun (Örn: `1200`)
3. **Koda Yazın:**
   ```cpp
   current_soil = map(rawSoil, 3400, 1200, 0, 100);  // Kendi değerleriniz
   ```

---

## 6. İlk Çalıştırma ve Test

### Adım 1: Kodu Yükleyin
1. USB kabloyla ESP32'yi bilgisayara bağlayın.
2. Arduino IDE'de doğru **Port** seçili olsun.
3. **Upload** (→) butonuna basın.

### Adım 2: WiFi Ayarı (İlk Sefer)
1. ESP32 ilk açıldığında **"AkilliSera-Kurulum"** adında bir WiFi ağı oluşturacak.
2. Telefonunuzla bu ağa bağlanın.
3. Açılan sayfada ev/lab WiFi şifrenizi girin. (Bundan sonra otomatik bağlanır.)

### Adım 3: Serial Monitor Kontrol
- Arduino IDE > Tools > Serial Monitor (Baud: 115200)
- Şunları görmelisiniz:
  ```
  WiFi'a baglanildi!
  Firebase Auth Basarili
  [Cloud] Sensorler guncellendi.
  ```

### Adım 4: Offline Mode Testi
1. WiFi router'ı kapatın veya ESP32'yi kapsama alanı dışına çıkarın.
2. Serial Monitor'de şunu görmelisiniz:
   ```
   >>> BAGLANTI KOPTU: Offline Mode Aktif!
   [OFFLINE] Toprak kuru, pompa ACILDI.
   ```
3. WiFi geri geldiğinde:
   ```
   >>> BAGLANTI SAGLANDI: Cloud Mode Aktif!
   ```

---

## 7. Fail-Safe Davranışı Özeti

| Durum | ESP32 Davranışı |
| :--- | :--- |
| ✅ İnternet var | Buluttan gelen komutlara göre çalışır (Cloud Mode) |
| ❌ İnternet koptu | Kendi sensörlerine bakarak karar alır (Offline Mode) |
| 🔄 İnternet geri geldi | Kontrolü tekrar buluta devreder (Self-Healing) |
| 🌡️ Sıcaklık > 32°C (Offline) | Fan otomatik açılır |
| 💧 Toprak Nemi < %30 (Offline) | Pompa otomatik açılır |
