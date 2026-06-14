import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tool_mode_provider.dart';

/// Kısa (short-span) yatay/dikey çizgilerin sürükle-bırak onPanEnd mantığı.
/// Preview güncelleme canvas'taki mevcut metodlarda kalır.
class ShortLineDragTool {
  final WidgetRef ref;
  final BuildContext context;

  ShortLineDragTool({required this.ref, required this.context});

  void onHorizontalPanEnd(
    double? previewMmY,
    Offset? lastMmPos,
    void Function(Offset mmPos) addShortHorizontalLineAtMm,
    VoidCallback clearPreview,
  ) {
    if (previewMmY != null && lastMmPos != null) {
      addShortHorizontalLineAtMm(lastMmPos);
      ref.read(toolModeProvider.notifier).reset();
      clearPreview();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kısa yatay çizgi eklendi'),
          duration: Duration(milliseconds: 500),
        ),
      );
    } else {
      clearPreview();
    }
  }

  void onVerticalPanEnd(
    double? previewMmX,
    Offset? lastMmPos,
    void Function(Offset mmPos) addShortVerticalLineAtMm,
    VoidCallback clearPreview,
  ) {
    if (previewMmX != null && lastMmPos != null) {
      addShortVerticalLineAtMm(lastMmPos);
      ref.read(toolModeProvider.notifier).reset();
      clearPreview();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kısa dikey çizgi eklendi'),
          duration: Duration(milliseconds: 500),
        ),
      );
    } else {
      clearPreview();
    }
  }
}
