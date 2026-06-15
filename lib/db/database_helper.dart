import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _db;

  DatabaseHelper._internal();

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'atec_health.db');

    return await openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE users ADD COLUMN server_id TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE users ADD COLUMN birth_year INTEGER');
      await db.execute('ALTER TABLE users ADD COLUMN gender TEXT');
      await db.execute('ALTER TABLE users ADD COLUMN region TEXT');
    }
    if (oldVersion < 4) {
      // 오프라인 가입 시 얼굴 임베딩 보존 + 서버 미동기화 데이터 추적
      await db.execute('ALTER TABLE users ADD COLUMN face_descriptor TEXT');
      await db.execute(
          'ALTER TABLE measurements ADD COLUMN synced INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE cause_records ADD COLUMN synced INTEGER NOT NULL DEFAULT 0');
      await db.execute('UPDATE measurements SET synced = 1');
      await db.execute('UPDATE cause_records SET synced = 1');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE users ADD COLUMN birth_month INTEGER');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // 사용자 테이블
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        birth_year INTEGER,
        birth_month INTEGER,
        gender TEXT,
        region TEXT,
        phone TEXT,
        server_id TEXT,
        face_descriptor TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // HRV 측정 결과 테이블
    await db.execute('''
      CREATE TABLE measurements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        heart_rate REAL NOT NULL,
        hrv REAL NOT NULL,
        stress_index REAL NOT NULL,
        stress_level TEXT NOT NULL,
        hrv_level TEXT NOT NULL,
        measurement_duration INTEGER NOT NULL,
        rr_intervals TEXT NOT NULL,
        measured_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    // 원인 기록 테이블 (추후 사용)
    await db.execute('''
      CREATE TABLE cause_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        measurement_id INTEGER,
        content TEXT NOT NULL,
        recorded_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users(id),
        FOREIGN KEY (measurement_id) REFERENCES measurements(id)
      )
    ''');
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
