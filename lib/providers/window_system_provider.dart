import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/window_system.dart';
import '../services/window_system_service.dart';
import '../services/database_provider.dart';

final windowSystemsProvider = FutureProvider<List<WindowSystem>>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final repo = WindowSystemRepository(db);
  return repo.getAll();
});
