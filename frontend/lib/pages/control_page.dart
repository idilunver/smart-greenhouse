import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  // Fixed plant list
  final List<String> allPlants = [
    "Tomato 🍅",
    "Pepper 🌶️",
    "Lettuce 🥬",
    "Cactus 🌵",
    "Cucumber 🥒"
  ];

  @override
  Widget build(BuildContext context) {
    DatabaseReference controlRef = FirebaseDatabase.instance.ref("Greenhouse/Controls");
    DatabaseReference settingsRef = FirebaseDatabase.instance.ref("Greenhouse/Settings");

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("System Control", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isWide = constraints.maxWidth > 800;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWide ? 1000 : constraints.maxWidth),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- AUTOMATIC MODE ---
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[700],
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: StreamBuilder(
                        stream: controlRef.child("auto_mode").onValue,
                        builder: (context, snapshot) {
                          final autoVal = snapshot.data?.snapshot.value;
                          bool isAuto = autoVal == true || autoVal == 1;
                          return SwitchListTile(
                            title: const Text("Automatic Mode (AI)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            subtitle: const Text("AI provides protection in extreme conditions", style: TextStyle(color: Colors.white70, fontSize: 12)),
                            value: isAuto,
                            activeColor: Colors.white,
                            onChanged: (val) => controlRef.update({"auto_mode": val ? 1 : 0}),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 40),

                    // --- MANUAL CONTROLS ---
                    const Text("Manual Intervention Units", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                    const SizedBox(height: 16),

                    isWide
                      ? Row(
                          children: [
                            Expanded(child: _buildActionTile(controlRef, "pump", "Water Pump", Icons.water_drop_rounded, Colors.blue)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildActionTile(controlRef, "fan", "Exhaust Fan", Icons.air_rounded, Colors.cyan)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildActionTile(controlRef, "light", "Grow Light", Icons.lightbulb_rounded, Colors.amber)),
                          ],
                        )
                      : Column(
                          children: [
                            _buildActionTile(controlRef, "pump", "Water Pump", Icons.water_drop_rounded, Colors.blue),
                            const SizedBox(height: 12),
                            _buildActionTile(controlRef, "fan", "Exhaust Fan", Icons.air_rounded, Colors.cyan),
                            const SizedBox(height: 12),
                            _buildActionTile(controlRef, "light", "Grow Light", Icons.lightbulb_rounded, Colors.amber),
                          ],
                        ),

                    const SizedBox(height: 40),

                    // --- PLANT SELECTION AREA ---
                    const Text("Target Plant Profiling", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                    const Text("AI analyses are calibrated according to this data.", style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 20),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
                      ),
                      child: StreamBuilder(
                        stream: settingsRef.child("plants").onValue,
                        builder: (context, snapshot) {
                          List<dynamic> selectedPlants = [];
                          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                            selectedPlants = List.from(snapshot.data!.snapshot.value as List);
                          }

                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: allPlants.map((plant) {
                              final bool isSelected = selectedPlants.contains(plant);
                              return FilterChip(
                                label: Text(plant, style: TextStyle(color: isSelected ? Colors.green[900] : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                selected: isSelected,
                                selectedColor: Colors.green[100],
                                checkmarkColor: Colors.green[800],
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: isSelected ? Colors.green : Colors.grey[300]!),
                                ),
                                onSelected: (bool selected) {
                                  if (selected) {
                                    selectedPlants.add(plant);
                                  } else {
                                    selectedPlants.remove(plant);
                                  }
                                  settingsRef.update({"plants": selectedPlants});
                                },
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionTile(DatabaseReference ref, String key, String title, IconData icon, Color color) {
    return StreamBuilder(
      stream: ref.child(key).onValue,
      builder: (context, snapshot) {
        final rawVal = snapshot.data?.snapshot.value;
        bool isOn = rawVal == true || rawVal == 1;
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
                child: Text(isOn ? "OFF" : "ON")),
          ),
        );
      },
    );
  }
}