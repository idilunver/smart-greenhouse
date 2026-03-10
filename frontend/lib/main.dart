import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Senin Firebase Bilgilerin
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
      home: Scaffold(
        appBar: AppBar(title: const Text('Akıllı Sera Kontrol')),
        body: const Center(child: GreenhouseStatus()),
      ),
    );
  }
}

class GreenhouseStatus extends StatelessWidget {
  const GreenhouseStatus({super.key});

  @override
  Widget build(BuildContext context) {
    // 2. Firebase'den Sıcaklık Verisini Dinleyen Stream
    DatabaseReference tempRef = FirebaseDatabase.instance.ref("Greenhouse/Sensors/temp");

    return StreamBuilder(
      stream: tempRef.onValue,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          var temp = snapshot.data!.snapshot.value.toString();
          return Text("Anlık Sıcaklık: $temp °C", style: const TextStyle(fontSize: 24));
        }
        return const CircularProgressIndicator();
      },
    );
  }
}