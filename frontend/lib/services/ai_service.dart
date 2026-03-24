import 'package:flutter/material.dart';
import '../config/env.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AIService {
  static GenerativeModel? _model;

  static GenerativeModel _getOrCreateModel() {
    final apiKey = Env.geminiApiKey;
    if (_model == null) {
      _model = GenerativeModel(
        model: 'gemini-3-flash-preview',
        apiKey: apiKey,
        systemInstruction: Content.system(
          "Sen bu akıllı seranın yaşayan zekası ve dijital koruyucusun. Bir ziraat uzmanının bilgisine "
          "ve bir doğa dostunun sıcaklığına sahipsin. Görevin, karmaşık sensör verilerini anlamlandırıp "
          "kullanıcıya rehberlik etmektir. Kişi isimleri kullanma. Samimi, bilge ve yardımcı bir üslup kullan. "
          "Teknik verileri doğalca yedir ama çok uzun anlatma. Cevapların en fazla 2 cümle olsun. "
          "Sorun varsa nazikçe çözüm öner, yoksa kısa bir onay ver."
        ),
      );
    }
    return _model!;
  }

  static Future<String> getChatResponse(String message, Map sensorData) async {
    try {
      final model = _getOrCreateModel();
      final prompt = "Güncel Sensör Durumu: $sensorData. Kullanıcı Sorusu: $message";
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? "Üzgünüm, şu an yanıt üretemiyorum.";
    } catch (e) {
      debugPrint("AI Hatası: $e");
      return "Üzgünüm, şu an AI yanıt veremiyor. Lütfen API anahtarınızı ve internetinizi kontrol edin.";
    }
  }
}
