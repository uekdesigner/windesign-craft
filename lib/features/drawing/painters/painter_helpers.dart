// lib/features/drawing/painters/painter_helpers.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Tüm painter sınıfları tarafından kullanılan paylaşılan çizim yardımcıları.
/// Sadece Canvas işlemleri. ShapeSpec veya state bağımlılığı yoktur.
class PainterHelpers {
  const PainterHelpers._();

  static const double fontSizeSmall = 9;

  // ── TEXT STİL YARDIMCISI ──

  static TextStyle labelStyle({
    double fontSize = fontSizeSmall,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return TextStyle(
      color: Colors.black87,
      fontSize: fontSize,
      fontWeight: fontWeight,
    );
  }

  static TextStyle labelStyleOnLine({
    double fontSize = fontSizeSmall,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return TextStyle(
      color: Colors.black87,
      fontSize: fontSize,
      fontWeight: fontWeight,
      backgroundColor: Colors.white.withValues(alpha: 0.9),
    );
  }
  // ── TEMEL ÇİZİM METODİLERİ ──

  /// Kesik çizgi (dashed path) çizer.
  static void drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dashLength,
    required double gapLength,
  }) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashLength).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashLength + gapLength;
      }
    }
  }

  /// İki nokta arasına ince leader (gösterge) çizgisi çizer.
  static void drawLeaderLine(Canvas canvas, Offset start, Offset end) {
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = Colors.black54
        ..strokeWidth = 1,
    );
  }

  /// Ölçü çizgisinin iki ucuna tik işareti çizer.
  static void drawTickMarks(
    Canvas canvas,
    double x1,
    double y1,
    double x2,
    double y2,
  ) {
    final paint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 1;

    const tickSize = 4.0;
    canvas.drawLine(
      Offset(x1 - tickSize, y1),
      Offset(x1 + tickSize, y1),
      paint,
    );
    canvas.drawLine(
      Offset(x2 - tickSize, y2),
      Offset(x2 + tickSize, y2),
      paint,
    );
  }

  /// İki nokta arasına ölçü çizgisi + tik + ortalanmış metin çizer.
  static void drawDimensionLine(
    Canvas canvas,
    Offset start,
    Offset end,
    String text, {
    required bool isVertical,
  }) {
    final paint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 1;

    canvas.drawLine(start, end, paint);

    const tickLength = 8.0;
    if (isVertical) {
      canvas.drawLine(
        Offset(start.dx - tickLength / 2, start.dy),
        Offset(start.dx + tickLength / 2, start.dy),
        paint,
      );
      canvas.drawLine(
        Offset(end.dx - tickLength / 2, end.dy),
        Offset(end.dx + tickLength / 2, end.dy),
        paint,
      );
    } else {
      canvas.drawLine(
        Offset(start.dx, start.dy - tickLength / 2),
        Offset(start.dx, start.dy + tickLength / 2),
        paint,
      );
      canvas.drawLine(
        Offset(end.dx, end.dy - tickLength / 2),
        Offset(end.dx, end.dy + tickLength / 2),
        paint,
      );
    }

    _paintCenteredText(
      canvas,
      text,
      Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2),
      rotate: isVertical ? -math.pi / 2 : 0,
      style: labelStyle(fontWeight: FontWeight.bold),
    );
  }

  /// Bir kenar üzerinde ortalanmış etiket çizer (isteğe bağlı döndürme ile).
  static void drawEdgeLabel(
    Canvas canvas,
    Offset p1,
    Offset p2,
    String text,
    bool isVertical,
  ) {
    final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
    _paintCenteredText(
      canvas,
      text,
      mid,
      rotate: isVertical ? -math.pi / 2 : 0,
      style: labelStyleOnLine(),
    );
  }

  /// Çapraz kenar üzerinde açısına göre döndürülmüş etiket çizer.
  static void drawDiagonalLabel(
    Canvas canvas,
    Offset p1,
    Offset p2,
    String text,
  ) {
    final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
    var angle = math.atan2(p2.dy - p1.dy, p2.dx - p1.dx);
    if (angle.abs() > math.pi / 2) angle += math.pi;
    _paintCenteredText(
      canvas,
      text,
      mid,
      rotate: angle,
      style: labelStyleOnLine(fontWeight: FontWeight.bold),
    );
  }

  /// Yatay/dikey çizgi üzerine ortalanmış etiket çizer.
  static void drawLineLabel(
    Canvas canvas,
    Offset position,
    String text, {
    required bool isHorizontal,
    TextStyle? style,
  }) {
    _paintCenteredText(
      canvas,
      text,
      position,
      rotate: isHorizontal ? 0 : -math.pi / 2,
      style: style,
    );
  }

  /// Dikey yazı çizer (canvas döndürülerek).
  static void drawVerticalText(Canvas canvas, double x, double y, String text) {
    _paintCenteredText(canvas, text, Offset(x, y), rotate: -math.pi / 2);
  }

  /// Yatay yazıyı sola yaslanmış çizer (sol ölçü çizgisi için).
  static void drawHorizontalText(
    Canvas canvas,
    double x,
    double y,
    String text,
  ) {
    final textPainter = _buildTextPainter(text);
    textPainter.paint(
      canvas,
      Offset(x - textPainter.width - 2, y - textPainter.height / 2),
    );
  }

  // ── ÖZEL YARDIMCI ──

  static void _paintCenteredText(
    Canvas canvas,
    String text,
    Offset center, {
    double rotate = 0,
    TextStyle? style,
  }) {
    final textPainter = _buildTextPainter(text, style: style);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (rotate != 0) canvas.rotate(rotate);
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );
    canvas.restore();
  }

  static TextPainter _buildTextPainter(String text, {TextStyle? style}) {
    return TextPainter(
      text: TextSpan(text: text, style: style ?? labelStyle()),
      textDirection: TextDirection.ltr,
    )..layout();
  }
}
