import 'package:flutter/material.dart';
import '../config/env.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AIService {
  static GenerativeModel? _model;

  // ─── Plant Library: Ideal ranges ────────────────────────────────────────────
  static const Map<String, Map<String, dynamic>> _plantRules = {
    'Domates':    {'temp': [18, 28], 'hum': [60, 80], 'soil': [40, 60], 'vpd': [0.8, 1.5]},
    'Salatalık':  {'temp': [22, 30], 'hum': [70, 90], 'soil': [40, 60], 'vpd': [0.8, 1.6]},
    'Marul':      {'temp': [15, 22], 'hum': [70, 90], 'soil': [50, 70], 'vpd': [0.4, 1.2]},
    'Biber':      {'temp': [20, 30], 'hum': [50, 70], 'soil': [30, 50], 'vpd': [0.8, 1.5]},
    'Genel':      {'temp': [20, 30], 'hum': [50, 80], 'soil': [30, 60], 'vpd': [0.5, 1.5]},
  };

  // ─── Model — System Instruction: general, immutable ─────────────────────────
  static GenerativeModel _getOrCreateModel() {
    if (_model == null) {
      _model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: Env.geminiApiKey,
        systemInstruction: Content.system(
          'You are the living intelligence and digital guardian of a smart greenhouse. '
          'You possess the knowledge of an agricultural expert and the warmth of a nature enthusiast. '
          'You interpret complex sensor data and provide guidance to the user. '
          'Do not use personal names. Adopt a warm, wise, and helpful tone. '
          'Use technical terms naturally: if VPD is high, say "transpiration is increasing"; '
          'if CO2 is low, say "photosynthesis is slowing down". '
          'Keep responses concise and clear; avoid unnecessary technical detail.',
        ),
      );
    }
    return _model!;
  }

  // ─── Main Response Function ──────────────────────────────────────────────────
  static Future<String> getChatResponse({
    required String message,
    required Map sensorData,
    required Map settingsData,
    required Map controlsData,
  }) async {
    try {
      final model = _getOrCreateModel();

      // Normalise plant list
      final rawPlants = settingsData['plants'];
      final List<String> plants = rawPlants is List
          ? rawPlants.map((p) => p.toString().split(' ').first).toList()
          : ['Genel'];

      final int autoMode = (controlsData['auto_mode'] ?? 0) is bool
          ? ((controlsData['auto_mode'] == true) ? 1 : 0)
          : int.tryParse(controlsData['auto_mode'].toString()) ?? 0;

      // Build plant rules summary
      final StringBuffer plantRulesText = StringBuffer();
      for (final plant in plants) {
        final rule = _plantRules[plant] ?? _plantRules['Genel']!;
        plantRulesText.writeln(
          '- $plant: Temperature ${rule['temp'][0]}-${rule['temp'][1]}°C, '
          'Humidity ${rule['hum'][0]}-${rule['hum'][1]}%, '
          'Soil Moisture ${rule['soil'][0]}-${rule['soil'][1]}%, '
          'VPD ${rule['vpd'][0]}-${rule['vpd'][1]} kPa',
        );
      }

      // Read sensor values
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
      final String gece  = lux < 50 ? 'Night (lux < 50, plants at rest)' : 'Daytime';

      // ── Dynamic Context Prompt ───────────────────────────────────────────────
      final String contextPrompt = '''
[SYSTEM CONTEXT — do not display this block to the user]

=== GREENHOUSE STATUS ===
Cultivated Plants: ${plants.join(', ')}
Time Window: $gece

Sensors (Inner):
  • Temperature: ${tempInner}°C
  • Humidity: $humInner%
  • Soil Moisture: $soil%
  • Light: $lux lux
  • CO₂: $co2 ppm

Sensors (Outer):
  • Temperature: ${tempOuter}°C
  • Humidity: $humOuter%

Actuator States:
  • Fan: ${fanOn ? 'ON' : 'OFF'}
  • Pump: ${pumpOn ? 'ON' : 'OFF'}
  • Light/Misting: ${lightOn ? 'ON' : 'OFF'}

Operating Mode: ${autoMode == 1 ? 'AUTOMATIC (auto_mode=1)' : 'MANUAL (auto_mode=0)'}

=== PLANT IDEAL VALUES ===
$plantRulesText
=== ACTION RULES (VERY IMPORTANT) ===
• VPD > 1.5 kPa → Check soil moisture, trigger irrigation.
• During night hours (lux < 50), minimise irrigation as much as possible.
• CO₂ < 400 ppm → Issue warning: "Photosynthesis is slowing down".
• Temp_inner > plant's max temperature → Activate fan.

=== MODE BEHAVIOUR RULES ===
IF auto_mode == 1:
  - Take action YOURSELF and inform the user with "… done".
  - Append the invisible action code to the END of your message.
IF auto_mode == 0 (MANUAL):
  - NEVER take action on your own.
  - Ask for confirmation: "Would you like me to …?".
  - If the user says "Yes", append the action code to the end of your message.

=== ACTION CODE FORMAT ===
Append to the end of your message, without spaces, in uppercase:
[ACTION:FAN:ON], [ACTION:FAN:OFF]
[ACTION:PUMP:ON], [ACTION:PUMP:OFF]
[ACTION:LIGHT:ON], [ACTION:LIGHT:OFF]
Multiple codes may be included. Omit if not required.

===========================

User Question: $message
''';

      final response = await model.generateContent([Content.text(contextPrompt)]);
      return response.text ?? 'I\'m sorry, I am unable to generate a response at this moment.';
    } catch (e) {
      debugPrint('AI Error: $e');
      if (e.toString().contains('429')) {
        return 'Daily AI quota exhausted, data continues to be monitored normally.';
      }
      return 'I\'m sorry, the AI is currently unresponsive. Please check your connection.';
    }
  }
}