import '../models/user.dart';
import 'database_helper.dart';

class UserDao {
  final _db = DatabaseHelper.instance;

  Future<int> insert(User user) async {
    final db = await _db.database;
    return await db.insert('users', user.toMap());
  }

  Future<User?> getById(int id) async {
    final db = await _db.database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return User.fromMap(rows.first);
  }

  Future<List<User>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('users', orderBy: 'created_at DESC');
    return rows.map(User.fromMap).toList();
  }

  Future<User?> getByServerId(String serverId) async {
    final db = await _db.database;
    final rows = await db.query(
      'users',
      where: 'server_id = ?',
      whereArgs: [serverId],
    );
    if (rows.isEmpty) return null;
    return User.fromMap(rows.first);
  }

  /// 서버에 아직 등록되지 않은 사용자 (server_id 없음)
  Future<List<User>> getUnsynced() async {
    final db = await _db.database;
    final rows = await db.query('users', where: 'server_id IS NULL');
    return rows.map(User.fromMap).toList();
  }

  Future<int> update(User user) async {
    final db = await _db.database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }
}
