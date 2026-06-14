import '../../models/project.dart';
import '../../services/result.dart';
import '../../services/app_exceptions.dart';

abstract class ProjectRepository {
  Future<Result<void, DatabaseException>> addProject(Project project);
  Future<Result<void, DatabaseException>> updateProject(Project project);
  Future<Result<void, DatabaseException>> deleteProject(String projectId);
  Future<Result<List<Project>, DatabaseException>> getProjects();
  Future<Result<Project?, DatabaseException>> getProjectById(String projectId);
}
