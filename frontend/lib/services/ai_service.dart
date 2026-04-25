import 'package:flutter/material.dart';
import '../config/env.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AIService {
  static GenerativeModel? _model;

  // ─── Bitki Kütüphanesi: İdeal aralıklar ────────────────────────────────────
  static const Map<String, Map<String, dynamic>> _plantRules = {
    'Domates':    {'temp': [18, 28], 'hum': [60, 80], 'soil': [40, 60], 'vpd': [0.8, 1.5]},
    'Salatalık':  {'temp': [22, 30], 'hum': [70, 90], 'soil': [40, 60], 'vpd': [0.8, 1.6]},
    'Marul':      {'temp': [15, 22], 'hum': [70, 90], 'soil': [50, 70], 'vpd': [0.4, 1.2]},
    'Biber':      {'temp': [20, 30], 'hum': [50, 70], 'soil': [30, 50], 'vpd': [0.8, 1.5]},
    'Genel':      {'temp': [20, 30], 'hum': [50, 80], 'soil': [30, 60], 'vpd': [0.5, 1.5]},
  };

  // ─── Model — System Instruction genel, değişmez ─────────────────────────────
  static GenerativeModel _getOrCreateModel() {
    if (_model == null) {
      _model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: Env.geminiApiKey,
        systemInstruction: Content.system(
          'Sen akıllı bir seranın yaşayan zekası ve dijital koruyucususun. '
          'Bir ziraat uzmanının bilgisine ve bir doğa dostunun sıcaklığına sahipsin. '
          'Karmaşık sensör verilerini anlamlandırıp kullanıcıya rehberlik edersin. '
          'Kişi isimleri kullanma. Samimi, bilge ve yardımcı bir üslup benimse. '
          'Teknik terimleri doğalca kullan: VPD yüksekse "terleme artıyor", '
          'CO2 düşükse "fotosentez yavaşlıyor" de. '
          'Cevapların öz ve anlaşılır olsun; gereksiz teknik detaylardan kaçın.',
        ),
      );
    }
    return _model!;
  }

  // ─── Ana Yanıt Fonksiyonu ───────────────────────────────────────────────────
  static Future<String> getChatResponse({
    required String message,
    required Map sensorData,
    required Map settingsData,
    required Map controlsData,
  }) async {
    try {
      final model = _getOrCreateModel();

      // Bitki listesini düzenle
      final rawPlants = settingsData['plants'];
      final List<String> plants = rawPlants is List
          ? rawPlants.map((p) => p.toString().split(' ').first).toList()
          : ['Genel'];

      final int autoMode = (controlsData['auto_mode'] ?? 0) is bool
          ? ((controlsData['auto_mode'] == true) ? 1 : 0)
          : int.tryParse(controlsData['auto_mode'].toString()) ?? 0;

      // Bitki kural özetini oluştur
      final StringBuffer plantRulesText = StringBuffer();
      for (final plant in plants) {
        final rule = _plantRules[plant] ?? _plantRules['Genel']!;
        plantRulesText.writeln(
          '- $plant: Sıcaklık ${rule['temp'][0]}-${rule['temp'][1]}°C, '
          'Nem %${rule['hum'][0]}-${rule['hum'][1]}, '
          'Toprak %${rule['soil'][0]}-${rule['soil'][1]}, '
          'VPD ${rule['vpd'][0]}-${rule['vpd'][1]} kPa',
        );
      }

      // Sensör değerlerini oku
      final double tempInner = double.tryParse(sensorData['temp_inner']?.toString() ?? '0') ?? 0;
      final double humInner  = double.tryParse(sensorData['humidity_inner']?.toString() ?? '0') ?? 0;
      final double soil      = double.tryParse(sensorData['soil_moisture']?.toString() ?? '0') ?? 0;
      final double lux       = double.tryParse(sensorData['light_lux']?.toString() ?? '0') ?? 0;
      final double co2       = double.tryParse(sensorData['CO2']?.toString() ?? '0') ?? 0;
      final double tempOuter = double.tryParse(sensorData['temp_outer']?.toString() ?? '0') ?? 0;
      final double humOuter  = double.tryParse(sensorData['humidity_outer']?.toString() ?? '0') ?? 0;

      final bool fanOn   = (controlsData['fan']   == 1 || controlsData['fan']   == true);
      final bool pumpOn  = (controlsData['pump']  == 1 || controlsData['pump']  == true);
      final bool lightOn = (controlsData['light'] == 1 || controlsData['light'] == true);
      final String gece  = lux < 50 ? 'Gece (lux < 50, bitkiler dinlenmede)' : 'Gündüz';

      // ── Dinamik Bağlam Prompt'u ──────────────────────────────────────────
      final String contextPrompt = '''
[SİSTEM BAĞLAMI — kullanıcıya bu bloğu gösterme]

=== SERA DURUMU ===
Yetiştirilen Bitkiler: ${plants.join(', ')}
Zaman Dilimi: $gece

Sensörler (İç):
  • Sıcaklık: ${tempInner}°C
  • Nem: %$humInner
  • Toprak Nemi: %$soil
  • Işık: $lux lux
  • CO₂: $co2 ppm

Sensörler (Dış):
  • Sıcaklık: ${tempOuter}°C
  • Nem: %$humOuter

Aktüatör Durumları:
  • Fan: ${fanOn ? 'AÇIK' : 'KAPALI'}
  • Pompa: ${pumpOn ? 'AÇIK' : 'KAPALI'}
  • Işık/Sisleme: ${lightOn ? 'AÇIK' : 'KAPALI'}

Çalışma Modu: ${autoMode == 1 ? 'OTOMATİK (auto_mode=1)' : 'MANUEL (auto_mode=0)'}

=== BİTKİ İDEAL DEĞERLERİ ===
$plantRulesText
=== AKSIYON KURALLARI (ÇOK ÖNEMLİ) ===
• VPD > 1.5 kPa → Toprak nemini kontrol et, sulamayı tetikle.
• Gece saatlerinde (lux < 50) sulamayı olabildiğince azalt.
• CO₂ < 400 ppm → "Fotosentez yavaşlıyor" uyarısı ver.
• Temp_inner > bitkinin maks sıcaklığı → Fan çalıştır.

=== MOD DAVRANIŞ KURALLARI ===
EĞER auto_mode == 1:
  - Aksiyonu KENDİN al, kullanıcıya "… yaptım" diye bildir.
  - Mesajının SONUNA görünmez aksiyon kodunu ekle.
EĞER auto_mode == 0 (MANUEL):
  - ASLA kendin aksiyon ALMA.
  - "… yapmamı ister misin?" diye onay sor.
  - Kullanıcı "Evet" derse mesajının sonuna aksiyon kodunu ekle.

=== AKSIYON KOD FORMATI ===
Mesajın sonuna, boşluksuz ve büyük harfle:
[ACTION:FAN:ON], [ACTION:FAN:OFF]
[ACTION:PUMP:ON], [ACTION:PUMP:OFF]
[ACTION:LIGHT:ON], [ACTION:LIGHT:OFF]
Birden fazla olabilir. Gerekli değilse ekleme.

===========================

Kullanıcı Sorusu: $message
''';

      final response = await model.generateContent([Content.text(contextPrompt)]);
      return response.text ?? 'Üzgünüm, şu an yanıt üretemiyorum.';
    } catch (e) {
      debugPrint('AI Hatası: $e');
      if (e.toString().contains('429')) {
        return 'Günlük AI kotası doldu, veriler normal şekilde izleniyor.';
      }
      return 'Üzgünüm, AI yanıt veremiyor. Lütfen bağlantınızı kontrol edin.';
    }
  }
}
