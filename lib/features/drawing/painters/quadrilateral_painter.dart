import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/shape_spec.dart';

class ShapePainter extends CustomPainter {
  final ShapeSpec spec;
  final Color? overrideStrokeColor;
  final double? overrideStrokeWidth;

  const ShapePainter(
    this.spec, {
    this.overrideStrokeColor,
    this.overrideStrokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = _calculateScale(size);
    final offset = _calculateCenterOffset(size, scale);
    final pointsMm = spec.getPolygonPoints();
    final pointsPx = pointsMm.map((p) => _mmToPx(p, scale, offset)).toList();

    if (pointsPx.length < 4) return;

    final path = Path();

    // 🛡️ GÜVENLİ: Hem 4 hem 8 nokta destekler
    if (pointsPx.length >= 8) {
      // Yeni sistem (8 nokta - X/Y ayrı)
      path.moveTo(pointsPx[0].dx, pointsPx[0].dy);
      path.lineTo(pointsPx[1].dx, pointsPx[1].dy);
      path.lineTo(pointsPx[7].dx, pointsPx[7].dy);
      path.lineTo(pointsPx[6].dx, pointsPx[6].dy);
      path.lineTo(pointsPx[5].dx, pointsPx[5].dy);
      path.lineTo(pointsPx[4].dx, pointsPx[4].dy);
      path.lineTo(pointsPx[3].dx, pointsPx[3].dy);
      path.lineTo(pointsPx[2].dx, pointsPx[2].dy);
    } else {
      // Eski sistem (4 nokta)
      path.moveTo(pointsPx[0].dx, pointsPx[0].dy);
      for (int i = 1; i < pointsPx.length; i++) {
        path.lineTo(pointsPx[i].dx, pointsPx[i].dy);
      }
    }
    path.close();

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // 4. Ana hatları çiz
    final strokePaint = Paint()
      ..color = overrideStrokeColor ?? spec.strokeColor
      ..strokeWidth = overrideStrokeWidth ?? spec.strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, strokePaint);

    // 5. Base dikdörtgeni (gri, noktalı - referans için)
    _drawBaseRectangle(canvas, size, scale, offset);

    // 6. İç çizgileri çiz (varsa)
    _drawInternalElements(canvas, scale, offset);

    // 7. Ölçüleri yaz
    if (spec.showDimensions) {
      _drawDimensions(canvas, pointsPx);
    }
  }

  /// MM'den Pixel'a dönüşüm
  double _calculateScale(Size canvasSize) {
    final bounds = spec.boundingSize;
    const padding = 0.9;
    final scaleX = (canvasSize.width * padding) / bounds.width;
    final scaleY = (canvasSize.height * padding) / bounds.height;
    return math.min(scaleX, scaleY);
  }

  Offset _calculateCenterOffset(Size canvasSize, double scale) {
    final bounds = spec.boundingSize;
    final scaledW = bounds.width * scale;
    final scaledH = bounds.height * scale;
    return Offset(
      (canvasSize.width - scaledW) / 2,
      (canvasSize.height - scaledH) / 2,
    );
  }

  Offset _mmToPx(Offset mm, double scale, Offset offset) {
    // Flutter'da Y=0 üstte, bizim modelde Y=0 altta
    return Offset(
      mm.dx * scale + offset.dx,
      (spec.baseHeight - mm.dy) * scale + offset.dy,
    );
  }

  void _drawBaseRectangle(
    Canvas canvas,
    Size size,
    double scale,
    Offset offset,
  ) {
    final baseRect = Rect.fromLTWH(
      offset.dx,
      offset.dy,
      spec.baseWidth * scale,
      spec.baseHeight * scale,
    );

    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawRect(baseRect, paint);
  }

  void _drawInternalElements(Canvas canvas, double scale, Offset offset) {
    final paint = Paint()
      ..color = Colors.red.shade400
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final element in spec.internalElements) {
      final start = _mmToPx(element.position, scale, offset);

      switch (element.type) {
        case InternalElementType.verticalLine:
          canvas.drawLine(
            start,
            Offset(start.dx, start.dy + element.size.height * scale),
            paint,
          );
          break;
        case InternalElementType.horizontalLine:
          canvas.drawLine(
            start,
            Offset(start.dx + element.size.width * scale, start.dy),
            paint,
          );
          break;
        case InternalElementType.triangle:
          final path = Path()
            ..moveTo(start.dx, start.dy)
            ..lineTo(start.dx + element.size.width * scale, start.dy)
            ..lineTo(
              start.dx + element.size.width * scale / 2,
              start.dy + element.size.height * scale,
            )
            ..close();
          canvas.drawPath(path, paint);
          break;
        case InternalElementType.parallelLines:
          final spacing = 5.0;
          canvas.drawLine(
            start,
            Offset(start.dx + element.size.width * scale, start.dy),
            paint,
          );
          canvas.drawLine(
            Offset(start.dx, start.dy + spacing),
            Offset(start.dx + element.size.width * scale, start.dy + spacing),
            paint,
          );
          break;
      }
    }
  }

  void _drawDimensions(Canvas canvas, List<Offset> pointsPx) {
    if (pointsPx.length < 8) return;

    // Kenarları ve ölçüleri çiz
    _drawEdgeLabel(
      canvas,
      pointsPx[0],
      pointsPx[2],
      spec.baseWidth.toInt().toString(),
    ); // Üst
    _drawEdgeLabel(
      canvas,
      pointsPx[1],
      pointsPx[7],
      spec.baseHeight.toInt().toString(),
    ); // Sol
    _drawEdgeLabel(
      canvas,
      pointsPx[6],
      pointsPx[5],
      spec.baseWidth.toInt().toString(),
    ); // Alt
    _drawEdgeLabel(
      canvas,
      pointsPx[3],
      pointsPx[4],
      spec.baseHeight.toInt().toString(),
    ); // Sağ
  }

  void _drawEdgeLabel(Canvas canvas, Offset p1, Offset p2, String text) {
    final midPoint = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);

    canvas.save();
    canvas.translate(midPoint.dx, midPoint.dy);

    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: Colors.black87,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        backgroundColor: Colors.white.withOpacity(0.9),
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ShapePainter oldDelegate) {
    return oldDelegate.spec != spec ||
        oldDelegate.overrideStrokeColor != overrideStrokeColor ||
        oldDelegate.overrideStrokeWidth != overrideStrokeWidth;
  }
}
