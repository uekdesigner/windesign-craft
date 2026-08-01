// lib/features/drawing/painters/quadrilateral_painter.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/shape_spec.dart';
import '../geometry/shape_crop_geometry.dart';
import 'painter_helpers.dart';
import 'shape_dimension_painter.dart';
import 'shape_element_painter.dart';

export 'shape_dimension_painter.dart' show MmToPx;

class ShapePainter extends CustomPainter {
  final ShapeSpec spec;
  final Color? overrideStrokeColor;
  final double? overrideStrokeWidth;
  final String? selectedElementId;
  final bool showInternalElements;
  final double? previewHorizontalLineY;
  final double? previewVerticalLineX;
  final double? previewShortHorizontalLineY;
  final double? previewShortVerticalLineX;
  final List<SideAttachment> sideAttachments;

  // ── Yan panel drag önizlemesi (gölge) ──
  // sidePreviewSide: hangi panel ('left' | 'right')
  // sidePreviewLocalY: yatay çizgi için panel-yerel Y (0 = alt)
  // sidePreviewLocalX: dikey çizgi için panel-yerel X (0 = sol)
  final String? sidePreviewSide;
  final double? sidePreviewLocalY;
  final double? sidePreviewLocalX;

  const ShapePainter(
    this.spec, {
    this.overrideStrokeColor,
    this.overrideStrokeWidth,
    this.selectedElementId,
    this.showInternalElements = true,
    this.previewHorizontalLineY,
    this.previewVerticalLineX,
    this.previewShortHorizontalLineY,
    this.previewShortVerticalLineX,
    this.sideAttachments = const [],
    this.sidePreviewSide,
    this.sidePreviewLocalY,
    this.sidePreviewLocalX,
  });

  // ── mmToPx: sol panel offset'ini hesaba katar ──

  Offset _mmToPx(Offset mm, double scale, Offset offset) {
    double leftExtra = 0;
    for (final a in spec.sideAttachments) {
      if (a.side == 'left') leftExtra = math.max(leftExtra, a.width);
    }
    return Offset(
      (mm.dx + leftExtra) * scale + offset.dx,
      (spec.baseHeight - mm.dy) * scale + offset.dy,
    );
  }

  // ── SCALE / OFFSET ──

  double _calculateScale(Size canvasSize, bool isThumbnail) {
    final bounds = ShapeCropGeometry.totalBounds(spec);
    final padding = isThumbnail ? 0.8 : 0.75;
    return math.min(
      (canvasSize.width * padding) / bounds.width,
      (canvasSize.height * padding) / bounds.height,
    );
  }

  Offset _calculateCenterOffset(
    Size canvasSize,
    double scale,
    bool isThumbnail,
  ) {
    final bounds = ShapeCropGeometry.totalBounds(spec);
    final scaledW = bounds.width * scale;
    final scaledH = bounds.height * scale;

    if (isThumbnail) {
      return Offset(
        (canvasSize.width - scaledW) / 2,
        (canvasSize.height - scaledH) / 2,
      );
    }
    return Offset(
      (canvasSize.width - scaledW) / 2 + 20,
      (canvasSize.height - scaledH) / 2 - 30,
    );
  }

  // ── PAINT ──

  @override
  void paint(Canvas canvas, Size size) {
    final isThumbnail = size.width < 150 || !showInternalElements;
    final scale = _calculateScale(size, isThumbnail);
    final offset = _calculateCenterOffset(size, scale, isThumbnail);

    final pointsMm = spec.getPolygonPoints();
    final pointsPx = pointsMm.map((p) => _mmToPx(p, scale, offset)).toList();
    if (pointsPx.length < 4) return;

    _validateCropValues();
    final mainPath = _createMainPath(pointsPx);

    if (!isThumbnail) _drawBaseRectangle(canvas, scale, offset);
    _drawMainShape(canvas, mainPath);

    if (showInternalElements && !isThumbnail) {
      if (previewHorizontalLineY != null) {
        ShapeElementPainter.drawPreviewHorizontalLine(
          canvas,
          spec,
          scale,
          offset,
          previewHorizontalLineY!,
          _mmToPx,
        );
      }
      if (previewVerticalLineX != null) {
        ShapeElementPainter.drawPreviewVerticalLine(
          canvas,
          spec,
          scale,
          offset,
          previewVerticalLineX!,
          _mmToPx,
        );
      }
      ShapeElementPainter.drawInternalElements(
        canvas,
        spec,
        scale,
        offset,
        mainPath,
        _mmToPx,
        selectedElementId,
      );
    }

    if (previewShortHorizontalLineY != null) {
      ShapeElementPainter.drawPreviewShortHorizontalLine(
        canvas,
        spec,
        scale,
        offset,
        previewShortHorizontalLineY!,
        _mmToPx,
      );
    }
    if (previewShortVerticalLineX != null) {
      ShapeElementPainter.drawPreviewShortVerticalLine(
        canvas,
        spec,
        scale,
        offset,
        previewShortVerticalLineX!,
        _mmToPx,
      );
    }

    // ── YAN PANEL DİKDÖRTGENLERİ ──
    _drawSidePanelRects(canvas, pointsPx, scale, offset);

    // ── ÖLÇÜLER ──
    if (spec.showDimensions && !isThumbnail) {
      ShapeDimensionPainter.drawAllDimensions(
        canvas: canvas,
        spec: spec,
        pointsPx: pointsPx,
        sideAttachments: sideAttachments,
        scale: scale,
        offset: offset,
        mmToPx: _mmToPx,
        showInternalElements: showInternalElements,
      );
    }
  }

  // ── ANA ŞEKİL ──

  Path _createMainPath(List<Offset> pointsPx) {
    final path = Path();
    if (pointsPx.length >= 8) {
      path.moveTo(pointsPx[0].dx, pointsPx[0].dy);
      path.lineTo(pointsPx[1].dx, pointsPx[1].dy);
      path.lineTo(pointsPx[7].dx, pointsPx[7].dy);
      path.lineTo(pointsPx[6].dx, pointsPx[6].dy);
      path.lineTo(pointsPx[5].dx, pointsPx[5].dy);
      path.lineTo(pointsPx[4].dx, pointsPx[4].dy);
      path.lineTo(pointsPx[3].dx, pointsPx[3].dy);
      path.lineTo(pointsPx[2].dx, pointsPx[2].dy);
    } else {
      path.moveTo(pointsPx[0].dx, pointsPx[0].dy);
      for (int i = 1; i < pointsPx.length; i++) {
        path.lineTo(pointsPx[i].dx, pointsPx[i].dy);
      }
    }
    path.close();
    return path;
  }

  void _drawMainShape(Canvas canvas, Path path) {
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = overrideStrokeColor ?? spec.strokeColor
        ..strokeWidth = overrideStrokeWidth ?? spec.strokeWidth
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawBaseRectangle(Canvas canvas, double scale, Offset offset) {
    double leftExtra = 0;
    double rightExtra = 0;

    for (final a in spec.sideAttachments) {
      if (a.side == 'left') leftExtra = math.max(leftExtra, a.width);
      if (a.side == 'right') rightExtra = math.max(rightExtra, a.width);
    }

    // _mmToPx'i kullanmak yerine direkt piksel hesabı yap
    // Çünkü _mmToPx spec.baseHeight baz alıyor,
    // yan panel daha yüksekse kayma olur

    // Ana şeklin piksel sol-üst köşesi
    final mainTopLeftPx = _mmToPx(Offset(0, spec.baseHeight), scale, offset);

    // Toplam genişlik ve yükseklik piksel olarak
    final totalWidthPx = (spec.baseWidth + leftExtra + rightExtra) * scale;

    // Yükseklik: en yüksek paneli baz al
    double maxHeight = spec.baseHeight;
    for (final a in spec.sideAttachments) {
      maxHeight = math.max(maxHeight, a.height);
    }
    final totalHeightPx = maxHeight * scale;

    // Sol kenar: mainTopLeft'ten leftExtra kadar sola
    final rectLeft = mainTopLeftPx.dx - leftExtra * scale;
    final rectTop = mainTopLeftPx.dy; // ana şeklin üst kenarıyla hizalı

    canvas.drawRect(
      Rect.fromLTWH(rectLeft, rectTop, totalWidthPx, totalHeightPx),
      Paint()
        ..color = Colors.grey.shade300
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
  }
  // ============================================================
  // SADECE _drawSidePanelRects metodunu bununla değiştir.
  // Dosyanın geri kalanı — paint(), _createMainPath(),
  // _drawMainShape(), shouldRepaint() vs — HİÇ DEĞİŞMEZ.
  // ============================================================

  void _drawSidePanelRects(
    Canvas canvas,
    List<Offset> pointsPx,
    double scale,
    Offset offset,
  ) {
    for (final attach in sideAttachments) {
      final mainLeft = pointsPx.map((p) => p.dx).reduce(math.min);
      final mainTop = pointsPx.map((p) => p.dy).reduce(math.min);
      final mainRight = pointsPx.map((p) => p.dx).reduce(math.max);

      // ── mmToPx ile doğru hesapla ──────────────────────────
      // Y ekseni ters: yTop → küçük px, yBottom → büyük px
      final double pLeft, pTop, pRight, pBottom;

      if (attach.side == 'right') {
        pLeft = mainRight;
        pTop = mainTop; // ana şeklin üst kenarıyla hizalı

        // attach.height mm → px: mmToPx y eksenini ters çevirdiği için
        // panelin alt kenarı = mmToPx(y=0), üst kenarı = mmToPx(y=attach.height)
        // Bunu doğrudan scale ile hesapla:
        final topMm = _mmToPx(Offset(0, attach.height), scale, offset);
        final bottomMm = _mmToPx(Offset(0, 0), scale, offset);
        final heightPx = bottomMm.dy - topMm.dy; // pozitif fark

        pRight = pLeft + attach.width * scale;
        pBottom = pTop + heightPx;
      } else {
        // left
        pRight = mainLeft;
        pTop = mainTop;

        final topMm = _mmToPx(Offset(0, attach.height), scale, offset);
        final bottomMm = _mmToPx(Offset(0, 0), scale, offset);
        final heightPx = bottomMm.dy - topMm.dy;

        pLeft = pRight - attach.width * scale;
        pBottom = pTop + heightPx;
      }

      final panelRect = Rect.fromLTRB(pLeft, pTop, pRight, pBottom);

      // ── Çerçeve ──
      canvas.drawRect(
        panelRect,
        Paint()
          ..color = overrideStrokeColor ?? Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = overrideStrokeWidth ?? 2,
      );

      // ── Drag önizleme (gölge) — yan panel ──
      // Sürükleme sırasında çizginin nereye düşeceğini panelin İÇİNDE
      // gösterir. Eskiden değer ana şekil mm'i gibi yorumlanıp gölge
      // ana şeklin üzerinde çiziliyordu; artık panelRect'e göre çizilir.
      if (sidePreviewSide == attach.side) {
        final previewPaint = Paint()
          ..color = Colors.grey.withValues(alpha: 0.6)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        if (sidePreviewLocalY != null) {
          final h = attach.height <= 0 ? 1.0 : attach.height;
          final fy = (sidePreviewLocalY! / h).clamp(0.0, 1.0);
          final py = panelRect.bottom - fy * panelRect.height;
          canvas.drawLine(
            Offset(panelRect.left, py),
            Offset(panelRect.right, py),
            previewPaint,
          );
        }
        if (sidePreviewLocalX != null) {
          final w = attach.width <= 0 ? 1.0 : attach.width;
          final fx = (sidePreviewLocalX! / w).clamp(0.0, 1.0);
          final px = panelRect.left + fx * panelRect.width;
          canvas.drawLine(
            Offset(px, panelRect.top),
            Offset(px, panelRect.bottom),
            previewPaint,
          );
        }
      }

      // ── İç elemanlar ──
      if (attach.internalElements.isNotEmpty) {
        final bounds = spec.boundingSize;
        final xShift = (spec.baseWidth - bounds.width) / 2;
        final mainLeftMm = xShift;
        final mainRightMm = xShift + bounds.width;

        final Offset localToGlobal;
        if (attach.side == 'left') {
          localToGlobal = Offset(mainLeftMm - attach.width, 0);
        } else {
          localToGlobal = Offset(mainRightMm, 0);
        }

        ShapeElementPainter.drawSidePanelElements(
          canvas,
          attach,
          panelRect,
          localToGlobal,
          scale,
          offset,
          _mmToPx,
        );
      }
    }
  }
  // ── DOĞRULAMA ──

  void _validateCropValues() {
    final checks = [
      (spec.topLeftX + spec.topRightX > spec.baseWidth, 'Üst kenar crop aşımı'),
      (
        spec.bottomLeftX + spec.bottomRightX > spec.baseWidth,
        'Alt kenar crop aşımı',
      ),
      (
        spec.topLeftY + spec.bottomLeftY > spec.baseHeight,
        'Sol kenar crop aşımı',
      ),
      (
        spec.topRightY + spec.bottomRightY > spec.baseHeight,
        'Sağ kenar crop aşımı',
      ),
    ];
    for (final (hasError, msg) in checks) {
      if (hasError) debugPrint('❌ Crop Hatası: $msg');
    }
  }

  // ── REPAINT ──

  @override
  bool shouldRepaint(covariant ShapePainter oldDelegate) {
    return oldDelegate.spec != spec ||
        oldDelegate.overrideStrokeColor != overrideStrokeColor ||
        oldDelegate.overrideStrokeWidth != overrideStrokeWidth ||
        oldDelegate.selectedElementId != selectedElementId ||
        oldDelegate.showInternalElements != showInternalElements ||
        oldDelegate.previewHorizontalLineY != previewHorizontalLineY ||
        oldDelegate.previewVerticalLineX != previewVerticalLineX ||
        oldDelegate.previewShortHorizontalLineY !=
            previewShortHorizontalLineY ||
        oldDelegate.previewShortVerticalLineX != previewShortVerticalLineX ||
        oldDelegate.sideAttachments != sideAttachments ||
        oldDelegate.sidePreviewSide != sidePreviewSide ||
        oldDelegate.sidePreviewLocalY != sidePreviewLocalY ||
        oldDelegate.sidePreviewLocalX != sidePreviewLocalX;
  }
}
