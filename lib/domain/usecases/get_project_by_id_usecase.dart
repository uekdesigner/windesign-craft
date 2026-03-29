// lib/domain/usecases/get_project_by_id_usecase.dart
import '../repositories/project_repository.dart';
import '../../models/project.dart';
import '../../core/utils/result.dart';
import '../../core/errors/app_exceptions.dart';

class GetProjectByIdUseCase {
  final ProjectRepository repository;

  GetProjectByIdUseCase(this.repository);

  Future<Result<Project?, DatabaseException>> call(String projectId) async {
    return await repository.getProjectById(projectId);
  }
}
