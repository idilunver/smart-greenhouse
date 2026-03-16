import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

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
        primarySwatch: Colors.green,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: const GreenhouseDashboard(),
    );
  }
}

class GreenhouseDashboard extends StatelessWidget {
  const GreenhouseDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    DatabaseReference sensorsRef = FirebaseDatabase.instance.ref("Greenhouse/Sensors");
    DatabaseReference pumpRef = FirebaseDatabase.instance.ref("Greenhouse/Controls/pump");
    DatabaseReference fanRef = FirebaseDatabase.instance.ref("Greenhouse/Controls/fan"); // Fan referansı eklendi
    DatabaseReference adviceRef = FirebaseDatabase.instance.ref("Greenhouse/AI_Analysis/advice");

    return Scaffold(
      appBar: AppBar(
        title: const Text("🌿 Sera Kontrol Sistemi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- ANALİZ BÖLÜMÜ ---
              StreamBuilder(
                stream: adviceRef.onValue,
                builder: (context, snapshot) {
                  String advice = snapshot.data?.snapshot.value?.toString() ?? "Veri bekleniyor...";
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[300]!)),
                    child: ListTile(
                      leading: const Icon(Icons.tips_and_updates, color: Colors.orange),
                      title: Text(advice, style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // --- SENSÖR GRİD ---
              const Text("📊 Canlı Veriler", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              StreamBuilder(
                stream: sensorsRef.onValue,
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                    Map<dynamic, dynamic> data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.9,
                      children: [
                        _buildSmallCard("Sıcaklık", data['temp'], "°C", Icons.thermostat, Colors.orange),
                        _buildSmallCard("Toprak", data['soil_moisture'], "%", Icons.opacity, Colors.brown),
                        _buildSmallCard("Işık", data['light_lux'], " Lx", Icons.wb_sunny, Colors.amber),
                        _buildSmallCard("Nem", data['humidity'], "%", Icons.water, Colors.blue),
                        _buildSmallCard("CO2", data['CO2'], " p", Icons.co2, Colors.blueGrey),
                        _buildSmallCard("Sistem", "Aktif", "", Icons.check_circle, Colors.green),
                      ],
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                },
              ),
              const SizedBox(height: 30),

              // --- KONTROL PANELİ (POMPA & FAN) ---
              const Text("⚙️ Cihaz Kontrolü", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              Row(
                children: [
                  // SU POMPASI BUTONU
                  Expanded(
                    child: StreamBuilder(
                      stream: pumpRef.onValue,
                      builder: (context, snapshot) {
                        bool isOn = (snapshot.data?.snapshot.value == 1);
                        return _buildControlButton(
                          title: isOn ? "Pompa: AÇIK" : "Pompa: KAPALI",
                          isOn: isOn,
                          icon: Icons.water_drop,
                          color: Colors.blue,
                          onPressed: () => pumpRef.set(isOn ? 0 : 1),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  // FAN BUTONU
                  Expanded(
                    child: StreamBuilder(
                      stream: fanRef.onValue,
                      builder: (context, snapshot) {
                        bool isOn = (snapshot.data?.snapshot.value == 1);
                        return _buildControlButton(
                          title: isOn ? "Fan: AÇIK" : "Fan: KAPALI",
                          isOn: isOn,
                          icon: Icons.air,
                          color: Colors.cyan,
                          onPressed: () => fanRef.set(isOn ? 0 : 1),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Sensör Kartı Tasarımı
  Widget _buildSmallCard(String title, dynamic value, String unit, IconData icon, Color color) {
    String displayValue = (value != null) ? "$value$unit" : "---";
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(displayValue, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // Kontrol Butonu Tasarımı (Yeni)
  Widget _buildControlButton({required String title, required bool isOn, required IconData icon, required Color color, required VoidCallback onPressed}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isOn ? color : Colors.white,
        foregroundColor: isOn ? Colors.white : Colors.black87,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isOn ? Colors.transparent : Colors.grey[300]!),
        ),
      ),
      onPressed: onPressed,
      child: Column(
        children: [
          Icon(icon, size: 28),
          const SizedBox(height: 5),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}