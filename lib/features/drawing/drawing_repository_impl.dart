import 'drawing_repository.dart';
import '../../models/drawing.dart';
import '../../services/database.dart';
import '../../services/error_handler.dart';
import '../../services/app_exceptions.dart';
import '../../services/result.dart';

class DrawingRepositoryImpl implements DrawingRepository {
  final LocalDatabase _database;
  final ErrorHandlerService _errorHandler = ErrorHandlerService();

  DrawingRepositoryImpl(this._database);

  @override
  Future<Result<void, DatabaseException>> addDrawing(Drawing drawing) async {
    try {
      await _database.insertDrawingWithTransaction(drawing.toMap());
      return Result.success(null);
    } catch (e, stackTrace) {
      final error = DatabaseException(
        'Çizim eklenirken hata: ${e.toString()}',
        stackTrace,
      );

      _errorHandler.handleError(
        error: error,
        context: 'DrawingRepository.addDrawing',
        stackTrace: stackTrace,
        showUserMessage: true,
      );

      return Result.failure(error);
    }
  }

  @override
  Future<Result<List<Drawing>, DatabaseException>> getDrawingsByProject(
    String projectId,
  ) async {
    try {
      final drawingsMap = await _database.getDrawingsByProject(projectId);
      final drawings = drawingsMap.map((map) => Drawing.fromMap(map)).toList();

      return Result.success(drawings);
    } catch (e, stackTrace) {
      final error = DatabaseException(
        'Çizimler yüklenirken hata: ${e.toString()}',
        stackTrace,
      );

      _errorHandler.handleError(
        error: error,
        context: 'DrawingRepository.getDrawingsByProject',
        stackTrace: stackTrace,
        showUserMessage: true,
      );

      return Result.failure(error);
    }
  }

  @override
  Future<Result<void, DatabaseException>> updateDrawing(Drawing drawing) async {
    try {
      // 🚨 GÜNCELLENDİ: updated_at otomatik güncelle
      final updatedDrawing = drawing.copyWith(
        updatedAt: DateTime.now().toIso8601String(),
      );

      await _database.updateDrawing(updatedDrawing.toMap());
      return Result.success(null);
    } catch (e, stackTrace) {
      final error = DatabaseException(
        'Çizim güncellenirken hata: ${e.toString()}',
        stackTrace,
      );

      _errorHandler.handleError(
        error: error,
        context: 'DrawingRepository.updateDrawing',
        stackTrace: stackTrace,
        showUserMessage: true,
      );

      return Result.failure(error);
    }
  }

  @override
  Future<Result<void, DatabaseException>> deleteDrawing(
    String drawingId,
  ) async {
    try {
      await _database.deleteDrawing(drawingId);
      return Result.success(null);
    } catch (e, stackTrace) {
      final error = DatabaseException(
        'Çizim silinirken hata: ${e.toString()}',
        stackTrace,
      );

      _errorHandler.handleError(
        error: error,
        context: 'DrawingRepository.deleteDrawing',
        stackTrace: stackTrace,
        showUserMessage: true,
      );

      return Result.failure(error);
    }
  }

  @override
  Future<Result<Drawing?, DatabaseException>> getDrawingById(
    String drawingId,
  ) async {
    try {
      final drawingMap = await _database.getDrawingById(drawingId);

      if (drawingMap == null || drawingMap.isEmpty) {
        return Result.success(null);
      }

      final drawing = Drawing.fromMap(drawingMap);

      return Result.success(drawing);
    } catch (e, stackTrace) {
      final error = DatabaseException(
        'Çizim getirme hatası: ${e.toString()}',
        stackTrace,
      );

      _errorHandler.handleError(
        error: error,
        context: 'DrawingRepository.getDrawingById',
        stackTrace: stackTrace,
        showUserMessage: false,
      );

      return Result.failure(error);
    }
  }

  // 🚨 YENİ: Çizim sayısını getir
  Future<Result<int, DatabaseException>> getDrawingCount(
    String projectId,
  ) async {
    try {
      final count = await _database.getDrawingCount(projectId);
      return Result.success(count);
    } catch (e, stackTrace) {
      final error = DatabaseException(
        'Çizim sayısı alınırken hata: ${e.toString()}',
        stackTrace,
      );

      _errorHandler.handleError(
        error: error,
        context: 'DrawingRepository.getDrawingCount',
        stackTrace: stackTrace,
        showUserMessage: false,
      );

      return Result.failure(error);
    }
  }

  // 🚨 YENİ: Son çizimleri getir
  Future<Result<List<Drawing>, DatabaseException>> getRecentDrawings({
    int limit = 10,
  }) async {
    try {
      final drawingsMap = await _database.getRecentDrawings(limit: limit);
      final drawings = drawingsMap.map((map) => Drawing.fromMap(map)).toList();

      return Result.success(drawings);
    } catch (e, stackTrace) {
      final error = DatabaseException(
        'Son çizimler yüklenirken hata: ${e.toString()}',
        stackTrace,
      );

      _errorHandler.handleError(
        error: error,
        context: 'DrawingRepository.getRecentDrawings',
        stackTrace: stackTrace,
        showUserMessage: false,
      );

      return Result.failure(error);
    }
  }
}
