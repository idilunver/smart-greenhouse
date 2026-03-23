import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

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
                  bool isAuto = (snapshot.data?.snapshot.value ?? 0).toString() == "1";
                  return SwitchListTile(title: const Text("Otomatik Mod", style: TextStyle(fontWeight: FontWeight.bold)), subtitle: const Text("Sensörlere göre AI müdahale"), value: isAuto, onChanged: (val) => controlRef.update({"auto_mode": val ? 1 : 0}));
                },
              ),
            ),
            const SizedBox(height: 30),
            _buildActionTile(controlRef, "pump", "Su Pompası", Icons.water_drop, Colors.blue),
            const SizedBox(height: 15),
            _buildActionTile(controlRef, "fan", "Tahliye Fanı", Icons.air, Colors.cyan),
            const SizedBox(height: 15),
            _buildActionTile(controlRef, "light", "Grow Light", Icons.lightbulb, Colors.amber),
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
