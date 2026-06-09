class User {
  final int? id;
  final String name;
  final int? birthYear;
  final String? gender;   // 'M' | 'F'
  final String? region;
  final String? phone;
  final String? serverId;
  final DateTime createdAt;

  User({
    this.id,
    required this.name,
    this.birthYear,
    this.gender,
    this.region,
    this.phone,
    this.serverId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'birth_year': birthYear,
        'gender': gender,
        'region': region,
        'phone': phone,
        'server_id': serverId,
        'created_at': createdAt.toIso8601String(),
      };

  factory User.fromMap(Map<String, dynamic> map) => User(
        id: map['id'] as int?,
        name: map['name'] as String,
        birthYear: map['birth_year'] as int?,
        gender: map['gender'] as String?,
        region: map['region'] as String?,
        phone: map['phone'] as String?,
        serverId: map['server_id'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  User copyWith({
    int? id,
    String? name,
    int? birthYear,
    String? gender,
    String? region,
    String? phone,
    String? serverId,
  }) =>
      User(
        id: id ?? this.id,
        name: name ?? this.name,
        birthYear: birthYear ?? this.birthYear,
        gender: gender ?? this.gender,
        region: region ?? this.region,
        phone: phone ?? this.phone,
        serverId: serverId ?? this.serverId,
        createdAt: createdAt,
      );
}
