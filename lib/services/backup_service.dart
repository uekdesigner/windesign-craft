import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../services/database.dart';

class BackupService {
  final LocalDatabase _db = LocalDatabase();

  /// Tüm veritabanını JSON'a çevirir ve paylaşma ekranını açar.
  Future<void> exportBackup() async {
    final db = await _db.database;

    // Tüm tabloları oku
    final projects = await db.query('projects');
    final drawings = await db.query('drawings');
    final payments = await db.query('payments');
    final windowSystems = await db.query('window_systems');
    final windowSeries = await db.query('window_series');
    final windowColors = await db.query('window_colors');
    final glassSystems = await db.query('glass_systems');
    final glassTones = await db.query('glass_tones');
    final accessories = await db.query('accessories');

    final backup = {
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'projects': projects,
      'drawings': drawings,
      'payments': payments,
      'window_systems': windowSystems,
      'window_series': windowSeries,
      'window_colors': windowColors,
      'glass_systems': glassSystems,
      'glass_tones': glassTones,
      'accessories': accessories,
    };

    final json = const JsonEncoder.withIndent('  ').convert(backup);

    // Geçici dosyaya kaydet
    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final fileName =
        'windesign_yedek_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.json';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(json);

    // Paylaşma ekranını aç
    await Share.shareXFiles([
      XFile(file.path, mimeType: 'application/json'),
    ], subject: 'WinDesign Craft Yedek - $fileName');
  }

  /// JSON dosyasını seçip veritabanına geri yükler.
  /// Döner: (başarılı mı, mesaj)
  Future<(bool, String)> importBackup() async {
    // Dosya seç
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.isEmpty) {
      return (false, 'Dosya seçilmedi.');
    }

    final path = result.files.first.path;
    if (path == null) return (false, 'Dosya yolu alınamadı.');

    final file = File(path);
    final content = await file.readAsString();

    late Map<String, dynamic> backup;
    try {
      backup = jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return (false, 'Geçersiz yedek dosyası.');
    }

    // Versiyon kontrolü
    final version = backup['version'] as int? ?? 1;
    if (version > 2) {
      return (false, 'Bu yedek dosyası daha yeni bir sürüme ait.');
    }

    final db = await _db.database;

    await db.transaction((txn) async {
      // Projeleri geri yükle
      final projects = backup['projects'] as List<dynamic>? ?? [];
      for (final p in projects) {
        await txn.insert(
          'projects',
          Map<String, dynamic>.from(p as Map),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Çizimleri geri yükle
      final drawings = backup['drawings'] as List<dynamic>? ?? [];
      for (final d in drawings) {
        await txn.insert(
          'drawings',
          Map<String, dynamic>.from(d as Map),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Ödemeleri geri yükle
      final payments = backup['payments'] as List<dynamic>? ?? [];
      for (final p in payments) {
        await txn.insert(
          'payments',
          Map<String, dynamic>.from(p as Map),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Pencere sistemlerini geri yükle
      final systems = backup['window_systems'] as List<dynamic>? ?? [];
      for (final s in systems) {
        await txn.insert(
          'window_systems',
          Map<String, dynamic>.from(s as Map),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      final series = backup['window_series'] as List<dynamic>? ?? [];
      for (final s in series) {
        await txn.insert(
          'window_series',
          Map<String, dynamic>.from(s as Map),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      final colors = backup['window_colors'] as List<dynamic>? ?? [];
      for (final c in colors) {
        await txn.insert(
          'window_colors',
          Map<String, dynamic>.from(c as Map),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Cam sistemleri
      final glassSystems = backup['glass_systems'] as List<dynamic>? ?? [];
      for (final g in glassSystems) {
        await txn.insert(
          'glass_systems',
          Map<String, dynamic>.from(g as Map),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      final glassTones = backup['glass_tones'] as List<dynamic>? ?? [];
      for (final g in glassTones) {
        await txn.insert(
          'glass_tones',
          Map<String, dynamic>.from(g as Map),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      final accessories = backup['accessories'] as List<dynamic>? ?? [];
      for (final a in accessories) {
        await txn.insert(
          'accessories',
          Map<String, dynamic>.from(a as Map),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });

    final projectCount = (backup['projects'] as List?)?.length ?? 0;
    final drawingCount = (backup['drawings'] as List?)?.length ?? 0;

    return (
      true,
      '$projectCount proje ve $drawingCount çizim başarıyla geri yüklendi.',
    );
  }
}
