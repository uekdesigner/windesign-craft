import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppErrorWidget extends ConsumerWidget {
  final String message;
  final VoidCallback? onRetry;
  final String? retryText;

  const AppErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.retryText = 'Tekrar Dene',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Hata Oluştu',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// 🚨 YENİ: Error Boundary Widget
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error, StackTrace stackTrace)? fallback;

  const ErrorBoundary({super.key, required this.child, this.fallback});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.fallback?.call(_error!, _stackTrace!) ??
          AppErrorWidget(
            message: 'Beklenmeyen bir hata oluştu.',
            onRetry: () => setState(() {
              _error = null;
              _stackTrace = null;
            }),
          );
    }

    return widget.child;
  }

  @override
  void initState() {
    super.initState();
    // Hata sınırı için error listener
  }
}
