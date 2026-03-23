import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    DatabaseReference sensorsRef = FirebaseDatabase.instance.ref("Greenhouse/Sensors");
    DatabaseReference aiRef = FirebaseDatabase.instance.ref("Greenhouse/AI_Analysis");
    DatabaseReference controlRef = FirebaseDatabase.instance.ref("Greenhouse/Controls");

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        title: const Text("🌿 Akıllı Sera Paneli", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder(
        stream: sensorsRef.onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return const Center(child: CircularProgressIndicator());
          }
          Map data = snapshot.data!.snapshot.value as Map;

          bool tempAlert = (double.tryParse(data['temp_inner']?.toString() ?? '0') ?? 0) > 32;
          bool soilAlert = (double.tryParse(data['soil_moisture']?.toString() ?? '0') ?? 0) < 20;
          bool humidityAlert = (double.tryParse(data['humidity_inner']?.toString() ?? '0') ?? 0) < 40;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── ÜST BÖLÜM: AI Tavsiyesi + Son Olaylar yan yana ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ARTIK BURASI CANLI DİNLENİYOR
                    Expanded(flex: 3, child: _buildAISection(aiRef)),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: _buildEventLog(controlRef)),
                  ],
                ),

                const SizedBox(height: 25),
                const Text("Kritik Göstergeler", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                // ── ORTA BÖLÜM: Kritik Göstergeler (büyük kartlar) ──
                Row(
                  children: [
                    Expanded(child: _buildCriticalCard("İç Sıcaklık", "${data['temp_inner'] ?? '0'}", "°C", Icons.thermostat, Colors.orange, tempAlert)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildCriticalCard("İç Nem", "${data['humidity_inner'] ?? '0'}", "%", Icons.water_drop, Colors.blue, humidityAlert)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildCriticalCard("Toprak Nemi", "${data['soil_moisture'] ?? '0'}", "%", Icons.grass, Colors.brown, soilAlert)),
                  ],
                ),

                const SizedBox(height: 25),
                const Text("Tüm Sensör Verileri", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                // ── ALT BÖLÜM: Tüm sensörler liste halinde ──
                _buildSensorRow("Dış Sıcaklık", "${data['temp_outer'] ?? '0'} °C", Icons.wb_cloudy, Colors.blueGrey, "Referans"),
                _buildSensorRow("Dış Nem", "${data['humidity_outer'] ?? '0'} %", Icons.air, Colors.cyan, "Normal"),
                _buildSensorRow("Işık Gücü", "${data['light_lux'] ?? '0'} Lx", Icons.wb_sunny, Colors.amber, "Yeterli"),
                _buildSensorRow("CO2 Seviyesi", "${data['CO2'] ?? '0'} ppm", Icons.cloud, Colors.blueGrey, "Güvenli"),
                _buildSensorRow("Sistem Gücü", "12.4 V", Icons.bolt, Colors.green, "Aktif"),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── AI TAVSİYESİ KARTI (CANLI GÜNCELLENEN VERSİYON) ──
  Widget _buildAISection(DatabaseReference aiRef) {
    return StreamBuilder(
      stream: aiRef.onValue,
      builder: (context, snapshot) {
        // Firebase'den veri gelene kadar bekleme değerleri
        String advice = "Analiz ediliyor...";
        String etDisplay = "0.00";

        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          Map aiData = snapshot.data!.snapshot.value as Map;
          advice = aiData['advice']?.toString() ?? advice;
          
          // et_rate değerini alıp 2 basamaklı formata sokuyoruz
          var rawEt = aiData['et_rate'] ?? 0;
          etDisplay = double.parse(rawEt.toString()).toStringAsFixed(2);
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.green[800]!, Colors.green[400]!]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.psychology, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  const Text("AI Tavsiyesi", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                    child: Text("ET: $etDisplay", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                advice, 
                style: const TextStyle(color: Colors.white, fontSize: 13, fontStyle: FontStyle.italic, height: 1.4),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── SON OLAYLAR KARTI (SABİT KALDI) ──
  Widget _buildEventLog(DatabaseReference controlRef) {
    return StreamBuilder(
      stream: controlRef.onValue,
      builder: (context, snapshot) {
        Map controls = (snapshot.data?.snapshot.value as Map?) ?? {};
        bool pumpOn = controls['pump']?.toString() == "1";
        bool fanOn = controls['fan']?.toString() == "1";
        bool lightOn = controls['light']?.toString() == "1";
        bool autoMode = controls['auto_mode']?.toString() == "1";

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.notifications_active, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  const Text("Son Olaylar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 12),
              _buildEventItem(
                pumpOn ? "Pompa Çalışıyor" : "Pompa Kapalı",
                pumpOn ? "Aktif sulama" : "Beklemede",
                Icons.water_drop,
                pumpOn ? Colors.blue : Colors.grey,
              ),
              _buildEventItem(
                fanOn ? "Fan Çalışıyor" : "Fan Kapalı",
                fanOn ? "Havalandırma aktif" : "Beklemede",
                Icons.air,
                fanOn ? Colors.cyan : Colors.grey,
              ),
              _buildEventItem(
                lightOn ? "Işık Açık" : "Işık Kapalı",
                lightOn ? "Işık aktif" : "Beklemede",
                Icons.lightbulb,
                lightOn ? Colors.amber : Colors.grey,
              ),
              const Divider(height: 16),
              Row(
                children: [
                  Icon(autoMode ? Icons.smart_toy : Icons.pan_tool, size: 14, color: autoMode ? Colors.green : Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    autoMode ? "Otonom" : "Manuel",
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: autoMode ? Colors.green[700] : Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventItem(String title, String subtitle, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(radius: 14, backgroundColor: color.withOpacity(0.1), child: Icon(icon, size: 14, color: color)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                Text(subtitle, style: TextStyle(fontSize: 9, color: Colors.grey[500])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriticalCard(String title, String value, String unit, IconData icon, Color color, bool isAlert) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isAlert ? Colors.red[50] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isAlert ? Colors.red : Colors.transparent, width: isAlert ? 2 : 0),
        boxShadow: [BoxShadow(color: (isAlert ? Colors.red : Colors.black).withOpacity(0.06), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Icon(icon, color: isAlert ? Colors.red : color, size: 28),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 10, color: isAlert ? Colors.red : Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isAlert ? Colors.red : Colors.black87)),
              Text(unit, style: TextStyle(fontSize: 11, color: isAlert ? Colors.red[300] : Colors.grey)),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (isAlert ? Colors.red : Colors.green).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isAlert ? "⚠️ DİKKAT" : "✅ Normal",
              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: isAlert ? Colors.red : Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorRow(String title, String value, IconData icon, Color color, String status) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 18, backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 15),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text("● $status", style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}