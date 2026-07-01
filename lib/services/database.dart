import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  static Database? _database;

  LocalDatabase._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'windesign_craftv2.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createTables,
      onUpgrade: _handleUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE window_systems (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        sort_order INTEGER DEFAULT 0,
        unit_price REAL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE window_series (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        system_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        sort_order INTEGER DEFAULT 0,
        unit_price REAL DEFAULT 0,
        FOREIGN KEY (system_id) REFERENCES window_systems(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE window_colors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        series_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        sort_order INTEGER DEFAULT 0,
        unit_price REAL DEFAULT 0,
        FOREIGN KEY (series_id) REFERENCES window_series(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE projects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        address TEXT NOT NULL,
        description TEXT,
        created_at TEXT NOT NULL,
        discount REAL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE drawings (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        drawing_data TEXT,
        location TEXT,
        direction TEXT,
        height REAL,
        width REAL,
        room_description TEXT,
        system_name TEXT,
        series_name TEXT,
        profile_color TEXT,
        glass_system TEXT,
        glass_tone TEXT,
        description TEXT,
        FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE glass_systems (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        unit_price REAL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE glass_tones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        unit_price REAL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE accessories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        unit_price REAL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id TEXT NOT NULL,
        amount REAL NOT NULL,
        paid_at TEXT NOT NULL,
        note TEXT,
        dekont_no TEXT UNIQUE,
        status TEXT NOT NULL DEFAULT 'active',
        cancelled_at TEXT,
        cancel_reason TEXT,
        FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _handleUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _ensureDrawingColumns(db);
      await _ensureUnitPriceColumns(db);
      await _ensureProjectColumns(db);

      await db.execute('''
        CREATE TABLE IF NOT EXISTS payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          project_id TEXT NOT NULL,
          amount REAL NOT NULL,
          paid_at TEXT NOT NULL,
          note TEXT,
          FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 3) {
      await _ensurePaymentColumns(db);
    }
  }

  Future<void> _ensurePaymentColumns(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(payments)');
    final columnNames = columns.map((c) => c['name'] as String).toSet();

    if (!columnNames.contains('dekont_no')) {
      await db.execute('ALTER TABLE payments ADD COLUMN dekont_no TEXT');
    }
    if (!columnNames.contains('status')) {
      await db.execute(
        "ALTER TABLE payments ADD COLUMN status TEXT NOT NULL DEFAULT 'active'",
      );
    }
    if (!columnNames.contains('cancelled_at')) {
      await db.execute('ALTER TABLE payments ADD COLUMN cancelled_at TEXT');
    }
    if (!columnNames.contains('cancel_reason')) {
      await db.execute('ALTER TABLE payments ADD COLUMN cancel_reason TEXT');
    }
  }

  Future<void> _ensureProjectColumns(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(projects)');
    final columnNames = columns.map((c) => c['name'] as String).toSet();
    if (!columnNames.contains('discount')) {
      await db.execute(
        'ALTER TABLE projects ADD COLUMN discount REAL DEFAULT 0',
      );
    }
  }

  Future<void> _ensureUnitPriceColumns(Database db) async {
    final tables = [
      'window_systems',
      'window_series',
      'window_colors',
      'glass_systems',
      'glass_tones',
    ];
    for (final table in tables) {
      final columns = await db.rawQuery('PRAGMA table_info($table)');
      final columnNames = columns.map((c) => c['name'] as String).toSet();
      if (!columnNames.contains('unit_price')) {
        await db.execute(
          'ALTER TABLE $table ADD COLUMN unit_price REAL DEFAULT 0',
        );
      }
    }
  }

  Future<void> _ensureDrawingColumns(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(drawings)');
    final columnNames = columns.map((c) => c['name'] as String).toSet();

    final newColumns = {
      'system_name': 'TEXT',
      'series_name': 'TEXT',
      'profile_color': 'TEXT',
      'glass_system': 'TEXT',
      'glass_tone': 'TEXT',
      'description': 'TEXT',
    };

    for (final entry in newColumns.entries) {
      if (!columnNames.contains(entry.key)) {
        await db.execute(
          'ALTER TABLE drawings ADD COLUMN ${entry.key} ${entry.value}',
        );
      }
    }
  }

  // ==================== PROJE İŞLEMLERİ ====================

  Future<int> insertProject(Map<String, dynamic> project) async {
    final db = await database;
    return await db.insert(
      'projects',
      project,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getProjects() async {
    final db = await database;
    return await db.query('projects', orderBy: 'created_at DESC');
  }

  Future<int> deleteProject(String id) async {
    final db = await database;
    try {
      final result = await db.delete(
        'projects',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (result == 0) throw Exception('Proje bulunamadı: $id');
      return result;
    } catch (e) {
      rethrow;
    }
  }

  Future<int> updateProject(Map<String, dynamic> project) async {
    final db = await database;
    return await db.update(
      'projects',
      project,
      where: 'id = ?',
      whereArgs: [project['id']],
    );
  }

  Future<Map<String, dynamic>?> getProjectById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'projects',
      where: 'id = ?',
      whereArgs: [id],
    );
    return maps.isNotEmpty ? maps.first : null;
  }

  Future<bool> projectExists(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'projects',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  // ==================== ÇİZİM İŞLEMLERİ ====================

  Future<int> insertDrawing(Map<String, dynamic> drawing) async {
    final db = await database;
    return await db.insert(
      'drawings',
      drawing,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getDrawingsByProject(
    String projectId,
  ) async {
    final db = await database;
    return await db.query(
      'drawings',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'created_at DESC, updated_at DESC',
    );
  }

  Future<int> updateDrawing(Map<String, dynamic> drawing) async {
    final db = await database;
    return await db.update(
      'drawings',
      drawing,
      where: 'id = ?',
      whereArgs: [drawing['id']],
    );
  }

  Future<int> deleteDrawing(String id) async {
    final db = await database;
    return await db.delete('drawings', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> getDrawingById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'drawings',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return maps.isNotEmpty ? maps.first : null;
  }

  Future<int> insertDrawingWithTransaction(Map<String, dynamic> drawing) async {
    final db = await database;
    return await db.transaction((txn) async {
      final project = await txn.query(
        'projects',
        where: 'id = ?',
        whereArgs: [drawing['project_id']],
        limit: 1,
      );
      if (project.isEmpty)
        throw Exception('Proje bulunamadı: ${drawing['project_id']}');

      final result = await txn.insert(
        'drawings',
        drawing,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (result == 0) throw Exception('Çizim eklenemedi');
      return result;
    });
  }

  Future<int> getDrawingCount(String projectId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM drawings WHERE project_id = ?',
      [projectId],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getRecentDrawings({int limit = 10}) async {
    final db = await database;
    return await db.query(
      'drawings',
      where: 'updated_at IS NOT NULL',
      orderBy: 'updated_at DESC',
      limit: limit,
    );
  }

  // ==================== ÖDEME İŞLEMLERİ ====================

  /// Dekont numarası üretir: DKT-YYYY-NNNN
  Future<String> _generateDekontNo(Database db) async {
    final year = DateTime.now().year;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM payments WHERE dekont_no LIKE 'DKT-$year-%'",
    );
    final count = ((result.first['count'] as int?) ?? 0) + 1;
    return 'DKT-$year-${count.toString().padLeft(4, '0')}';
  }

  Future<int> insertPayment(Map<String, dynamic> payment) async {
    final db = await database;
    final dekontNo = await _generateDekontNo(db);
    final paymentWithDekont = Map<String, dynamic>.from(payment);
    paymentWithDekont['dekont_no'] = dekontNo;
    paymentWithDekont['status'] = 'active';
    return await db.insert(
      'payments',
      paymentWithDekont,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getPaymentsByProject(
    String projectId,
  ) async {
    final db = await database;
    return await db.query(
      'payments',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'paid_at DESC',
    );
  }

  Future<Map<String, dynamic>?> getPaymentById(int id) async {
    final db = await database;
    final maps = await db.query(
      'payments',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return maps.isNotEmpty ? maps.first : null;
  }

  Future<Map<String, dynamic>?> getPaymentByDekontNo(String dekontNo) async {
    final db = await database;
    final maps = await db.query(
      'payments',
      where: 'dekont_no = ?',
      whereArgs: [dekontNo],
      limit: 1,
    );
    return maps.isNotEmpty ? maps.first : null;
  }

  /// Ödemeyi siler değil, iptal eder.
  Future<int> cancelPayment(int id, {String? reason}) async {
    final db = await database;
    return await db.update(
      'payments',
      {
        'status': 'cancelled',
        'cancelled_at': DateTime.now().toIso8601String(),
        'cancel_reason': reason ?? 'Manuel iptal',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Gerçekten silmek gerekirse (sadece backup restore gibi özel durumlar için).
  Future<int> deletePayment(int id) async {
    final db = await database;
    return await db.delete('payments', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== EXCEL EXPORT ====================

  /// Tüm projeleri ve ödemeleri döner (Excel export için).
  Future<Map<String, dynamic>> getExportData() async {
    final db = await database;
    final projects = await db.query('projects', orderBy: 'created_at DESC');
    final payments = await db.query('payments', orderBy: 'paid_at DESC');
    return {'projects': projects, 'payments': payments};
  }

  // ==================== DURUM ====================

  Future<Map<String, dynamic>> getDatabaseStatus() async {
    final db = await database;
    final projectsCount = await db.rawQuery('SELECT COUNT(*) FROM projects');
    final drawingsCount = await db.rawQuery('SELECT COUNT(*) FROM drawings');
    return {
      'projects': (projectsCount.first['COUNT(*)'] as int?) ?? 0,
      'drawings': (drawingsCount.first['COUNT(*)'] as int?) ?? 0,
      'version': 3,
    };
  }
}
