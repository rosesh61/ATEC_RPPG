import '../models/measurement_record.dart';
import 'database_helper.dart';

class MeasurementDao {
  final _db = DatabaseHelper.instance;

  Future<int> insert(MeasurementRecord record) async {
    final db = await _db.database;
    return await db.insert('measurements', record.toMap());
  }

  Future<MeasurementRecord?> getById(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      'measurements',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return MeasurementRecord.fromMap(rows.first);
  }

  /// 전체 측정 기록 (최신순)
  Future<List<MeasurementRecord>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('measurements', orderBy: 'measured_at DESC');
    return rows.map(MeasurementRecord.fromMap).toList();
  }

  /// 특정 사용자의 측정 기록 (최신순)
  Future<List<MeasurementRecord>> getByUserId(int userId) async {
    final db = await _db.database;
    final rows = await db.query(
      'measurements',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'measured_at DESC',
    );
    return rows.map(MeasurementRecord.fromMap).toList();
  }

  /// 날짜 범위로 조회
  Future<List<MeasurementRecord>> getByDateRange(
    DateTime from,
    DateTime to, {
    int? userId,
  }) async {
    final db = await _db.database;
    final where = userId != null
        ? 'measured_at >= ? AND measured_at <= ? AND user_id = ?'
        : 'measured_at >= ? AND measured_at <= ?';
    final args = userId != null
        ? [from.toIso8601String(), to.toIso8601String(), userId]
        : [from.toIso8601String(), to.toIso8601String()];

    final rows = await db.query(
      'measurements',
      where: where,
      whereArgs: args,
      orderBy: 'measured_at DESC',
    );
    return rows.map(MeasurementRecord.fromMap).toList();
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return await db.delete('measurements', where: 'id = ?', whereArgs: [id]);
  }
}
