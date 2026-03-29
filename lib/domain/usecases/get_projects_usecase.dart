// lib/domain/usecases/get_projects_usecase.dart
import '../repositories/project_repository.dart';
import '../../models/project.dart';
import '../../core/utils/result.dart';
import '../../core/errors/app_exceptions.dart';

class GetProjectsUseCase {
  final ProjectRepository repository;

  GetProjectsUseCase(this.repository);

  Future<Result<List<Project>, DatabaseException>> call() async {
    return await repository.getProjects();
  }
}
