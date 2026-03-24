import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with TickerProviderStateMixin {
  late AnimationController _fanController;
  late AnimationController _pumpController;

  @override
  void initState() {
    super.initState();
    _fanController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _pumpController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  }

  @override
  void dispose() {
    _fanController.dispose();
    _pumpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    DatabaseReference sensorsRef = FirebaseDatabase.instance.ref("Greenhouse/Sensors");
    DatabaseReference aiRef = FirebaseDatabase.instance.ref("Greenhouse/AI_Analysis");
    DatabaseReference controlRef = FirebaseDatabase.instance.ref("Greenhouse/Controls");

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("🌿 Smart Greenhouse Controller", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isWide = constraints.maxWidth > 900;
          double contentWidth = isWide ? 1100 : constraints.maxWidth;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentWidth),
              child: StreamBuilder(
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
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Üst Panel: AI ve Loglar
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: _buildAISection(aiRef)),
                              const SizedBox(width: 24),
                              Expanded(flex: 1, child: _buildEventLog(controlRef)),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _buildAISection(aiRef),
                              const SizedBox(height: 16),
                              _buildEventLog(controlRef),
                            ],
                          ),
                        
                        const SizedBox(height: 40),
                        const Text("Kritik Sistem Parametreleri", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                        const SizedBox(height: 16),
                        
                        // Kritik Kartlar: Mobilde Alt Alta/Kaydırılabilir, Web'de Yan Yana
                        isWide 
                          ? Row(
                              children: [
                                Expanded(child: _buildCriticalCard("Sıcaklık", "${data['temp_inner'] ?? '0'}", "°C", Icons.thermostat_rounded, Colors.orange, tempAlert)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildCriticalCard("Hava Nemi", "${data['humidity_inner'] ?? '0'}", "%", Icons.water_drop_rounded, Colors.blue, humidityAlert)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildCriticalCard("Toprak Nemi", "${data['soil_moisture'] ?? '0'}", "%", Icons.grass_rounded, Colors.brown, soilAlert)),
                              ],
                            )
                          : GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: constraints.maxWidth > 500 ? 3 : 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.85,
                              children: [
                                _buildCriticalCard("Sıcaklık", "${data['temp_inner'] ?? '0'}", "°C", Icons.thermostat_rounded, Colors.orange, tempAlert),
                                _buildCriticalCard("Hava Nemi", "${data['humidity_inner'] ?? '0'}", "%", Icons.water_drop_rounded, Colors.blue, humidityAlert),
                                _buildCriticalCard("Toprak Nemi", "${data['soil_moisture'] ?? '0'}", "%", Icons.grass_rounded, Colors.brown, soilAlert),
                              ],
                            ),

                        const SizedBox(height: 40),
                        const Text("Yardımcı Sensörler", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                        const SizedBox(height: 16),
                        
                        // Diğer Sensörler: Yan yana grid (Web'de daha fazla sütun)
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: isWide ? 3 : 1,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 16,
                          childAspectRatio: isWide ? 3.5 : 4.5,
                          children: [
                            _buildSensorRow("Dış Sıcaklık", "${data['temp_outer'] ?? '0'} °C", Icons.wb_cloudy_rounded, Colors.blueGrey, "Atmosfer"),
                            _buildSensorRow("Dış Nem", "${data['humidity_outer'] ?? '0'} %", Icons.air_rounded, Colors.cyan, "Normal"),
                            _buildSensorRow("Işık Şiddeti", "${data['light_lux'] ?? '0'} Lx", Icons.wb_sunny_rounded, Colors.amber, "Güneş"),
                            _buildSensorRow("CO2 Seviyesi", "${data['CO2'] ?? '0'} ppm", Icons.cloud_circle_rounded, Colors.blueGrey, "Besin"),
                            _buildSensorRow("Voltaj", "12.4 V", Icons.bolt_rounded, Colors.green, "Stabil"),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
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

  // ── SON OLAYLAR KARTI (CANLI LOG VERSİYONU) ──
  Widget _buildEventLog(DatabaseReference controlRef) {
    DatabaseReference logsRef = FirebaseDatabase.instance.ref("Greenhouse/Logs");

    return StreamBuilder(
      stream: logsRef.limitToLast(5).onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return _buildStaticEventContainer(const [
            Text("Henüz olay gerçekleşmedi.", style: TextStyle(fontSize: 10, color: Colors.grey)),
          ]);
        }

        Map dataMap = snapshot.data!.snapshot.value as Map;
        List<MapEntry> entries = dataMap.entries.toList();
        entries.sort((a, b) => (b.value['timestamp'] as int).compareTo(a.value['timestamp'] as int));

        // Animasyon durumlarını kontrol et
        bool isPumpRunning = entries.any((e) => e.value['type'] == 'pump' && e.value['msg'].contains('AÇILDI'));
        bool isFanRunning = entries.any((e) => e.value['type'] == 'fan' && e.value['msg'].contains('AÇILDI'));
        
        if (isFanRunning) { _fanController.repeat(); } else { _fanController.stop(); }
        if (isPumpRunning) { _pumpController.repeat(reverse: true); } else { _pumpController.stop(); }

        return _buildStaticEventContainer(
          entries.map((e) {
            var val = e.value;
            String type = val['type']?.toString() ?? 'info';
            IconData icon = Icons.info_outline;
            Color color = Colors.blue;
            Widget? animatedIcon;

            if (type == 'pump') { 
              icon = Icons.water_drop; 
              color = Colors.blue;
              animatedIcon = ScaleTransition(scale: Tween(begin: 0.8, end: 1.2).animate(_pumpController), child: Icon(icon, size: 14, color: color));
            }
            if (type == 'fan') { 
              icon = Icons.air; 
              color = Colors.cyan;
              animatedIcon = RotationTransition(turns: _fanController, child: Icon(icon, size: 14, color: color));
            }
            if (type == 'light') { icon = Icons.lightbulb; color = Colors.amber; }

            return _buildEventItem(
              val['msg']?.toString() ?? "Olay",
              _formatTimestamp(val['timestamp'] as int),
              icon,
              color,
              customIcon: animatedIcon,
            );
          }).toList(),
        );
      },
    );
  }

  String _formatTimestamp(int timestamp) {
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  Widget _buildStaticEventContainer(List<Widget> children) {
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
          ...children,
        ],
      ),
    );
  }

  Widget _buildEventItem(String title, String subtitle, IconData icon, Color color, {Widget? customIcon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14, 
            backgroundColor: color.withOpacity(0.1), 
            child: customIcon ?? Icon(icon, size: 14, color: color)
          ),
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