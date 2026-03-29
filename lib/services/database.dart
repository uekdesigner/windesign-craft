// lib/data/datasources/local_database.dart
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
    final path = join(dbPath, 'windesign_craft.db');

    return await openDatabase(
      path,
      version: 10,
      onCreate: _createTables,
      onUpgrade: _updateDatabase,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('PRAGMA foreign_keys = ON');

    // Projeler tablosu
    await db.execute('''
      CREATE TABLE projects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        address TEXT NOT NULL,
        description TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Çizimler tablosu
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
        FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _updateDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    await db.execute('PRAGMA foreign_keys = ON');

    if (oldVersion < 10) {
      // Yeni ShapeSpec modeli için eski verileri temizle
      await db.execute('DROP TABLE IF EXISTS drawings');
      await db.execute('DROP TABLE IF EXISTS projects');
      await _createTables(db, 10);
    }

    // 🚨 YENİ: Version 7 için optimizasyonlar
    if (oldVersion < 7) {
      try {
        // Yeni index'ler
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_drawings_project_updated 
          ON drawings (project_id, updated_at DESC)
        ''');

        // Mevcut verileri optimize et
        await db.execute('VACUUM');
      } catch (e) {
        print('⚠️ Database update error: $e');
      }
    }
    if (oldVersion < 9) {
      await db.execute('DROP TABLE IF EXISTS drawings');
      await db.execute('DROP TABLE IF EXISTS projects');
      await _createTables(db, 9);
    }
    if (oldVersion < 6) {
      try {
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_drawings_project_id 
          ON drawings (project_id)
        ''');
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_drawings_created_at 
          ON drawings (created_at DESC)
        ''');
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_projects_created_at 
          ON projects (created_at DESC)
        ''');
      } catch (e) {
        print('⚠️ Index creation error: $e');
      }
    }

    if (oldVersion < 3) {
      await db.execute('DROP TABLE IF EXISTS drawings');
      await db.execute('DROP TABLE IF EXISTS projects');
      await _createTables(db, 3);
    }

    if (oldVersion < 4) {
      try {
        await db.execute('''
          CREATE TABLE drawings_backup_v4 AS 
          SELECT * FROM drawings
        ''');
        await db.execute('''
          CREATE TABLE drawings_new (
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
            FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          INSERT INTO drawings_new 
          SELECT * FROM drawings
        ''');
        await db.execute('DROP TABLE drawings');
        await db.execute('ALTER TABLE drawings_new RENAME TO drawings');
        await db.execute('DROP TABLE drawings_backup_v4');
      } catch (e) {
        print('⚠️ Version 4 migration error: $e');
      }
    }
  }

  // PROJE İŞLEMLERİ
  Future<int> insertProject(Map<String, dynamic> project) async {
    final db = await database;
    return await db.insert('projects', project);
  }

  Future<List<Map<String, dynamic>>> getProjects() async {
    final db = await database;
    return await db.query('projects', orderBy: 'created_at DESC');
  }

  Future<int> deleteProject(String id) async {
    final db = await database;

    // Önce foreign key check
    try {
      final result = await db.delete(
        'projects',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (result == 0) {
        throw Exception('Proje bulunamadı: $id');
      }
      return result;
    } catch (e) {
      print('❌ Delete project error: $e');
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

  // ÇİZİM İŞLEMLERİ
  Future<int> insertDrawing(Map<String, dynamic> drawing) async {
    final db = await database;

    // Projenin var olduğundan emin ol
    final project = await getProjectById(drawing['project_id']);
    if (project == null) {
      throw Exception('Proje bulunamadı: ${drawing['project_id']}');
    }

    return await db.insert('drawings', drawing);
  }

  Future<List<Map<String, dynamic>>> getDrawingsByProject(
    String projectId,
  ) async {
    final db = await database;

    // Projenin var olduğundan emin ol
    final project = await getProjectById(projectId);
    if (project == null) {
      throw Exception('Proje bulunamadı: $projectId');
    }

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

  // 🚨 YENİ: Toplu işlem için transaction
  Future<int> insertDrawingWithTransaction(Map<String, dynamic> drawing) async {
    final db = await database;

    return await db.transaction((txn) async {
      // Proje kontrolü
      final project = await txn.query(
        'projects',
        where: 'id = ?',
        whereArgs: [drawing['project_id']],
        limit: 1,
      );

      if (project.isEmpty) {
        throw Exception('Proje bulunamadı: ${drawing['project_id']}');
      }

      // Çizimi ekle
      final result = await txn.insert('drawings', drawing);

      if (result == 0) {
        throw Exception('Çizim eklenemedi');
      }

      return result;
    });
  }

  // 🚨 YENİ: Çizim sayısını getir
  Future<int> getDrawingCount(String projectId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM drawings WHERE project_id = ?',
      [projectId],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  // 🚨 YENİ: Son güncellenen çizimleri getir
  Future<List<Map<String, dynamic>>> getRecentDrawings({int limit = 10}) async {
    final db = await database;
    return await db.query(
      'drawings',
      where: 'updated_at IS NOT NULL',
      orderBy: 'updated_at DESC',
      limit: limit,
    );
  }

  // 🚨 YENİ: Veritabanı durumunu kontrol et
  Future<Map<String, dynamic>> getDatabaseStatus() async {
    final db = await database;
    final projectsCount = await db.rawQuery('SELECT COUNT(*) FROM projects');
    final drawingsCount = await db.rawQuery('SELECT COUNT(*) FROM drawings');

    return {
      'projects': (projectsCount.first['COUNT(*)'] as int?) ?? 0,
      'drawings': (drawingsCount.first['COUNT(*)'] as int?) ?? 0,
      'version': 7,
    };
  }
}
