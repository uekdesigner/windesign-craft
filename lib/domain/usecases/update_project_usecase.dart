// lib/domain/usecases/update_project_usecase.dart
import '../repositories/project_repository.dart';
import '../../models/project.dart';
import '../../core/utils/result.dart';
import '../../core/errors/app_exceptions.dart';

class UpdateProjectUseCase {
  final ProjectRepository repository;

  UpdateProjectUseCase(this.repository);

  Future<Result<void, DatabaseException>> call(Project project) async {
    return await repository.updateProject(project);
  }
}
