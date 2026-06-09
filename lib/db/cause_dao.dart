import '../models/cause_record.dart';
import 'database_helper.dart';

class CauseDao {
  final _db = DatabaseHelper.instance;

  Future<int> insert(CauseRecord record) async {
    final db = await _db.database;
    return await db.insert('cause_records', record.toMap());
  }

  Future<List<CauseRecord>> getByUserId(int userId) async {
    final db = await _db.database;
    final rows = await db.query(
      'cause_records',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'recorded_at DESC',
    );
    return rows.map(CauseRecord.fromMap).toList();
  }

  Future<List<CauseRecord>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('cause_records', orderBy: 'recorded_at DESC');
    return rows.map(CauseRecord.fromMap).toList();
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return await db.delete('cause_records', where: 'id = ?', whereArgs: [id]);
  }
}
