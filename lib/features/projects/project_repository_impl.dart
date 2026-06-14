import 'project_repository.dart';
import '../../models/project.dart';
import '../../services/database.dart';
import '../../services/error_handler.dart';
import '../../services/app_exceptions.dart';
import '../../services/result.dart';

class ProjectRepositoryImpl implements ProjectRepository {
  final LocalDatabase database;
  final ErrorHandlerService errorHandler = ErrorHandlerService();

  ProjectRepositoryImpl(this.database);

  @override
  Future<Result<void, DatabaseException>> addProject(Project project) async {
    try {
      await database.insertProject(project.toMap());
      return Result.success(null);
    } catch (e, stackTrace) {
      final error = DatabaseException(
        'Proje eklenirken hata: ${e.toString()}',
        stackTrace,
      );

      errorHandler.handleError(
        error: error,
        context: 'ProjectRepository.addProject',
        stackTrace: stackTrace,
        showUserMessage: true,
      );

      return Result.failure(error);
    }
  }

  @override
  Future<Result<List<Project>, DatabaseException>> getProjects() async {
    try {
      final projectsMap = await database.getProjects();
      final projects = projectsMap.map((map) => Project.fromMap(map)).toList();
      return Result.success(projects);
    } catch (e, stackTrace) {
      final error = DatabaseException(
        'Projeler yüklenirken hata: ${e.toString()}',
        stackTrace,
      );

      errorHandler.handleError(
        error: error,
        context: 'ProjectRepository.getProjects',
        stackTrace: stackTrace,
        showUserMessage: true,
      );

      return Result.failure(error);
    }
  }

  @override
  Future<Result<void, DatabaseException>> deleteProject(
    String projectId,
  ) async {
    try {
      await database.deleteProject(projectId);
      return Result.success(null);
    } catch (e, stackTrace) {
      final error = DatabaseException(
        'Proje silinirken hata: ${e.toString()}',
        stackTrace,
      );

      errorHandler.handleError(
        error: error,
        context: 'ProjectRepository.deleteProject',
        stackTrace: stackTrace,
        showUserMessage: true,
      );

      return Result.failure(error);
    }
  }

  @override
  Future<Result<void, DatabaseException>> updateProject(Project project) async {
    try {
      // Önce projenin var olup olmadığını kontrol et
      final existingProject = await database.getProjectById(project.id);
      if (existingProject == null) {
        throw DatabaseNotFoundException('Proje bulunamadı: ${project.id}');
      }

      // Projeyi güncelle
      final result = await database.updateProject(project.toMap());

      if (result == 0) {
        throw DatabaseException('Proje güncellenemedi: ${project.id}');
      }

      return Result.success(null);
    } on DatabaseNotFoundException catch (e, stackTrace) {
      errorHandler.handleError(
        error: e,
        context: 'ProjectRepository.updateProject',
        stackTrace: stackTrace,
        showUserMessage: true,
      );
      return Result.failure(DatabaseException(e.message, stackTrace));
    } catch (e, stackTrace) {
      final error = DatabaseException(
        'Proje güncellenirken hata: ${e.toString()}',
        stackTrace,
      );

      errorHandler.handleError(
        error: error,
        context: 'ProjectRepository.updateProject',
        stackTrace: stackTrace,
        showUserMessage: true,
      );

      return Result.failure(error);
    }
  }

  @override
  Future<Result<Project?, DatabaseException>> getProjectById(
    String projectId,
  ) async {
    try {
      final projectMap = await database.getProjectById(projectId);
      if (projectMap != null) {
        return Result.success(Project.fromMap(projectMap));
      }
      return Result.success(null);
    } catch (e, stackTrace) {
      final error = DatabaseException(
        'Proje getirme hatası: ${e.toString()}',
        stackTrace,
      );

      errorHandler.handleError(
        error: error,
        context: 'ProjectRepository.getProjectById',
        stackTrace: stackTrace,
        showUserMessage: false,
      );

      return Result.failure(error);
    }
  }
}
