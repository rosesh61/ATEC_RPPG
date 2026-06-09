import 'dart:math';
import '../models/measurement_result.dart';

class HrvService {
  /// Calculate HRV and stress index from heart rate data
  /// Based on time-domain analysis (RMSSD) and frequency-domain analysis
  MeasurementResult calculateFromHeartRates(
    List<double> heartRates,
    int measurementDuration,
  ) {
    if (heartRates.isEmpty) {
      throw Exception('No heart rate data available');
    }

    // Filter out invalid heart rates
    final validHeartRates = heartRates
        .where((hr) => hr > 40 && hr < 200)
        .toList();

    if (validHeartRates.isEmpty) {
      throw Exception('No valid heart rate data');
    }

    // Calculate RR intervals from heart rates (in milliseconds)
    final rrIntervals = validHeartRates
        .map((hr) => 60000.0 / hr)
        .toList();

    // Calculate average heart rate
    final avgHeartRate = validHeartRates.reduce((a, b) => a + b) / validHeartRates.length;

    // Calculate RMSSD (Root Mean Square of Successive Differences)
    final hrv = _calculateRMSSD(rrIntervals);

    // Calculate stress index based on HRV and HR variability
    final stressIndex = _calculateStressIndex(avgHeartRate, hrv, rrIntervals);

    return MeasurementResult(
      heartRate: avgHeartRate,
      hrv: hrv,
      stressIndex: stressIndex,
      rrIntervals: rrIntervals,
      timestamp: DateTime.now(),
      measurementDuration: measurementDuration,
    );
  }

  /// Calculate RMSSD (Root Mean Square of Successive Differences)
  /// This is a time-domain measure of HRV
  double _calculateRMSSD(List<double> rrIntervals) {
    if (rrIntervals.length < 2) return 0.0;

    double sumSquaredDiff = 0.0;
    for (int i = 1; i < rrIntervals.length; i++) {
      final diff = rrIntervals[i] - rrIntervals[i - 1];
      sumSquaredDiff += diff * diff;
    }

    return sqrt(sumSquaredDiff / (rrIntervals.length - 1));
  }

  /// Calculate SDNN (Standard Deviation of NN intervals)
  double _calculateSDNN(List<double> rrIntervals) {
    if (rrIntervals.isEmpty) return 0.0;

    final mean = rrIntervals.reduce((a, b) => a + b) / rrIntervals.length;
    final variance = rrIntervals
        .map((rr) => pow(rr - mean, 2))
        .reduce((a, b) => a + b) / rrIntervals.length;

    return sqrt(variance);
  }

  /// Calculate stress index (0-100)
  double _calculateStressIndex(
    double avgHeartRate,
    double hrv,
    List<double> rrIntervals,
  ) {
    // Normalize heart rate component (60-80 is normal resting)
    double hrComponent = 0.0;
    if (avgHeartRate < 60) {
      hrComponent = 0.0;
    } else if (avgHeartRate < 80) {
      hrComponent = (avgHeartRate - 60) / 20 * 30;
    } else if (avgHeartRate < 100) {
      hrComponent = 30 + (avgHeartRate - 80) / 20 * 30;
    } else {
      hrComponent = 60 + min((avgHeartRate - 100) / 20 * 40, 40);
    }

    // Normalize HRV component (higher HRV = lower stress)
    double hrvComponent = 0.0;
    if (hrv > 50) {
      hrvComponent = 0.0;
    } else if (hrv > 30) {
      hrvComponent = (50 - hrv) / 20 * 30;
    } else if (hrv > 20) {
      hrvComponent = 30 + (30 - hrv) / 10 * 30;
    } else {
      hrvComponent = 60 + (20 - hrv) / 20 * 40;
    }

    // Calculate variability component
    final sdnn = _calculateSDNN(rrIntervals);
    double variabilityComponent = 0.0;
    if (sdnn < 20) {
      variabilityComponent = 30.0;
    } else if (sdnn < 50) {
      variabilityComponent = 30 - (sdnn - 20) / 30 * 30;
    }

    // Weighted average of components
    final stressIndex = (hrComponent * 0.3 + hrvComponent * 0.5 + variabilityComponent * 0.2);

    return stressIndex.clamp(0.0, 100.0);
  }
}
