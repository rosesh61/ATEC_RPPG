import 'dart:convert';

class User {
  final int? id;
  final String name;
  final int? birthYear;
  final int? birthMonth;
  final String? gender;   // 'M' | 'F'
  final String? region;
  final String? phone;
  final String? serverId;

  /// 얼굴 임베딩 (128차원). 가입 시점에 서버 등록이 실패해도
  /// 나중에 SyncService가 올릴 수 있도록 로컬에 보존한다.
  final List<double>? faceDescriptor;
  final DateTime createdAt;

  User({
    this.id,
    required this.name,
    this.birthYear,
    this.birthMonth,
    this.gender,
    this.region,
    this.phone,
    this.serverId,
    this.faceDescriptor,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'birth_year': birthYear,
        'birth_month': birthMonth,
        'gender': gender,
        'region': region,
        'phone': phone,
        'server_id': serverId,
        'face_descriptor':
            faceDescriptor != null ? jsonEncode(faceDescriptor) : null,
        'created_at': createdAt.toIso8601String(),
      };

  factory User.fromMap(Map<String, dynamic> map) => User(
        id: map['id'] as int?,
        name: map['name'] as String,
        birthYear: map['birth_year'] as int?,
        birthMonth: map['birth_month'] as int?,
        gender: map['gender'] as String?,
        region: map['region'] as String?,
        phone: map['phone'] as String?,
        serverId: map['server_id'] as String?,
        faceDescriptor: map['face_descriptor'] != null
            ? (jsonDecode(map['face_descriptor'] as String) as List)
                .map((e) => (e as num).toDouble())
                .toList()
            : null,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  User copyWith({
    int? id,
    String? name,
    int? birthYear,
    int? birthMonth,
    String? gender,
    String? region,
    String? phone,
    String? serverId,
    List<double>? faceDescriptor,
  }) =>
      User(
        id: id ?? this.id,
        name: name ?? this.name,
        birthYear: birthYear ?? this.birthYear,
        birthMonth: birthMonth ?? this.birthMonth,
        gender: gender ?? this.gender,
        region: region ?? this.region,
        phone: phone ?? this.phone,
        serverId: serverId ?? this.serverId,
        faceDescriptor: faceDescriptor ?? this.faceDescriptor,
        createdAt: createdAt,
      );
}
