import 'package:sqflite/sqflite.dart';
import '../models/window_system.dart';

class WindowSystemRepository {
  final Database _db;

  WindowSystemRepository(this._db);

  Future<List<WindowSystem>> getAll() async {
    final systemsData = await _db.query('window_systems', orderBy: 'name ASC');

    final List<WindowSystem> systems = [];

    for (final sysMap in systemsData) {
      final systemId = sysMap['id'] as int;

      final seriesData = await _db.query(
        'window_series',
        where: 'system_id = ?',
        whereArgs: [systemId],
        orderBy: 'name ASC',
      );

      final List<WindowSeries> series = [];

      for (final serMap in seriesData) {
        final seriesId = serMap['id'] as int;

        final colorsData = await _db.query(
          'window_colors',
          where: 'series_id = ?',
          whereArgs: [seriesId],
          orderBy: 'name ASC',
        );

        series.add(
          WindowSeries(
            id: seriesId,
            systemId: systemId,
            name: serMap['name'] as String,
            sortOrder: serMap['sort_order'] as int? ?? 0,
            unitPrice: (serMap['unit_price'] as num?)?.toDouble() ?? 0.0,
            colors: colorsData
                .map(
                  (c) => WindowColor(
                    id: c['id'] as int,
                    seriesId: seriesId,
                    name: c['name'] as String,
                    sortOrder: c['sort_order'] as int? ?? 0,
                    unitPrice: (c['unit_price'] as num?)?.toDouble() ?? 0.0,
                  ),
                )
                .toList(),
          ),
        );
      }

      systems.add(
        WindowSystem(
          id: systemId,
          name: sysMap['name'] as String,
          sortOrder: sysMap['sort_order'] as int? ?? 0,
          unitPrice: (sysMap['unit_price'] as num?)?.toDouble() ?? 0.0,
          series: series,
        ),
      );
    }

    return systems;
  }

  Future<int> addSystem(String name, {double unitPrice = 0.0}) async {
    return await _db.insert('window_systems', {
      'name': name,
      'sort_order': 999,
      'unit_price': unitPrice,
    });
  }

  Future<void> deleteSystem(int id) async {
    await _db.transaction((txn) async {
      final series = await txn.query(
        'window_series',
        columns: ['id'],
        where: 'system_id = ?',
        whereArgs: [id],
      );
      for (final s in series) {
        final seriesId = s['id'] as int;
        await txn.delete(
          'window_colors',
          where: 'series_id = ?',
          whereArgs: [seriesId],
        );
      }
      await txn.delete(
        'window_series',
        where: 'system_id = ?',
        whereArgs: [id],
      );
      await txn.delete('window_systems', where: 'id = ?', whereArgs: [id]);
    });
  }
  // ==================== SERİ CRUD ====================

  Future<int> addSeries(
    int systemId,
    String name, {
    double unitPrice = 0.0,
  }) async {
    return await _db.insert('window_series', {
      'system_id': systemId,
      'name': name,
      'sort_order': 999,
      'unit_price': unitPrice,
    });
  }

  Future<void> deleteSeries(int id) async {
    await _db.transaction((txn) async {
      await txn.delete(
        'window_colors',
        where: 'series_id = ?',
        whereArgs: [id],
      );
      await txn.delete('window_series', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ==================== RENK CRUD ====================

  Future<int> addColor(
    int seriesId,
    String name, {
    double unitPrice = 0.0,
  }) async {
    return await _db.insert('window_colors', {
      'series_id': seriesId,
      'name': name,
      'sort_order': 999,
      'unit_price': unitPrice,
    });
  }

  Future<void> deleteColor(int id) async {
    await _db.delete('window_colors', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== CAM SİSTEMİ ====================

  Future<List<Map<String, dynamic>>> getAllGlassSystems() async {
    return await _db.query('glass_systems', orderBy: 'name ASC');
  }

  Future<int> addGlassSystem(String name, {double unitPrice = 0.0}) async {
    return await _db.insert('glass_systems', {
      'name': name,
      'unit_price': unitPrice,
    });
  }

  Future<int> deleteGlassSystem(int id) async {
    return await _db.delete('glass_systems', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== CAM TONU ====================

  Future<List<Map<String, dynamic>>> getAllGlassTones() async {
    return await _db.query('glass_tones', orderBy: 'name ASC');
  }

  Future<int> addGlassTone(String name, {double unitPrice = 0.0}) async {
    return await _db.insert('glass_tones', {
      'name': name,
      'unit_price': unitPrice,
    });
  }

  Future<int> deleteGlassTone(int id) async {
    return await _db.delete('glass_tones', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== AKSESUARLAR ====================

  Future<List<Map<String, dynamic>>> getAllAccessories() async {
    return await _db.query('accessories', orderBy: 'name ASC');
  }

  Future<int> addAccessory(String name, {double unitPrice = 0.0}) async {
    return await _db.insert('accessories', {
      'name': name,
      'unit_price': unitPrice,
    });
  }

  Future<int> updateAccessoryPrice(int id, double unitPrice) async {
    return await _db.update(
      'accessories',
      {'unit_price': unitPrice},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAccessory(int id) async {
    return await _db.delete('accessories', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== FİYAT GÜNCELLEME (Edit) ====================

  Future<int> updateSystemPrice(int id, double unitPrice) async {
    return await _db.update(
      'window_systems',
      {'unit_price': unitPrice},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateSeriesPrice(int id, double unitPrice) async {
    return await _db.update(
      'window_series',
      {'unit_price': unitPrice},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateColorPrice(int id, double unitPrice) async {
    return await _db.update(
      'window_colors',
      {'unit_price': unitPrice},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateGlassSystemPrice(int id, double unitPrice) async {
    return await _db.update(
      'glass_systems',
      {'unit_price': unitPrice},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateGlassTonePrice(int id, double unitPrice) async {
    return await _db.update(
      'glass_tones',
      {'unit_price': unitPrice},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
