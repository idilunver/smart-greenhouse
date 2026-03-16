import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart'; // Mevcut kullanım için kalsın
import 'package:syncfusion_flutter_charts/charts.dart'; // Yeni eklenen profesyonel grafikler

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyB5VTUokAVSnmQUocsT1Ub7pOoxtCXKr4w",
      appId: "1:588272095295:web:e73914e1640b98d6db688a",
      messagingSenderId: "588272095295",
      projectId: "smart-greenhouse-9fb8e",
      databaseURL: "https://smart-greenhouse-9fb8e-default-rtdb.europe-west1.firebasedatabase.app",
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        cardTheme: CardTheme(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      ),
      home: const MainNavigation(),
    );
  }
}

// --- ANA NAVİGASYON ---
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  
  final List<Widget> _pages = [
    const DashboardPage(), 
    const AIChatAnalysisPage(), 
    const ChartsPage(), 
    const ControlPage()
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Genel Bakış'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'AI Analiz'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'Grafik'),
          NavigationDestination(icon: Icon(Icons.settings_suggest_outlined), selectedIcon: Icon(Icons.settings_suggest), label: 'Kontrol'),
        ],
      ),
    );
  }
}

// --- 1. SAYFA: DASHBOARD ---
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    DatabaseReference sensorsRef = FirebaseDatabase.instance.ref("Greenhouse/Sensors");
    DatabaseReference adviceRef = FirebaseDatabase.instance.ref("Greenhouse/AI_Analysis/advice");

    return Scaffold(
      appBar: AppBar(title: const Text("🌿 Akıllı Sera Paneli", style: TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder(
              stream: adviceRef.onValue,
              builder: (context, snapshot) {
                String advice = snapshot.data?.snapshot.value?.toString() ?? "Veri bekleniyor...";
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.green[800]!, Colors.green[400]!]),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [Icon(Icons.psychology, color: Colors.white), SizedBox(width: 8), Text("Anlık AI Tavsiyesi", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
                      const SizedBox(height: 10),
                      Text(advice, style: const TextStyle(color: Colors.white, fontSize: 13, fontStyle: FontStyle.italic)),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 25),
            const Text("Canlı Sensör Verileri", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            StreamBuilder(
              stream: sensorsRef.onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data?.snapshot.value == null) return const Center(child: CircularProgressIndicator());
                Map data = snapshot.data!.snapshot.value as Map;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.1,
                  children: [
                    _buildProCard("Sıcaklık", "${data['temp']}", "°C", Icons.thermostat, Colors.orange, "Stabil"),
                    _buildProCard("Hava Nemi", "${data['humidity']}", "%", Icons.water_drop, Colors.blue, "Normal"),
                    _buildProCard("Toprak Nemi", "${data['soil_moisture']}", "%", Icons.grass, Colors.brown, "İdeal"),
                    _buildProCard("Işık Gücü", "${data['light_lux']}", " Lx", Icons.wb_sunny, Colors.amber, "Yeterli"),
                    _buildProCard("CO2 Seviyesi", "${data['CO2']}", " ppm", Icons.cloud, Colors.blueGrey, "Güvenli"),
                    _buildProCard("Sistem Gücü", "12.4", "V", Icons.bolt, Colors.green, "Aktif"),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProCard(String title, String value, String unit, IconData icon, Color color, String status) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(backgroundColor: color.withOpacity(0.1), radius: 18, child: Icon(icon, color: color, size: 20)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(unit, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
          Text("● $status", style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// --- 2. SAYFA: AI ANALİZ & CHAT (Dikey Bölünmüş) ---
class AIChatAnalysisPage extends StatefulWidget {
  const AIChatAnalysisPage({super.key});
  @override
  State<AIChatAnalysisPage> createState() => _AIChatAnalysisPageState();
}

class _AIChatAnalysisPageState extends State<AIChatAnalysisPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [
    {'role': 'ai', 'text': 'Merhaba! Ben Sera Asistanınız. Bitkileriniz hakkında ne bilmek istersiniz?'}
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🤖 AI Danışmanlık", style: TextStyle(fontWeight: FontWeight.bold))),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(color: Colors.white, border: Border(right: BorderSide(color: Colors.grey[200]!))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(padding: EdgeInsets.all(16.0), child: Text("SİSTEM GÜNLÜĞÜ", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green, letterSpacing: 1.2))),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        _buildLogTile("Sulama Tamamlandı", "15:30", Icons.check_circle, Colors.green),
                        _buildLogTile("Yüksek CO2 Tespit Edildi", "14:45", Icons.warning_amber_rounded, Colors.orange),
                        _buildLogTile("Fan Otomatik Başlatıldı", "14:46", Icons.air, Colors.blue),
                        _buildLogTile("Sistem Kontrolü OK", "12:00", Icons.shield, Colors.grey),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      bool isUser = _messages[index]['role'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isUser ? Colors.green[600] : Colors.grey[200],
                            borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: Radius.circular(isUser ? 16 : 0), bottomRight: Radius.circular(isUser ? 0 : 16)),
                          ),
                          child: Text(_messages[index]['text']!, style: TextStyle(color: isUser ? Colors.white : Colors.black87, fontSize: 13)),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(child: TextField(controller: _controller, decoration: InputDecoration(hintText: "Soru sor...", filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 20)))),
                      const SizedBox(width: 8),
                      CircleAvatar(backgroundColor: Colors.green, child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 18), onPressed: () { if (_controller.text.isNotEmpty) { setState(() { _messages.add({'role': 'user', 'text': _controller.text}); _controller.clear(); }); } })),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogTile(String title, String time, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), Text(time, style: TextStyle(fontSize: 10, color: Colors.grey[600])), const SizedBox(height: 5), Divider(height: 1, color: Colors.grey[100])]))]),
    );
  }
}

// --- 3. SAYFA: PROFESYONEL GRAFİKLER (Syncfusion) ---
class ChartsPage extends StatelessWidget {
  const ChartsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Örnek veri setleri (Firebase listeleriyle bağlandığında otomatik güncellenir)
    final List<ChartDataPoint> tempHistory = [
      ChartDataPoint(0, 22), ChartDataPoint(1, 24), ChartDataPoint(2, 28), ChartDataPoint(3, 26), ChartDataPoint(4, 30), ChartDataPoint(5, 27),
    ];
    final List<ChartDataPoint> humidityHistory = [
      ChartDataPoint(0, 45), ChartDataPoint(1, 50), ChartDataPoint(2, 48), ChartDataPoint(3, 55), ChartDataPoint(4, 52), ChartDataPoint(5, 49),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Detaylı Grafik Analizi", style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildSfChart("Sıcaklık Değişimi (°C)", tempHistory, Colors.orange, "°C", 15, 40, true),
          const SizedBox(height: 15),
          _buildSfChart("Hava Nemi (%)", humidityHistory, Colors.blue, "%", 0, 100, false),
          const SizedBox(height: 15),
          _buildSfChart("Toprak Nemi (%)", [ChartDataPoint(0, 30), ChartDataPoint(5, 45)], Colors.brown, "%", 0, 100, false),
        ],
      ),
    );
  }

  Widget _buildSfChart(String title, List<ChartDataPoint> data, Color color, String unit, double min, double max, bool showIdealRange) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            SizedBox(
              height: 220,
              child: SfCartesianChart(
                zoomPanBehavior: ZoomPanBehavior(enablePinching: true, enablePanning: true, zoomMode: ZoomMode.x),
                tooltipBehavior: TooltipBehavior(enable: true, header: title, canShowMarker: true),
                primaryXAxis: const NumericAxis(majorGridLines: MajorGridLines(width: 0), title: AxisTitle(text: 'Zaman (saat)', textStyle: TextStyle(fontSize: 10))),
                primaryYAxis: NumericAxis(
                  minimum: min, maximum: max,
                  labelFormat: '{value}$unit',
                  plotBands: showIdealRange ? [
                    PlotBand(isVisible: true, start: 22, end: 28, color: Colors.green.withOpacity(0.1), text: 'İDEAL ARALIK', textStyle: const TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold))
                  ] : [],
                ),
                series: <CartesianSeries>[
                  SplineSeries<ChartDataPoint, int>(
                    dataSource: data,
                    xValueMapper: (ChartDataPoint d, _) => d.x,
                    yValueMapper: (ChartDataPoint d, _) => d.y,
                    color: color,
                    width: 3,
                    markerSettings: const MarkerSettings(isVisible: true),
                    enableTooltip: true,
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChartDataPoint {
  ChartDataPoint(this.x, this.y);
  final int x;
  final double y;
}

// --- 4. SAYFA: KONTROL ---
class ControlPage extends StatelessWidget {
  const ControlPage({super.key});

  @override
  Widget build(BuildContext context) {
    DatabaseReference controlRef = FirebaseDatabase.instance.ref("Greenhouse/Controls");
    return Scaffold(
      appBar: AppBar(title: const Text("Sistem Kontrolü")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: StreamBuilder(
                stream: controlRef.child("auto_mode").onValue,
                builder: (context, snapshot) {
                  bool isAuto = snapshot.data?.snapshot.value == 1;
                  return SwitchListTile(title: const Text("Otomatik Mod", style: TextStyle(fontWeight: FontWeight.bold)), subtitle: const Text("Sensörlere göre AI müdahale"), value: isAuto, onChanged: (val) => controlRef.update({"auto_mode": val ? 1 : 0}));
                },
              ),
            ),
            const SizedBox(height: 30),
            _buildActionTile(controlRef, "pump", "Su Pompası", Icons.water_drop, Colors.blue),
            const SizedBox(height: 15),
            _buildActionTile(controlRef, "fan", "Tahliye Fanı", Icons.air, Colors.cyan),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(DatabaseReference ref, String key, String title, IconData icon, Color color) {
    return StreamBuilder(
      stream: ref.child(key).onValue,
      builder: (context, snapshot) {
        bool isOn = snapshot.data?.snapshot.value == 1;
        return Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isOn ? color : Colors.transparent, width: 2)),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: isOn ? color : Colors.grey[200], child: Icon(icon, color: Colors.white)),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: isOn ? Colors.red[400] : color, foregroundColor: Colors.white), onPressed: () => ref.update({key: isOn ? 0 : 1}), child: Text(isOn ? "KAPAT" : "AÇ")),
          ),
        );
      },
    );
  }
}