import 'measurement_record.dart';

class MeasurementResult {
  final double heartRate;
  final double hrv; // Heart Rate Variability (RMSSD in ms)
  final double stressIndex; // Stress index (0-100)
  final List<double> rrIntervals; // RR intervals in ms
  final DateTime timestamp;
  final int measurementDuration; // in seconds

  MeasurementResult({
    required this.heartRate,
    required this.hrv,
    required this.stressIndex,
    required this.rrIntervals,
    required this.timestamp,
    required this.measurementDuration,
  });

  String get stressLevel {
    if (stressIndex < 30) return '낮음';
    if (stressIndex < 60) return '보통';
    if (stressIndex < 80) return '높음';
    return '매우 높음';
  }

  String get hrvLevel {
    if (hrv > 50) return '우수';
    if (hrv > 30) return '양호';
    if (hrv > 20) return '보통';
    return '주의 필요';
  }

  MeasurementRecord toRecord({int? userId}) => MeasurementRecord(
        userId: userId,
        heartRate: heartRate,
        hrv: hrv,
        stressIndex: stressIndex,
        stressLevel: stressLevel,
        hrvLevel: hrvLevel,
        measurementDuration: measurementDuration,
        rrIntervals: rrIntervals,
        measuredAt: timestamp,
      );
}
