// lib/domain/usecases/delete_project_usecase.dart
import '../repositories/project_repository.dart';
import '../../core/utils/result.dart';
import '../../core/errors/app_exceptions.dart';

class DeleteProjectUseCase {
  final ProjectRepository repository;

  DeleteProjectUseCase(this.repository);

  Future<Result<void, DatabaseException>> call(String projectId) async {
    return await repository.deleteProject(projectId);
  }
}
