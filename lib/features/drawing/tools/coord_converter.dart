import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/shape_spec.dart';

class CoordConverter {
  final TransformationController transformationController;
  final double canvasScale;
  final Offset canvasOffset;

  CoordConverter({
    required this.transformationController,
    required this.canvasScale,
    required this.canvasOffset,
  });

  /// Screen (pixel) koordinatını MM koordinatına çevirir.
  Offset screenToMm(Offset screenPos, ShapeSpec spec) {
    final matrix = transformationController.value;

    if (!matrix.isIdentity()) {
      final inverse = Matrix4.inverted(matrix);
      screenPos = MatrixUtils.transformPoint(inverse, screenPos);
    }

    final scale = canvasScale;
    final offset = canvasOffset;

    final bounds = spec.boundingSize;
    final xShift = (spec.baseWidth - bounds.width) / 2;
    final yShift = (spec.baseHeight - bounds.height) / 2;

    // Sol panel offseti
    double leftExtra = 0;
    for (final attach in spec.sideAttachments) {
      if (attach.side == 'left') {
        leftExtra = math.max(leftExtra, attach.width);
      }
    }

    final mmX = ((screenPos.dx - offset.dx) / scale) + xShift - leftExtra;
    final mmY =
        spec.baseHeight - (((screenPos.dy - offset.dy) / scale) + yShift);

    return Offset(mmX, mmY);
  }
}
