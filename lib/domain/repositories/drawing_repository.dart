// lib/domain/repositories/drawing_repository.dart
import '../../models/drawing.dart';
import '../../core/utils/result.dart';
import '../../core/errors/app_exceptions.dart';

abstract class DrawingRepository {
  Future<Result<void, DatabaseException>> addDrawing(Drawing drawing);
  Future<Result<void, DatabaseException>> updateDrawing(Drawing drawing);
  Future<Result<void, DatabaseException>> deleteDrawing(String drawingId);
  Future<Result<List<Drawing>, DatabaseException>> getDrawingsByProject(
    String projectId,
  );
  Future<Result<Drawing?, DatabaseException>> getDrawingById(String drawingId);
}
