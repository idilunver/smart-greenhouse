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
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("Haftalık Analiz & Trendler", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isWide = constraints.maxWidth > 900;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWide ? 1200 : constraints.maxWidth),
              child: StreamBuilder(
                stream: databaseRef.limitToLast(50).onValue,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text("Yeterli veri bulunamadı.", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }

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

                  return GridView.count(
                    padding: const EdgeInsets.all(24),
                    crossAxisCount: isWide ? 2 : 1,
                    mainAxisSpacing: 24,
                    crossAxisSpacing: 24,
                    childAspectRatio: isWide ? 1.4 : 1.1,
                    children: [
                      _buildSfChart("İç Sıcaklık Değişimi (°C)", tempHistory, Colors.orange, "°C", 10, 45, true),
                      _buildSfChart("Hava Nemi (%)", humidityHistory, Colors.blue, "%", 0, 100, false),
                      _buildSfChart("Toprak Nemi (%)", soilHistory, Colors.brown, "%", 0, 100, false),
                      _buildSfChart("Işık Şiddeti (Lux)", luxHistory, Colors.amber, " Lx", 0, 1200, false),
                      _buildSfChart("CO2 Seviyesi (ppm)", co2History, Colors.blueGrey, " ppm", 300, 1200, false),
                      _buildSfChart("Sistem Voltajı (V)", voltageHistory, Colors.green, "V", 10, 15, false),
                    ],
                  );
                },
              ),
            ),
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
                    markerSettings: const MarkerSettings(isVisible: true, width: 4, height: 4),
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
