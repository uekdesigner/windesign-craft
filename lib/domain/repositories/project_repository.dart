// lib/domain/repositories/project_repository.dart
import '../../models/project.dart';
import '../../core/utils/result.dart';
import '../../core/errors/app_exceptions.dart';

abstract class ProjectRepository {
  Future<Result<void, DatabaseException>> addProject(Project project);
  Future<Result<void, DatabaseException>> updateProject(Project project);
  Future<Result<void, DatabaseException>> deleteProject(String projectId);
  Future<Result<List<Project>, DatabaseException>> getProjects();
  Future<Result<Project?, DatabaseException>> getProjectById(String projectId);
}
