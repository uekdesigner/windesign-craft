// lib/presentation/providers/drawing_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/drawing.dart';
import '../../data/repositories/drawing_repository_impl.dart';
import '../../services/database.dart';
import '../../services/error_handler.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/result.dart';

final drawingProvider = StateNotifierProvider.autoDispose
    .family<DrawingNotifier, List<Drawing>, String>((ref, projectId) {
      return DrawingNotifier(projectId, DrawingRepositoryImpl(LocalDatabase()));
    });

class DrawingNotifier extends StateNotifier<List<Drawing>> {
  final String projectId;
  final DrawingRepositoryImpl _repository;
  final ErrorHandlerService _errorHandler = ErrorHandlerService();

  List<Drawing>? _cachedDrawings;
  bool _isInitialized = false;

  DrawingNotifier(this.projectId, this._repository) : super([]) {
    _initialize();
  }

  Future<void> _initialize() async {
    if (_cachedDrawings != null) {
      state = _cachedDrawings!;
      return;
    }

    await loadDrawings();
  }

  Future<void> loadDrawings() async {
    try {
      final result = await _repository.getDrawingsByProject(projectId);

      result.fold(
        onSuccess: (drawings) {
          state = drawings;
          _isInitialized = true;
          _cachedDrawings = drawings;
        },
        onFailure: (error) {
          _errorHandler.handleError(
            error: error,
            context: 'DrawingNotifier.loadDrawings',
            showUserMessage: true,
          );
          state = [];
        },
      );
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        error: e,
        context: 'DrawingNotifier.loadDrawings',
        stackTrace: stackTrace,
        showUserMessage: true,
      );
      state = [];
    }
  }

  Future<void> addDrawing(Drawing drawing) async {
    try {
      // 🚨 YENİ: Cache'i temizle
      _cachedDrawings = null;

      final result = await _repository.addDrawing(drawing);

      result.fold(
        onSuccess: (_) {
          _cachedDrawings = null; // 🚨 YENİ: Başarılı olunca da temizle
          loadDrawings();
        },
        onFailure: (error) {
          _errorHandler.handleError(
            error: error,
            context: 'DrawingNotifier.addDrawing',
            showUserMessage: true,
          );
        },
      );
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        error: e,
        context: 'DrawingNotifier.addDrawing',
        stackTrace: stackTrace,
        showUserMessage: true,
      );
      rethrow;
    }
  }

  Future<void> updateDrawing(Drawing drawing) async {
    try {
      final result = await _repository.updateDrawing(drawing);

      result.fold(
        onSuccess: (_) {
          loadDrawings();
        },
        onFailure: (error) {
          _errorHandler.handleError(
            error: error,
            context: 'DrawingNotifier.updateDrawing',
            showUserMessage: true,
          );
        },
      );
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        error: e,
        context: 'DrawingNotifier.updateDrawing',
        stackTrace: stackTrace,
        showUserMessage: true,
      );
      rethrow;
    }
  }

  Future<void> deleteDrawing(String drawingId) async {
    try {
      final result = await _repository.deleteDrawing(drawingId);

      result.fold(
        onSuccess: (_) {
          loadDrawings();
        },
        onFailure: (error) {
          _errorHandler.handleError(
            error: error,
            context: 'DrawingNotifier.deleteDrawing',
            showUserMessage: true,
          );
        },
      );
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        error: e,
        context: 'DrawingNotifier.deleteDrawing',
        stackTrace: stackTrace,
        showUserMessage: true,
      );
      rethrow;
    }
  }

  Future<Drawing?> getDrawingById(String drawingId) async {
    try {
      final result = await _repository.getDrawingById(drawingId);

      return result.fold(
        onSuccess: (drawing) => drawing,
        onFailure: (error) {
          _errorHandler.handleError(
            error: error,
            context: 'DrawingNotifier.getDrawingById',
            showUserMessage: false,
          );
          return null;
        },
      );
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        error: e,
        context: 'DrawingNotifier.getDrawingById',
        stackTrace: stackTrace,
        showUserMessage: false,
      );
      return null;
    }
  }

  void clearCache() {
    _cachedDrawings = null;
  }

  @override
  void dispose() {
    super.dispose();
  }
}
