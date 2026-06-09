class CauseRecord {
  final int? id;
  final int? userId;
  final int? measurementId;
  final String symptom;      // 증상
  final String cause;        // 원인
  final DateTime recordedAt;

  CauseRecord({
    this.id,
    this.userId,
    this.measurementId,
    required this.symptom,
    required this.cause,
    DateTime? recordedAt,
  }) : recordedAt = recordedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'measurement_id': measurementId,
        'content': '$symptom|$cause',
        'recorded_at': recordedAt.toIso8601String(),
      };

  factory CauseRecord.fromMap(Map<String, dynamic> map) {
    final content = map['content'] as String;
    final parts = content.split('|');
    return CauseRecord(
      id: map['id'] as int?,
      userId: map['user_id'] as int?,
      measurementId: map['measurement_id'] as int?,
      symptom: parts.isNotEmpty ? parts[0] : content,
      cause: parts.length > 1 ? parts[1] : '',
      recordedAt: DateTime.parse(map['recorded_at'] as String),
    );
  }
}
