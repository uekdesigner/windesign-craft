import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../services/database.dart';

final databaseProvider = FutureProvider<Database>((ref) async {
  return await LocalDatabase().database;
});
