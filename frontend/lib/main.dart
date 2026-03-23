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
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
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

    return Scaffold(
      appBar: AppBar(title: const Text("🌿 Akıllı Sera Kontrol"), centerTitle: true),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // SENSÖR VERİLERİ PANELİ
              StreamBuilder(
                stream: sensorsRef.onValue,
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                    Map<dynamic, dynamic> data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                    return Column(
                      children: [
                        _buildSensorCard("Sıcaklık", "${data['temp']}°C", Icons.thermostat, Colors.red),
                        _buildSensorCard("Nem", "%${data['humidity']}", Icons.water_drop, Colors.blue),
                        _buildSensorCard("Işık", "${data['lux']} Lux", Icons.wb_sunny, Colors.orange),
                        _buildSensorCard("Toprak Nemi", "%${data['soil_moisture']}", Icons.grass, Colors.brown),
                        _buildSensorCard("CO2", "${data['CO2']} ppm", Icons.cloud, Colors.grey),
                      ],
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                },
              ),
              const Divider(height: 40),
              // KONTROL PANELİ
              StreamBuilder(
                stream: pumpRef.onValue,
                builder: (context, snapshot) {
                  bool isPumpOn = (snapshot.data?.snapshot.value == 1);
                  return ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPumpOn ? Colors.red : Colors.green,
                      minimumSize: const Size(double.infinity, 60),
                    ),
                    onPressed: () => pumpRef.set(isPumpOn ? 0 : 1),
                    icon: Icon(isPumpOn ? Icons.stop : Icons.play_arrow, color: Colors.white),
                    label: Text(isPumpOn ? "SU POMPASINI DURDUR" : "SU POMPASINI ÇALIŞTIR", style: const TextStyle(color: Colors.white)),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSensorCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: color, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
    );
  }
}