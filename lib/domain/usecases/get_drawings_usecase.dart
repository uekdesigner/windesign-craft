// lib/domain/usecases/get_drawings_usecase.dart
import '../repositories/drawing_repository.dart';
import '../../models/drawing.dart';
import '../../core/utils/result.dart';
import '../../core/errors/app_exceptions.dart';

class GetDrawingsUseCase {
  final DrawingRepository repository;

  GetDrawingsUseCase(this.repository);

  Future<Result<List<Drawing>, DatabaseException>> call(
    String projectId,
  ) async {
    return await repository.getDrawingsByProject(projectId);
  }
}
