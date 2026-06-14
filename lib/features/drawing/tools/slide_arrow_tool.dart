import 'package:flutter/material.dart';
import '../../../models/shape_spec.dart';

class SlideArrowTool {
  const SlideArrowTool._();

  static InternalElement createForPanel(
    Map<String, double> panel,
    String direction, // 'right' | 'left'
  ) {
    final left = panel['leftX']!;
    final right = panel['rightX']!;
    final top = panel['topY']!;
    final bottom = panel['bottomY']!;

    final width = right - left;
    final height = top - bottom;

    if (width <= 0 || height <= 0) {
      throw ArgumentError('Geçersiz panel: w=$width h=$height');
    }

    return InternalElement(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: InternalElementType.slideArrow,
      position: Offset(left, top),
      size: Size(width, height),
      rotation: 0,
      properties: {'direction': direction},
    );
  }

  /// Aynı panelde (position+size) aynı yönde ok var mı?
  static bool sameDirectionExists(
    ShapeSpec spec,
    Offset position,
    Size size,
    String direction,
  ) {
    return spec.internalElements.any(
      (e) =>
          e.type == InternalElementType.slideArrow &&
          e.position.dx == position.dx &&
          e.position.dy == position.dy &&
          e.size.width == size.width &&
          e.size.height == size.height &&
          (e.properties['direction'] as String? ?? 'right') == direction,
    );
  }
}
