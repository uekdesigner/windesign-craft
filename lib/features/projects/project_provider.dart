import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/project.dart';
import 'project_repository_impl.dart';
import '../../services/database.dart';
import '../../services/error_handler.dart';
import '../../services/license_service.dart';

// 🚨 DEĞİŞTİ: StateNotifierProvider -> AsyncNotifierProvider (daha güvenli)
final projectProvider = AsyncNotifierProvider<ProjectNotifier, List<Project>>(
  () => ProjectNotifier(ProjectRepositoryImpl(LocalDatabase())),
);

class ProjectNotifier extends AsyncNotifier<List<Project>> {
  final ProjectRepositoryImpl _repository;
  final ErrorHandlerService _errorHandler = ErrorHandlerService();

  ProjectNotifier(this._repository);

  @override
  Future<List<Project>> build() async {
    // 🚨 YENİ: Her build'de veritabanından çek
    return await _loadFromDatabase();
  }

  Future<List<Project>> _loadFromDatabase() async {
    try {
      final result = await _repository.getProjects();

      return result.fold(
        onSuccess: (projects) => projects,
        onFailure: (error) {
          _errorHandler.handleError(
            error: error,
            context: 'ProjectNotifier._loadFromDatabase',
            showUserMessage: true,
          );
          throw error;
        },
      );
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        error: e,
        context: 'ProjectNotifier._loadFromDatabase',
        stackTrace: stackTrace,
        showUserMessage: true,
      );
      rethrow;
    }
  }

  // 🚨 YENİ: Manuel yenileme
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadFromDatabase());
  }

  Future<void> addProject(Project project) async {
    try {
      await LicenseService().requestCreateProject();
      final result = await _repository.addProject(project);

      result.fold(
        onSuccess: (_) async {
          // 🚨 KRİTİK: Başarılı olunca hemen yenile
          await refresh();
        },
        onFailure: (error) {
          _errorHandler.handleError(
            error: error,
            context: 'ProjectNotifier.addProject',
            showUserMessage: true,
          );
          throw error;
        },
      );
    } catch (e) {
      if (e is LicenseDeniedException || e is LicenseOfflineException) {
        rethrow;
      }
      _errorHandler.handleError(
        error: e,
        context: 'ProjectNotifier.addProject',
        showUserMessage: true,
      );
      rethrow;
    }
  }

  Future<void> deleteProject(String projectId) async {
    try {
      final result = await _repository.deleteProject(projectId);

      result.fold(
        onSuccess: (_) async {
          await refresh();
        },
        onFailure: (error) {
          _errorHandler.handleError(
            error: error,
            context: 'ProjectNotifier.deleteProject',
            showUserMessage: true,
          );
          throw error;
        },
      );
    } catch (e) {
      _errorHandler.handleError(
        error: e,
        context: 'ProjectNotifier.deleteProject',
        showUserMessage: true,
      );
      rethrow;
    }
  }

  Future<void> updateProject(Project project) async {
    try {
      final result = await _repository.updateProject(project);

      result.fold(
        onSuccess: (_) async {
          await refresh();
        },
        onFailure: (error) {
          _errorHandler.handleError(
            error: error,
            context: 'ProjectNotifier.updateProject',
            showUserMessage: true,
          );
          throw error;
        },
      );
    } catch (e) {
      _errorHandler.handleError(
        error: e,
        context: 'ProjectNotifier.updateProject',
        showUserMessage: true,
      );
      rethrow;
    }
  }

  Future<Project?> getProjectById(String projectId) async {
    try {
      final result = await _repository.getProjectById(projectId);

      return result.fold(
        onSuccess: (project) => project,
        onFailure: (error) {
          _errorHandler.handleError(
            error: error,
            context: 'ProjectNotifier.getProjectById',
            showUserMessage: false,
          );
          return null;
        },
      );
    } catch (e) {
      _errorHandler.handleError(
        error: e,
        context: 'ProjectNotifier.getProjectById',
        showUserMessage: false,
      );
      return null;
    }
  }
}
