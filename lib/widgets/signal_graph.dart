import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/constants.dart';

class SignalGraph extends StatelessWidget {
  final List<double> signalData;
  final double? currentHeartRate;

  const SignalGraph({
    super.key,
    required this.signalData,
    this.currentHeartRate,
  });

  @override
  Widget build(BuildContext context) {
    if (signalData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          if (currentHeartRate != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${currentHeartRate!.toStringAsFixed(0)} ${AppStrings.bpm}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.white.withOpacity(0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: signalData.length.toDouble() - 1,
                minY: _getMinValue(),
                maxY: _getMaxValue(),
                lineBarsData: [
                  LineChartBarData(
                    spots: signalData
                        .asMap()
                        .entries
                        .map((entry) => FlSpot(
                              entry.key.toDouble(),
                              entry.value,
                            ))
                        .toList(),
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withOpacity(0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _getMinValue() {
    if (signalData.isEmpty) return 0;
    final min = signalData.reduce((a, b) => a < b ? a : b);
    return min - 0.5;
  }

  double _getMaxValue() {
    if (signalData.isEmpty) return 1;
    final max = signalData.reduce((a, b) => a > b ? a : b);
    return max + 0.5;
  }
}
