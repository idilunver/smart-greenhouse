import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';

class ChartDataPoint {
  ChartDataPoint(this.x, this.y);
  final DateTime x;
  final double y;
}

class ChartsPage extends StatelessWidget {
  const ChartsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final databaseRef = FirebaseDatabase.instance.ref('Greenhouse/History');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Detaylı Grafik Analizi", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: Colors.green),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Haftalık Rapor (CSV) oluşturuluyor...")),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder(
        stream: databaseRef.limitToLast(50).onValue, // Son 50 kaydı al
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("Henüz geçmiş veri toplanmadı...", style: TextStyle(color: Colors.grey)),
                  Text("Bunu başlatmak için backend'in çalıştığından emin olun.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            );
          }

          // Veriyi işle ve zamana göre sırala
          Map dataMap = snapshot.data!.snapshot.value as Map;
          List<MapEntry> entries = dataMap.entries.toList();
          entries.sort((a, b) => (a.value['timestamp'] as int).compareTo(b.value['timestamp'] as int));

          List<ChartDataPoint> tempHistory = [];
          List<ChartDataPoint> humidityHistory = [];
          List<ChartDataPoint> soilHistory = [];
          List<ChartDataPoint> luxHistory = [];
          List<ChartDataPoint> co2History = [];
          List<ChartDataPoint> voltageHistory = [];

          for (var entry in entries) {
            var val = entry.value;
            DateTime time = DateTime.fromMillisecondsSinceEpoch((val['timestamp'] as int) * 1000);
            
            tempHistory.add(ChartDataPoint(time, (val['temp'] ?? 0).toDouble()));
            humidityHistory.add(ChartDataPoint(time, (val['hum'] ?? 0).toDouble()));
            soilHistory.add(ChartDataPoint(time, (val['soil'] ?? 0).toDouble()));
            luxHistory.add(ChartDataPoint(time, (val['lux'] ?? 0).toDouble()));
            co2History.add(ChartDataPoint(time, (val['co2'] ?? 0).toDouble()));
            voltageHistory.add(ChartDataPoint(time, (val['voltage'] ?? 0).toDouble()));
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _buildSfChart("İç Sıcaklık Değişimi (°C)", tempHistory, Colors.orange, "°C", 10, 45, true),
              const SizedBox(height: 15),
              _buildSfChart("İç Nem Değişimi (%)", humidityHistory, Colors.blue, "%", 0, 100, false),
              const SizedBox(height: 15),
              _buildSfChart("Toprak Nemi (%)", soilHistory, Colors.brown, "%", 0, 100, false),
              const SizedBox(height: 15),
              _buildSfChart("Işık Şiddeti (Lux)", luxHistory, Colors.amber, " Lx", 0, 1000, false),
              const SizedBox(height: 15),
              _buildSfChart("CO2 Konsantrasyonu (ppm)", co2History, Colors.blueGrey, " ppm", 300, 1200, false),
              const SizedBox(height: 15),
              _buildSfChart("Sistem Voltajı (V)", voltageHistory, Colors.green, "V", 10, 15, false),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSfChart(String title, List<ChartDataPoint> data, Color color, String unit, double min, double max, bool showIdealRange) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Icon(Icons.trending_up, color: color.withOpacity(0.5), size: 18),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 220,
              child: SfCartesianChart(
                zoomPanBehavior: ZoomPanBehavior(enablePinching: true, enablePanning: true, zoomMode: ZoomMode.x),
                tooltipBehavior: TooltipBehavior(enable: true, header: title, canShowMarker: true),
                primaryXAxis: DateTimeAxis(
                  majorGridLines: const MajorGridLines(width: 0),
                  dateFormat: DateFormat('HH:mm'),
                  intervalType: DateTimeIntervalType.auto,
                  title: const AxisTitle(text: 'Zaman', textStyle: TextStyle(fontSize: 10)),
                ),
                primaryYAxis: NumericAxis(
                  minimum: min, maximum: max,
                  labelFormat: '{value}$unit',
                  plotBands: showIdealRange ? [
                    PlotBand(isVisible: true, start: 18, end: 28, color: Colors.green.withOpacity(0.1), text: 'İDEAL', textStyle: const TextStyle(color: Colors.green, fontSize: 8, fontWeight: FontWeight.bold))
                  ] : [],
                ),
                series: <CartesianSeries>[
                  SplineAreaSeries<ChartDataPoint, DateTime>(
                    dataSource: data,
                    xValueMapper: (ChartDataPoint d, _) => d.x,
                    yValueMapper: (ChartDataPoint d, _) => d.y,
                    color: color.withOpacity(0.3),
                    borderColor: color,
                    borderWidth: 3,
                    markerSettings: const MarkerSettings(isVisible: true, size: 4),
                    enableTooltip: true,
                    animationDuration: 1500,
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
