import 'dart:convert';

/// DB 저장/조회용 모델 (MeasurementResult는 계산 직후 임시 결과용으로 유지)
class MeasurementRecord {
  final int? id;
  final int? userId;
  final double heartRate;
  final double hrv;
  final double stressIndex;
  final String stressLevel;
  final String hrvLevel;
  final int measurementDuration;
  final List<double> rrIntervals;
  final DateTime measuredAt;

  MeasurementRecord({
    this.id,
    this.userId,
    required this.heartRate,
    required this.hrv,
    required this.stressIndex,
    required this.stressLevel,
    required this.hrvLevel,
    required this.measurementDuration,
    required this.rrIntervals,
    DateTime? measuredAt,
  }) : measuredAt = measuredAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'heart_rate': heartRate,
        'hrv': hrv,
        'stress_index': stressIndex,
        'stress_level': stressLevel,
        'hrv_level': hrvLevel,
        'measurement_duration': measurementDuration,
        'rr_intervals': jsonEncode(rrIntervals),
        'measured_at': measuredAt.toIso8601String(),
      };

  factory MeasurementRecord.fromMap(Map<String, dynamic> map) =>
      MeasurementRecord(
        id: map['id'] as int?,
        userId: map['user_id'] as int?,
        heartRate: (map['heart_rate'] as num).toDouble(),
        hrv: (map['hrv'] as num).toDouble(),
        stressIndex: (map['stress_index'] as num).toDouble(),
        stressLevel: map['stress_level'] as String,
        hrvLevel: map['hrv_level'] as String,
        measurementDuration: map['measurement_duration'] as int,
        rrIntervals: (jsonDecode(map['rr_intervals'] as String) as List)
            .map((e) => (e as num).toDouble())
            .toList(),
        measuredAt: DateTime.parse(map['measured_at'] as String),
      );
}
