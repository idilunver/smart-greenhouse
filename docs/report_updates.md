# Akıllı Sera Projesi - Rapor ve Sunum Güncellemeleri

Bu doküman, projenizin revize edilmiş haline ("Cloud-Native" ve "Digital Twin" destekli sürüm) uygun olarak mevcut akademik raporunuzda ve sunumunuzda yapabileceğiniz güncellemeleri içermektedir.

---

## 1. Metodoloji ve Mimari Güncellemesi (Rapora Eklenecek Metin)

**Eski YAPI:** Sistem, yerel bir bilgisayar üzerinden Python betikleriyle Firebase'e veri göndermektedir...
**YENİ YAPI (Güncellenmiş Metin):**
> "Geliştirdiğimiz Akıllı Sera Sistemi, yerel makine bağımlılığından kurtarılarak tamamen **'Cloud-Native' (Bulut Tabanlı)** bir mimariye taşınmıştır. Sistem verileri uzak bir Ubuntu sunucusu (veya ESP32 donanımı) üzerinden Firebase Realtime Database'e 7/24 kesintisiz olarak aktarılmaktadır.
> 
> Ayrıca donanım entegrasyonundan önce sistemin yazılımsal kararlılığını ve asenkron tepki süresini ölçmek amacıyla bir **'Digital Twin' (Dijital İkiz)** simülasyonu geliştirilmiştir. Bu aşama raporda **"Saha Öncesi Mantıksal Testler"** olarak adlandırılmaktadır. Bu simülatör, sistemin fiziksel bir kopyası gibi davranarak; kullanıcının arayüzden verdiği komutlara (örn. pompanın açılması) gerçek zamanlı tepki vermekte, toprak neminin artışı ve ortam sıcaklığının dış atmosfere uyumu gibi termodinamik fizik kurallarını sanal ortamda başarılı bir şekilde taklit etmektedir.
>
> *Not:* Şu an veriler simülasyon üzerinden akmaktadır ancak sistem mimarisi **'Plug-and-Play' (Tak-Çalıştır)** özelliğine sahiptir. Donanım bağlandığı anda kodda değişiklik yapılmadan gerçek veriler işlenmeye başlayacaktır.

## 2. Donanım ve Pin Bağlantı Şeması (Rapor Ekleri)

Donanım bileşenleri geldiğinde sisteme entegrasyonu hızlandırmak için aşağıdaki pin haritası (Pinout) belirlenmiştir. Bu haritayı bir Fritzing diyagramı ile raporunuza ekleyebilirsiniz.

### ESP32 Mikrodenetleyici Bağlantı Haritası

| Bileşen | Pin/Bağlantı Tipi | Açıklama |
| :--- | :--- | :--- |
| **BME280** (Sıcaklık/Nem) | I2C (SDA: **21**, SCL: **22**) | I2C hattında paralel bağlanmalıdır (3.3V) |
| **BH1750** (Işık/Lüx) | I2C (SDA: **21**, SCL: **22**) | BME280 ile aynı hattan paralel çekilebilir |
| **Toprak Nemi Sensörü** (Analog) | Analog ADC (**34** veya 35) | Korozyonu önlemek için kapasitif sensör önerilir |
| **Röle - Su Pompası** | Dijital Çıkış (GPIO **19**) | Rölenin IN1 pinine bağlanır |
| **Röle - Havalandırma Fanı** | Dijital Çıkış (GPIO **18**) | Rölenin IN2 pinine bağlanır |
| **MH-Z19B** (Karbon Dioksit) | UART (TX: **17**, RX: **16**) | Opsiyonel Serial iletişim pini |

> **Bağlantı Uyarısı:** Su pompası ve fan yüksek akım çektiği için ESP32'nin 5V pininden beslenmek yerine ayrı bir 5V adaptör veya güçlü bir regülatör üzerinden beslenmeli, ESP32 ve harici güç kaynağının **GND** hatları ortak bağlanmalıdır.

## 3. Yapay Zeka (Gemini) Entegrasyonu Hakkında Not

> "Sistemde yer alan AI asistan modülü, yalnızca verileri ekrana yansıtmakla kalmayıp 'İnce Ayar' (Fine-Tuning/Prompt Engineering) optimizasyonları ile donatılmıştır. Kullanıcının arayüzden seçtiği hedef bitki türüne (örn. Domates, Marul) göre ideal tolerans aralıklarını dinamik olarak hesaplamaktadır. Ayrıca veri akışında oluşabilecek donanımsal kesintileri veya sensör kopmalarını (örn. değerlerin aniden 0'a veya 999'a sıçraması) bir 'anomaly detection' (anomali tespiti) mantığıyla anında analiz ederek kullanıcıyı kablo/sensör bağlantılarını kontrol etmesi yönünde uyarmaktadır."
