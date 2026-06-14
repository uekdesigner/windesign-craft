// lib/features/drawing/painters/shape_element_painter.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/shape_spec.dart';
import '../geometry/shape_crop_geometry.dart';
import 'painter_helpers.dart';
import 'shape_dimension_painter.dart';

/// [ShapeSpec]'e ait tüm iç elemanları (üçgen, ok, çizgi, dotGrid, lineGrid)
/// ve önizleme (preview) çizgilerini çizen sınıf.
///
/// Tüm metodlar [static]. Instantiate edilmez.
/// [mmToPx] fonksiyonu dışarıdan geçirilir; sol panel offset'ini içerir.
class ShapeElementPainter {
  const ShapeElementPainter._();

  // ── ANA GİRİŞ NOKTASI ──

  /// Tüm iç elemanları doğru sırayla çizer.
  /// Sıra: üçgenler → oklar → dotGrid → lineGrid → çizgiler
  static void drawInternalElements(
    Canvas canvas,
    ShapeSpec spec,
    double scale,
    Offset offset,
    Path mainShapePath,
    MmToPx mmToPx,
    String? selectedElementId,
  ) {
    _drawTriangles(canvas, spec, scale, offset, mainShapePath, mmToPx);
    _drawSlideArrows(canvas, spec, scale, offset, mainShapePath, mmToPx);
    _drawDotGrids(canvas, spec, scale, offset, mainShapePath, mmToPx);
    _drawLineGrids(canvas, spec, scale, offset, mainShapePath, mmToPx);
    _drawLines(canvas, spec, scale, offset, mmToPx, selectedElementId);
  }

  // ── ÖNİZLEME ÇİZGİLERİ ──

  static void drawPreviewHorizontalLine(
    Canvas canvas,
    ShapeSpec spec,
    double scale,
    Offset offset,
    double mmY,
    MmToPx mmToPx,
  ) {
    final xLeft = ShapeCropGeometry.leftXAtY(spec, mmY);
    final xRight = ShapeCropGeometry.rightXAtY(spec, mmY);
    _drawPreviewLine(
      canvas,
      mmToPx(Offset(xLeft, mmY), scale, offset),
      mmToPx(Offset(xRight, mmY), scale, offset),
      Colors.grey.withValues(alpha: 0.6),
    );
  }

  static void drawPreviewVerticalLine(
    Canvas canvas,
    ShapeSpec spec,
    double scale,
    Offset offset,
    double mmX,
    MmToPx mmToPx,
  ) {
    final yTop = ShapeCropGeometry.topYAtX(spec, mmX);
    final yBottom = ShapeCropGeometry.bottomYAtX(spec, mmX);
    _drawPreviewLine(
      canvas,
      mmToPx(Offset(mmX, yTop), scale, offset),
      mmToPx(Offset(mmX, yBottom), scale, offset),
      Colors.grey.withValues(alpha: 0.6),
    );
  }

  static void drawPreviewShortHorizontalLine(
    Canvas canvas,
    ShapeSpec spec,
    double scale,
    Offset offset,
    double mmY,
    MmToPx mmToPx,
  ) {
    final xLeft = ShapeCropGeometry.leftXAtY(spec, mmY);
    final xRight = ShapeCropGeometry.rightXAtY(spec, mmY);
    _drawPreviewLine(
      canvas,
      mmToPx(Offset(xLeft, mmY), scale, offset),
      mmToPx(Offset(xRight, mmY), scale, offset),
      Colors.teal.withValues(alpha: 0.6),
    );
  }

  static void drawPreviewShortVerticalLine(
    Canvas canvas,
    ShapeSpec spec,
    double scale,
    Offset offset,
    double mmX,
    MmToPx mmToPx,
  ) {
    final yTop = ShapeCropGeometry.topYAtX(spec, mmX);
    final yBottom = ShapeCropGeometry.bottomYAtX(spec, mmX);
    _drawPreviewLine(
      canvas,
      mmToPx(Offset(mmX, yTop), scale, offset),
      mmToPx(Offset(mmX, yBottom), scale, offset),
      Colors.teal.withValues(alpha: 0.6),
    );
  }

  // ── ÜÇGENLERi ──

  static void _drawTriangles(
    Canvas canvas,
    ShapeSpec spec,
    double scale,
    Offset offset,
    Path mainShapePath,
    MmToPx mmToPx,
  ) {
    final triangles = spec.internalElements.where(
      (e) => e.type == InternalElementType.triangle,
    );

    for (final element in triangles) {
      final direction = TriangleDirection.values.byName(
        element.properties['direction'] as String? ?? 'up',
      );

      final leftX = element.position.dx;
      final topY = element.position.dy;
      final width = element.size.width;
      final height = element.size.height;
      final rightX = leftX + width;
      final bottomY = topY - height;

      Offset px(Offset mm) => mmToPx(mm, scale, offset);

      final path = Path();
      switch (direction) {
        case TriangleDirection.up:
          path.moveTo(
            px(Offset(leftX, bottomY)).dx,
            px(Offset(leftX, bottomY)).dy,
          );
          path.lineTo(
            px(Offset(rightX, bottomY)).dx,
            px(Offset(rightX, bottomY)).dy,
          );
          path.lineTo(
            px(Offset(leftX + width / 2, topY)).dx,
            px(Offset(leftX + width / 2, topY)).dy,
          );
          break;
        case TriangleDirection.down:
          break;
        case TriangleDirection.left:
          path.moveTo(px(Offset(rightX, topY)).dx, px(Offset(rightX, topY)).dy);
          path.lineTo(
            px(Offset(rightX, bottomY)).dx,
            px(Offset(rightX, bottomY)).dy,
          );
          path.lineTo(
            px(Offset(leftX, topY - height / 2)).dx,
            px(Offset(leftX, topY - height / 2)).dy,
          );
          break;
        case TriangleDirection.right:
          path.moveTo(px(Offset(leftX, topY)).dx, px(Offset(leftX, topY)).dy);
          path.lineTo(
            px(Offset(leftX, bottomY)).dx,
            px(Offset(leftX, bottomY)).dy,
          );
          path.lineTo(
            px(Offset(rightX, topY - height / 2)).dx,
            px(Offset(rightX, topY - height / 2)).dy,
          );
          break;
      }
      path.close();

      canvas.save();
      canvas.clipPath(mainShapePath);
      PainterHelpers.drawDashedPath(
        canvas,
        path,
        Paint()
          ..color = const Color.fromARGB(255, 198, 199, 199)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
        dashLength: 8,
        gapLength: 4,
      );
      canvas.restore();
    }
  }

  // ── SÜRME OKLARI ──

  static void _drawSlideArrows(
    Canvas canvas,
    ShapeSpec spec,
    double scale,
    Offset offset,
    Path mainShapePath,
    MmToPx mmToPx,
  ) {
    final arrows = spec.internalElements
        .where((e) => e.type == InternalElementType.slideArrow)
        .toList();

    if (arrows.isEmpty) return;

    // Aynı paneldeki okları grupla (pozisyon + boyut anahtarı)
    final groups = <String, List<InternalElement>>{};
    for (final a in arrows) {
      final key =
          '${a.position.dx.toInt()}_${a.position.dy.toInt()}_'
          '${a.size.width.toInt()}_${a.size.height.toInt()}';
      groups.putIfAbsent(key, () => []).add(a);
    }

    for (final group in groups.values) {
      final panelW = group.first.size.width;
      final panelH = group.first.size.height;
      final panelCx = group.first.position.dx + panelW / 2;
      final panelCy = group.first.position.dy - panelH / 2;

      // Panel boyutuna orantılı ikon boyutu
      final panelWPx = panelW * scale;
      final panelHPx = panelH * scale;
      final iconSizePx = (math.min(panelWPx, panelHPx) * 0.45).clamp(
        14.0,
        44.0,
      );

      canvas.save();
      canvas.clipPath(mainShapePath);

      final centerPx = mmToPx(Offset(panelCx, panelCy), scale, offset);

      if (group.length >= 2) {
        // İki ok → çift yönlü ikon
        _drawSingleArrowIcon(canvas, centerPx, Icons.swap_horiz, iconSizePx);
      } else {
        // Tek ok → yön ikonu
        final isRight =
            (group.first.properties['direction'] as String? ?? 'right') ==
            'right';
        _drawSingleArrowIcon(
          canvas,
          centerPx,
          isRight ? Icons.arrow_forward : Icons.arrow_back,
          iconSizePx,
        );
      }

      canvas.restore();
    }
  }

  // Panel boyutuna orantılı tek ikon çiz (beyaz arka plan ile)
  static void _drawSingleArrowIcon(
    Canvas canvas,
    Offset centerPx,
    IconData iconData,
    double fontSize,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          fontFamily: 'MaterialIcons',
          color: const Color.fromARGB(255, 122, 122, 122),
          fontSize: fontSize,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final iconPos = Offset(
      centerPx.dx - textPainter.width / 2,
      centerPx.dy - textPainter.height / 2,
    );

    canvas.drawRect(
      Rect.fromLTWH(
        iconPos.dx - 3,
        iconPos.dy - 3,
        textPainter.width + 6,
        textPainter.height + 6,
      ),
      Paint()..color = Colors.white.withOpacity(0.85),
    );
    textPainter.paint(canvas, iconPos);
  }

  // ── DOT GRİD (çapraz tarama) ──

  static void _drawDotGrids(
    Canvas canvas,
    ShapeSpec spec,
    double scale,
    Offset offset,
    Path mainShapePath,
    MmToPx mmToPx,
  ) {
    final dotGrids = spec.internalElements
        .where((e) => e.type == InternalElementType.dotGrid)
        .toList();

    if (dotGrids.isEmpty) return;

    final hatchPaint = Paint()
      ..color = const Color.fromARGB(255, 187, 186, 186)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const stepPx = 8.0;

    for (final element in dotGrids) {
      final bounds = _panelBoundsPx(element, scale, offset, mmToPx);
      if (bounds == null) continue;

      canvas.save();
      canvas.clipPath(mainShapePath);
      canvas.clipRect(bounds);

      _drawDiagonalHatch(
        canvas,
        bounds.left,
        bounds.top,
        bounds.right,
        bounds.bottom,
        stepPx,
        hatchPaint,
        true,
      );
      _drawDiagonalHatch(
        canvas,
        bounds.left,
        bounds.top,
        bounds.right,
        bounds.bottom,
        stepPx,
        hatchPaint,
        false,
      );

      canvas.restore();
    }
  }

  // ── LİNE GRİD (düz dikey çizgiler) ──

  static void _drawLineGrids(
    Canvas canvas,
    ShapeSpec spec,
    double scale,
    Offset offset,
    Path mainShapePath,
    MmToPx mmToPx,
  ) {
    final lineGrids = spec.internalElements
        .where((e) => e.type == InternalElementType.lineGrid)
        .toList();

    if (lineGrids.isEmpty) return;

    final linePaint = Paint()
      ..color = const Color.fromARGB(255, 187, 186, 186)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const stepPx = 12.0;

    for (final element in lineGrids) {
      final bounds = _panelBoundsPx(element, scale, offset, mmToPx);
      if (bounds == null) continue;

      canvas.save();
      canvas.clipPath(mainShapePath);
      canvas.clipRect(bounds);

      double x = bounds.left + stepPx;
      while (x < bounds.right) {
        canvas.drawLine(
          Offset(x, bounds.top),
          Offset(x, bounds.bottom),
          linePaint,
        );
        x += stepPx;
      }

      canvas.restore();
    }
  }

  // ── ÇİZGİLER (yatay / dikey) ──

  static void _drawLines(
    Canvas canvas,
    ShapeSpec spec,
    double scale,
    Offset offset,
    MmToPx mmToPx,
    String? selectedElementId,
  ) {
    final others = spec.internalElements.where(
      (e) => e.type != InternalElementType.triangle,
    );

    for (final element in others) {
      final isSelected = element.id == selectedElementId;
      final paint = Paint()
        ..color = isSelected ? Colors.blue.shade600 : spec.strokeColor
        ..strokeWidth = isSelected ? 4.0 : 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      switch (element.type) {
        case InternalElementType.verticalLine:
          _drawVerticalLine(
            canvas,
            element,
            spec,
            scale,
            offset,
            paint,
            isSelected,
            mmToPx,
          );
          break;
        case InternalElementType.horizontalLine:
          _drawHorizontalLine(
            canvas,
            element,
            spec,
            scale,
            offset,
            paint,
            isSelected,
            mmToPx,
          );
          break;
        default:
          break;
      }
    }
  }

  static void _drawVerticalLine(
    Canvas canvas,
    InternalElement element,
    ShapeSpec spec,
    double scale,
    Offset offset,
    Paint paint,
    bool isSelected,
    MmToPx mmToPx,
  ) {
    final isShort = element.properties['isShort'] == true;
    final lineX = element.position.dx;

    final Offset start;
    final Offset end;

    if (isShort) {
      start = mmToPx(element.position, scale, offset);
      end = Offset(start.dx, start.dy + element.size.height * scale);
    } else {
      final yTop = ShapeCropGeometry.topYAtX(spec, lineX);
      final yBottom = ShapeCropGeometry.bottomYAtX(spec, lineX);
      start = mmToPx(Offset(lineX, yTop), scale, offset);
      end = mmToPx(Offset(lineX, yBottom), scale, offset);
    }

    canvas.drawLine(start, end, paint);
  }

  static void _drawHorizontalLine(
    Canvas canvas,
    InternalElement element,
    ShapeSpec spec,
    double scale,
    Offset offset,
    Paint paint,
    bool isSelected,
    MmToPx mmToPx,
  ) {
    final isShort = element.properties['isShort'] == true;
    final lineY = element.position.dy;

    final Offset start;
    final Offset end;

    if (isShort) {
      start = mmToPx(element.position, scale, offset);
      end = Offset(start.dx + element.size.width * scale, start.dy);
    } else {
      final xLeft = ShapeCropGeometry.leftXAtY(spec, lineY);
      final xRight = ShapeCropGeometry.rightXAtY(spec, lineY);
      start = mmToPx(Offset(xLeft, lineY), scale, offset);
      end = mmToPx(Offset(xRight, lineY), scale, offset);
    }

    if (isSelected) {
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = Colors.blue.withValues(alpha: 0.2)
          ..strokeWidth = 8.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawLine(start, end, paint);
  }

  // ── ÖZEL YARDIMCILAR ──

  static Rect? _panelBoundsPx(
    InternalElement element,
    double scale,
    Offset offset,
    MmToPx mmToPx,
  ) {
    final leftMm = element.position.dx;
    final topMm = element.position.dy;
    final rightMm = leftMm + element.size.width;
    final bottomMm = topMm - element.size.height;

    final leftPx = mmToPx(Offset(leftMm, 0), scale, offset).dx;
    final rightPx = mmToPx(Offset(rightMm, 0), scale, offset).dx;
    final topPx = mmToPx(Offset(0, topMm), scale, offset).dy;
    final bottomPx = mmToPx(Offset(0, bottomMm), scale, offset).dy;

    if ((rightPx - leftPx) < 10 || (bottomPx - topPx) < 10) return null;
    return Rect.fromLTRB(leftPx, topPx, rightPx, bottomPx);
  }

  static void _drawDiagonalHatch(
    Canvas canvas,
    double left,
    double top,
    double right,
    double bottom,
    double step,
    Paint paint,
    bool isForwardSlash,
  ) {
    if (isForwardSlash) {
      // / yönü: y = x + b
      for (double b = top - right; b <= bottom - left; b += step) {
        final points = <Offset>[];
        final yLeft = left + b;
        if (yLeft >= top && yLeft <= bottom) points.add(Offset(left, yLeft));
        final yRight = right + b;
        if (yRight >= top && yRight <= bottom)
          points.add(Offset(right, yRight));
        final xTop = top - b;
        if (xTop >= left && xTop <= right) points.add(Offset(xTop, top));
        final xBottom = bottom - b;
        if (xBottom >= left && xBottom <= right)
          points.add(Offset(xBottom, bottom));
        if (points.length >= 2)
          canvas.drawLine(points.first, points.last, paint);
      }
    } else {
      // \ yönü: y = -x + b
      for (double b = top + left; b <= bottom + right; b += step) {
        final points = <Offset>[];
        final yLeft = -left + b;
        if (yLeft >= top && yLeft <= bottom) points.add(Offset(left, yLeft));
        final yRight = -right + b;
        if (yRight >= top && yRight <= bottom)
          points.add(Offset(right, yRight));
        final xTop = b - top;
        if (xTop >= left && xTop <= right) points.add(Offset(xTop, top));
        final xBottom = b - bottom;
        if (xBottom >= left && xBottom <= right)
          points.add(Offset(xBottom, bottom));
        if (points.length >= 2)
          canvas.drawLine(points.first, points.last, paint);
      }
    }
  }

  static void _drawPreviewLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Color color,
  ) {
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }
  // lib/features/drawing/painters/shape_element_painter.dart
  // ============================================================
  // MEVCUT DOSYANIN SONUNA EKLE — başka hiçbir şey değişmez
  // ShapeElementPainter sınıfının kapanma } 'inden ÖNCE ekle
  // ============================================================

  // ═══════════════════════════════════════════════════════════
  // YAN PANEL ELEMANLARI — drawSidePanelElements
  // ═══════════════════════════════════════════════════════════

  /// Bir SideAttachment içindeki tüm elemanları çizer.
  ///
  /// [panelRect] → pikselde panel sınırı (clip için)
  /// [localToGlobal] → yerel mm → global mm dönüşüm offset'i
  ///   Sol panel : Offset(mainLeftMm - attach.width, 0)
  ///   Sağ panel : Offset(mainRightMm, 0)
  static void drawSidePanelElements(
    Canvas canvas,
    SideAttachment attach,
    Rect panelRect, // px — clip sınırı
    Offset localToGlobal, // mm — yerel→global offset
    double scale,
    Offset offset,
    MmToPx mmToPx,
  ) {
    if (attach.internalElements.isEmpty) return;

    // Yerel mm → piksel dönüşümü.
    // ÖNEMLİ: Artık global mmToPx yerine doğrudan panelRect'e göre
    // hesaplıyoruz. Global mmToPx'in Y orijini ANA ŞEKLİN tabanıdır;
    // yan panel ana şekilden YÜKSEK olduğunda elemanlar ana şekil
    // yüksekliğinde kırpılıyordu. panelRect zaten attach.height ile
    // doğru çizildiği için ona göre eşleştiriyoruz → panel ne kadar
    // yüksekse eleman da o kadar yüksek çizilir.
    // (localToGlobal / scale / offset / mmToPx artık kullanılmıyor.)
    final double pw = attach.width <= 0 ? 1.0 : attach.width;
    final double ph = attach.height <= 0 ? 1.0 : attach.height;
    Offset lpx(Offset localMm) => Offset(
      panelRect.left + (localMm.dx / pw) * panelRect.width,
      panelRect.bottom - (localMm.dy / ph) * panelRect.height,
    );

    for (final element in attach.internalElements) {
      switch (element.type) {
        case InternalElementType.triangle:
          _drawSidePanelTriangle(canvas, element, panelRect, lpx, attach);
          break;

        case InternalElementType.slideArrow:
          // slideArrow'lar ayrıca işlenir — aşağıdaki gruplu çizime bırak
          break;

        case InternalElementType.horizontalLine:
          _drawSidePanelHorizontalLine(canvas, element, panelRect, lpx, attach);
          break;

        case InternalElementType.verticalLine:
          _drawSidePanelVerticalLine(canvas, element, panelRect, lpx, attach);
          break;

        case InternalElementType.dotGrid:
          _drawSidePanelDotGrid(canvas, element, panelRect, lpx);
          break;

        case InternalElementType.lineGrid:
          _drawSidePanelLineGrid(canvas, element, panelRect, lpx);
          break;

        default:
          break;
      }
    }

    // ── Yan panel slideArrow'larını gruplu çiz ──
    final slideArrows = attach.internalElements
        .where((e) => e.type == InternalElementType.slideArrow)
        .toList();
    if (slideArrows.isNotEmpty) {
      _drawSidePanelSlideArrowGroups(
        canvas,
        slideArrows,
        panelRect,
        scale,
        lpx,
      );
    }
  }

  // ── YAN PANEL ÜÇGENİ ──

  static void _drawSidePanelTriangle(
    Canvas canvas,
    InternalElement element,
    Rect panelRect,
    Offset Function(Offset) lpx,
    SideAttachment attach,
  ) {
    final direction = TriangleDirection.values.byName(
      element.properties['direction'] as String? ?? 'right',
    );

    // Piksel köşeleri — lpx yerine direkt panelRect kullan
    // Bu sayede localToGlobal hesap hatası üçgeni etkilemez
    final tl = Offset(panelRect.left, panelRect.top);
    final tr = Offset(panelRect.right, panelRect.top);
    final bl = Offset(panelRect.left, panelRect.bottom);
    final br = Offset(panelRect.right, panelRect.bottom);
    final tc = Offset(panelRect.center.dx, panelRect.top);
    final bc = Offset(panelRect.center.dx, panelRect.bottom);
    final ml = Offset(panelRect.left, panelRect.center.dy);
    final mr = Offset(panelRect.right, panelRect.center.dy);

    final path = Path();
    switch (direction) {
      case TriangleDirection.up:
        path.moveTo(bl.dx, bl.dy);
        path.lineTo(br.dx, br.dy);
        path.lineTo(tc.dx, tc.dy);
        break;
      case TriangleDirection.down:
        path.moveTo(tl.dx, tl.dy);
        path.lineTo(tr.dx, tr.dy);
        path.lineTo(bc.dx, bc.dy);
        break;
      case TriangleDirection.left:
        path.moveTo(tr.dx, tr.dy);
        path.lineTo(br.dx, br.dy);
        path.lineTo(ml.dx, ml.dy);
        break;
      case TriangleDirection.right:
        path.moveTo(tl.dx, tl.dy);
        path.lineTo(bl.dx, bl.dy);
        path.lineTo(mr.dx, mr.dy);
        break;
    }
    path.close();

    canvas.save();
    canvas.clipRect(panelRect); // sadece panel içi
    PainterHelpers.drawDashedPath(
      canvas,
      path,
      Paint()
        ..color = const Color.fromARGB(255, 198, 199, 199)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
      dashLength: 8,
      gapLength: 4,
    );
    canvas.restore();
  }
  // ── YAN PANEL SÜRME OKU ──

  // ── YAN PANEL SÜRME OKU (gruplu çizim) ──

  static void _drawSidePanelSlideArrowGroups(
    Canvas canvas,
    List<InternalElement> arrows,
    Rect panelRect,
    double scale,
    Offset Function(Offset) lpx,
  ) {
    // Aynı hücredeki okları grupla (subRect anahtarı)
    final groups = <String, List<InternalElement>>{};
    for (final a in arrows) {
      final subRect = _elementSubRect(a, lpx);
      final key =
          '${subRect.left.toInt()}_${subRect.top.toInt()}_'
          '${subRect.width.toInt()}_${subRect.height.toInt()}';
      groups.putIfAbsent(key, () => []).add(a);
    }

    for (final group in groups.values) {
      final subRect = _elementSubRect(group.first, lpx);
      final centerPx = subRect.center;

      // Hücre boyutuna orantılı ikon boyutu
      final iconSizePx = (math.min(subRect.width, subRect.height) * 0.45).clamp(
        14.0,
        44.0,
      );

      canvas.save();
      canvas.clipRect(subRect);

      if (group.length >= 2) {
        // İki ok → çift yönlü ikon
        _drawSingleArrowIcon(canvas, centerPx, Icons.swap_horiz, iconSizePx);
      } else {
        // Tek ok → yön ikonu
        final isRight =
            (group.first.properties['direction'] as String? ?? 'right') ==
            'right';
        _drawSingleArrowIcon(
          canvas,
          centerPx,
          isRight ? Icons.arrow_forward : Icons.arrow_back,
          iconSizePx,
        );
      }

      canvas.restore();
    }
  }

  // ── YAN PANEL YATAY ÇİZGİ ──

  static void _drawSidePanelHorizontalLine(
    Canvas canvas,
    InternalElement element,
    Rect panelRect,
    Offset Function(Offset) lpx,
    SideAttachment attach,
  ) {
    final isShort = element.properties['isShort'] == true;
    final y = element.position.dy;

    final Offset start;
    final Offset end;

    if (isShort) {
      // Kısa çizgi: position.dx → position.dx + size.width
      start = lpx(Offset(element.position.dx, y));
      end = lpx(Offset(element.position.dx + element.size.width, y));
    } else {
      // Uzun çizgi: panel genişliği boyunca
      start = lpx(Offset(0, y));
      end = lpx(Offset(attach.width, y));
    }

    canvas.save();
    canvas.clipRect(panelRect);
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = Colors.black
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  // ── YAN PANEL DİKEY ÇİZGİ ──

  static void _drawSidePanelVerticalLine(
    Canvas canvas,
    InternalElement element,
    Rect panelRect,
    Offset Function(Offset) lpx,
    SideAttachment attach,
  ) {
    final isShort = element.properties['isShort'] == true;
    final x = element.position.dx;

    final Offset start;
    final Offset end;

    if (isShort) {
      // Kısa dikey: position.dy → position.dy - size.height
      start = lpx(Offset(x, element.position.dy));
      end = lpx(Offset(x, element.position.dy - element.size.height));
    } else {
      // Uzun dikey: panel yüksekliği boyunca
      start = lpx(Offset(x, 0));
      end = lpx(Offset(x, attach.height));
    }

    canvas.save();
    canvas.clipRect(panelRect);
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = Colors.black
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  // ── YARDIMCI: element bounds → alt dikdörtgen (px) ──

  /// InternalElement'in position/size'ını lpx ile piksel Rect'e çevirir.
  /// Ana şekildeki `_panelBoundsPx`'in yan panel karşılığı.
  ///
  /// Konvansiyon (panel-yerel mm):
  ///   position.dx = sol kenar X,  position.dy = üst kenar Y (Y↑)
  ///   size.width  = genişlik,     size.height = yükseklik (aşağı)
  static Rect _elementSubRect(
    InternalElement element,
    Offset Function(Offset) lpx,
  ) {
    final topLeftPx = lpx(element.position); // (leftX, topY)
    final bottomRightPx = lpx(
      Offset(
        element.position.dx + element.size.width, // rightX
        element.position.dy - element.size.height, // bottomY
      ),
    );
    return Rect.fromLTRB(
      topLeftPx.dx,
      topLeftPx.dy,
      bottomRightPx.dx,
      bottomRightPx.dy,
    );
  }

  // ── YAN PANEL DOT GRİD ──

  static void _drawSidePanelDotGrid(
    Canvas canvas,
    InternalElement element,
    Rect panelRect,
    Offset Function(Offset) lpx,
  ) {
    // Element bounds'ından alt bölüm dikdörtgeni hesapla
    final subRect = _elementSubRect(element, lpx);

    final hatchPaint = Paint()
      ..color = const Color.fromARGB(255, 187, 186, 186)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const stepPx = 8.0;

    canvas.save();
    canvas.clipRect(subRect);

    _drawDiagonalHatch(
      canvas,
      subRect.left,
      subRect.top,
      subRect.right,
      subRect.bottom,
      stepPx,
      hatchPaint,
      true,
    );
    _drawDiagonalHatch(
      canvas,
      subRect.left,
      subRect.top,
      subRect.right,
      subRect.bottom,
      stepPx,
      hatchPaint,
      false,
    );

    canvas.restore();
  }

  // ── YAN PANEL LINE GRİD ──

  static void _drawSidePanelLineGrid(
    Canvas canvas,
    InternalElement element,
    Rect panelRect,
    Offset Function(Offset) lpx,
  ) {
    final subRect = _elementSubRect(element, lpx);

    final linePaint = Paint()
      ..color = const Color.fromARGB(255, 187, 186, 186)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const stepPx = 12.0;

    canvas.save();
    canvas.clipRect(subRect);

    double x = subRect.left + stepPx;
    while (x < subRect.right) {
      canvas.drawLine(
        Offset(x, subRect.top),
        Offset(x, subRect.bottom),
        linePaint,
      );
      x += stepPx;
    }

    canvas.restore();
  }
}
