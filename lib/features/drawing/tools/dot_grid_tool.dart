import 'package:flutter/material.dart';
import '../../../models/shape_spec.dart';

class DotGridTool {
  const DotGridTool._();

  static InternalElement createForPanel(Map<String, double> panel) {
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
      type: InternalElementType.dotGrid,
      position: Offset(left, top),
      size: Size(width, height),
      rotation: 0,
      properties: {},
    );
  }

  /// Aynı panelde zaten dotGrid var mı?
  static bool alreadyExists(ShapeSpec spec, Map<String, double> panel) {
    final left = panel['leftX']!;
    final top = panel['topY']!;
    final width = panel['rightX']! - left;
    final height = top - panel['bottomY']!;

    return spec.internalElements.any(
      (e) =>
          e.type == InternalElementType.dotGrid &&
          e.position.dx == left &&
          e.position.dy == top &&
          e.size.width == width &&
          e.size.height == height,
    );
  }
}
