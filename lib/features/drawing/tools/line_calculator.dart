import 'package:flutter/material.dart';
import '../../../models/shape_spec.dart';
import '../geometry/shape_crop_geometry.dart';

/// Uzun (full-span) yatay ve dikey çizgilerin yeni pozisyon/genişlik/yükseklik hesabı.
/// Sadece matematik. State'e dokunmaz, yeni InternalElement döner.
class LineCalculator {
  const LineCalculator._();

  /// Uzun yatay çizgi Y değiştiğinde: crop sınırlarına göre yeni genişlik ve pozisyon.
  static InternalElement? calculateHorizontalUpdate(
    ShapeSpec spec,
    InternalElement oldElement,
    double newY,
  ) {
    final newXLeft = ShapeCropGeometry.leftXAtY(spec, newY);
    final newXRight = ShapeCropGeometry.rightXAtY(spec, newY);
    final newWidth = newXRight - newXLeft;

    if (newWidth < 10) return null;

    return InternalElement(
      id: oldElement.id,
      type: oldElement.type,
      position: Offset(newXLeft, newY),
      size: Size(newWidth, oldElement.size.height),
      rotation: oldElement.rotation,
      properties: oldElement.properties,
    );
  }

  /// Uzun dikey çizgi X değiştiğinde: crop sınırlarına göre yeni yükseklik ve pozisyon.
  static InternalElement? calculateVerticalUpdate(
    ShapeSpec spec,
    InternalElement oldElement,
    double newX,
  ) {
    final newYTop = ShapeCropGeometry.topYAtX(spec, newX);
    final newYBottom = ShapeCropGeometry.bottomYAtX(spec, newX);
    final newHeight = newYTop - newYBottom;

    if (newHeight < 10) return null;

    return InternalElement(
      id: oldElement.id,
      type: oldElement.type,
      position: Offset(newX, newYTop),
      size: Size(oldElement.size.width, newHeight),
      rotation: oldElement.rotation,
      properties: oldElement.properties,
    );
  }
}
