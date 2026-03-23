import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class ChartDataPoint {
  ChartDataPoint(this.x, this.y);
  final int x;
  final double y;
}

class ChartsPage extends StatelessWidget {
  const ChartsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<ChartDataPoint> tempHistory = [ChartDataPoint(0, 22), ChartDataPoint(1, 24), ChartDataPoint(2, 28), ChartDataPoint(3, 26), ChartDataPoint(4, 30), ChartDataPoint(5, 27)];
    final List<ChartDataPoint> humidityHistory = [ChartDataPoint(0, 45), ChartDataPoint(1, 50), ChartDataPoint(2, 48), ChartDataPoint(3, 55), ChartDataPoint(4, 52), ChartDataPoint(5, 49)];
    final List<ChartDataPoint> soilHistory = [ChartDataPoint(0, 35), ChartDataPoint(1, 38), ChartDataPoint(2, 34), ChartDataPoint(3, 40), ChartDataPoint(4, 38)];
    final List<ChartDataPoint> luxHistory = [ChartDataPoint(0, 400), ChartDataPoint(1, 500), ChartDataPoint(2, 600), ChartDataPoint(3, 450), ChartDataPoint(4, 550)];
    final List<ChartDataPoint> co2History = [ChartDataPoint(0, 380), ChartDataPoint(1, 400), ChartDataPoint(2, 420), ChartDataPoint(3, 400), ChartDataPoint(4, 410)];
    final List<ChartDataPoint> voltageHistory = [ChartDataPoint(0, 12.1), ChartDataPoint(1, 12.4), ChartDataPoint(2, 12.3), ChartDataPoint(3, 12.4), ChartDataPoint(4, 12.4)];

    return Scaffold(
      appBar: AppBar(title: const Text("Detaylı Grafik Analizi", style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildSfChart("İç Sıcaklık Değişimi (°C)", tempHistory, Colors.orange, "°C", 15, 40, true),
          const SizedBox(height: 15),
          _buildSfChart("İç Nem Değişimi (%)", humidityHistory, Colors.blue, "%", 0, 100, false),
          const SizedBox(height: 15),
          _buildSfChart("Toprak Nemi (%)", soilHistory, Colors.brown, "%", 0, 100, false),
          const SizedBox(height: 15),
          _buildSfChart("Işık Şiddeti (Lux)", luxHistory, Colors.amber, " Lx", 0, 1000, false),
          const SizedBox(height: 15),
          _buildSfChart("CO2 Konsantrasyonu (ppm)", co2History, Colors.blueGrey, " ppm", 300, 1000, false),
          const SizedBox(height: 15),
          _buildSfChart("Sistem Voltajı (V)", voltageHistory, Colors.green, "V", 10, 15, false),
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
