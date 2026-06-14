import 'dart:math' as math; // 🆕 EKLE
import 'package:flutter/material.dart';
import '../../../models/shape_spec.dart';
import '../providers/tool_mode_provider.dart';
import '../geometry/shape_crop_geometry.dart'; // 🆕 EKLE

class TriangleTool {
  const TriangleTool._();

  static TriangleDirection directionFromTool(ToolMode tool) {
    switch (tool) {
      case ToolMode.triangleUp:
        return TriangleDirection.up;
      case ToolMode.triangleLeft:
        return TriangleDirection.left;
      case ToolMode.triangleRight:
        return TriangleDirection.right;
      default:
        throw ArgumentError('Üçgen tool değil: $tool');
    }
  }

  static InternalElement createForMainPanel(
    Map<String, double> panel,
    TriangleDirection direction,
    ShapeSpec spec,
  ) {
    final left = panel['leftX']!;
    final right = panel['rightX']!;
    final top = panel['topY']!;
    final bottom = panel['bottomY']!;

    final width = right - left;
    final height = top - bottom;

    if (width <= 0 || height <= 0) {
      throw ArgumentError('Geçersiz panel boyutu: w=$width h=$height');
    }

    return InternalElement(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: InternalElementType.triangle,
      position: Offset(left, top),
      size: Size(width, height),
      rotation: 0,
      properties: {'direction': direction.name},
    );
  }

  static InternalElement createForSidePanel(
    SideAttachment attach,
    TriangleDirection direction,
  ) {
    return InternalElement(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: InternalElementType.triangle,
      position: const Offset(0, 0),
      size: Size(attach.width, attach.height),
      rotation: 0,
      properties: {'direction': direction.name},
    );
  }
}
