import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AIService {
  static GenerativeModel? _model;

  static GenerativeModel _getOrCreateModel() {
    final apiKey = (dotenv.env['GEMINI_API_KEY'] ?? "").trim();
    if (_model == null) {
      _model = GenerativeModel(
        model: 'gemini-3-flash-preview',
        apiKey: apiKey,
        systemInstruction: Content.system(
          "Sen 'Smart Greenhouse' sisteminin beynisin. Bir ziraat mühendisi ve veri analisti gibi davran. "
          "Sana JSON formatında sensör verileri gelecek. Veriler normalse 'Sistem stabil' de. "
          "Eğer bir parametre bitki sağlığını tehdit ediyorsa (Örn: Nem %40'ın altındaysa) hemen teknik bir uyarı yap ve "
          "aktüatör (fan, pompa vb.) önerisinde bulun. Kısa, net ve aksiyon odaklı ol. "
          "Kullanıcıya ismiyle hitap etme."
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
