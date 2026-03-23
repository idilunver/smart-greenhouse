import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  // Sabit bitki listemiz
  final List<String> allPlants = [
    "Domates 🍅",
    "Biber 🌶️",
    "Marul 🥬",
    "Kaktüs 🌵",
    "Salatalık 🥒"
  ];

  @override
  Widget build(BuildContext context) {
    DatabaseReference controlRef = FirebaseDatabase.instance.ref("Greenhouse/Controls");
    DatabaseReference settingsRef = FirebaseDatabase.instance.ref("Greenhouse/Settings");

    return Scaffold(
      appBar: AppBar(title: const Text("Sistem Kontrolü")),
      body: SingleChildScrollView( // İçerik uzarsa kaydırılabilmesi için eklendi
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Başlıklar için sola yasla
          children: [
            // --- OTOMATİK MOD ---
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: StreamBuilder(
                stream: controlRef.child("auto_mode").onValue,
                builder: (context, snapshot) {
                  bool isAuto = (snapshot.data?.snapshot.value ?? 0).toString() == "1";
                  return SwitchListTile(
                      title: const Text("Otomatik Mod",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text("Sensörlere göre AI müdahale"),
                      value: isAuto,
                      onChanged: (val) =>
                          controlRef.update({"auto_mode": val ? 1 : 0}));
                },
              ),
            ),
            const SizedBox(height: 30),

            // --- MANUEL KONTROLLER ---
            _buildActionTile(controlRef, "pump", "Su Pompası", Icons.water_drop, Colors.blue),
            const SizedBox(height: 15),
            _buildActionTile(controlRef, "fan", "Tahliye Fanı", Icons.air, Colors.cyan),
            const SizedBox(height: 15),
            _buildActionTile(controlRef, "light", "Grow Light", Icons.lightbulb, Colors.amber),
            
            const SizedBox(height: 40),

            // --- BİTKİ SEÇİM ALANI (YENİ) ---
            const Text(
              "Yetiştirilen Bitkiler",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text(
              "Gemini tavsiyelerini bu seçime göre özelleştirir.",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 15),
            
            StreamBuilder(
              stream: settingsRef.child("plants").onValue,
              builder: (context, snapshot) {
                // Firebase'den seçili bitkileri çekiyoruz
                List<dynamic> selectedPlants = [];
                if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                  selectedPlants = List.from(snapshot.data!.snapshot.value as List);
                }

                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: allPlants.map((plant) {
                    final bool isSelected = selectedPlants.contains(plant);
                    return FilterChip(
                      label: Text(plant),
                      selected: isSelected,
                      selectedColor: Colors.green[100],
                      checkmarkColor: Colors.green,
                      onSelected: (bool selected) {
                        if (selected) {
                          selectedPlants.add(plant);
                        } else {
                          selectedPlants.remove(plant);
                        }
                        // Firebase'e listeyi güncelle
                        settingsRef.update({"plants": selectedPlants});
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(DatabaseReference ref, String key, String title, IconData icon, Color color) {
    return StreamBuilder(
      stream: ref.child(key).onValue,
      builder: (context, snapshot) {
        bool isOn = (snapshot.data?.snapshot.value ?? 0).toString() == "1";
        return Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isOn ? color : Colors.transparent, width: 2)),
          child: ListTile(
            leading: CircleAvatar(
                backgroundColor: isOn ? color : Colors.grey[200],
                child: Icon(icon, color: Colors.white)),
            title: Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: isOn ? Colors.red[400] : color,
                    foregroundColor: Colors.white),
                onPressed: () => ref.update({key: isOn ? 0 : 1}),
                child: Text(isOn ? "KAPAT" : "AÇ")),
          ),
        );
      },
    );
  }
}