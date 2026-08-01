// lib/features/drawing/painters/shape_dimension_painter.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/shape_spec.dart';
import '../geometry/shape_crop_geometry.dart';
import 'painter_helpers.dart';

typedef MmToPx = Offset Function(Offset mm, double scale, Offset offset);

const double _kBase = 15.0;
const double _kStep = 20.0;

class ShapeDimensionPainter {
  const ShapeDimensionPainter._();

  static void drawAllDimensions({
    required Canvas canvas,
    required ShapeSpec spec,
    required List<Offset> pointsPx,
    required List<SideAttachment> sideAttachments,
    required double scale,
    required Offset offset,
    required MmToPx mmToPx,
    bool showInternalElements = true,
  }) {
    final ctx = _MeasureContext.from(
      spec,
      sideAttachments,
      scale,
      offset,
      mmToPx,
      pointsPx,
    );
    drawDimensions(canvas, spec, pointsPx);
    _drawHeightSystem(canvas, spec, ctx);
    _drawWidthSystem(canvas, spec, ctx);
    if (showInternalElements) {
      _drawInternalLineDimensions(canvas, spec, ctx);
      _drawSidePanelInternalLineDimensions(canvas, ctx);
    }
  }

  static void _drawHeightSystem(
    Canvas canvas,
    ShapeSpec spec,
    _MeasureContext ctx,
  ) {
    final lo = ctx.leftOffsets;
    final ro = ctx.rightOffsets;
    final leftRef = ctx.leftmostPx;
    final rightRef = ctx.rightmostPx;
    final topPx = ctx.mainTopPx;
    final botPx = ctx.mainBottomPx;

    if (lo.mainExt != null) {
      _drawHDimLine(
        canvas,
        leftRef - lo.mainExt!,
        topPx,
        botPx,
        '${spec.baseHeight.toInt()}',
      );
    }

    if (lo.mainInnerH != null) {
      _drawMainInnerHeights(canvas, spec, ctx, leftRef - lo.mainInnerH!);
    }

    if (lo.leftExt != null && ctx.leftAttach != null) {
      final h = ctx.leftAttach!.height;
      _drawHDimLine(
        canvas,
        leftRef - lo.leftExt!,
        topPx,
        topPx + h * ctx.scale,
        '${h.toInt()}',
      );
    }

    // 🆕 Sol panel iç yatay çizgi segment ölçüleri
    if (lo.leftInnerH != null && ctx.leftAttach != null) {
      _drawSidePanelInnerHeights(
        canvas,
        ctx.leftAttach!,
        ctx,
        leftRef - lo.leftInnerH!,
        textOnLeft: true,
      );
    }

    if (ro.rightExt != null && ctx.rightAttach != null) {
      final h = ctx.rightAttach!.height;
      _drawHDimLine(
        canvas,
        rightRef + ro.rightExt!,
        topPx,
        topPx + h * ctx.scale,
        '${h.toInt()}',
        textOnLeft: false,
      );
    }

    // 🆕 Sağ panel iç yatay çizgi segment ölçüleri
    if (ro.rightInnerH != null && ctx.rightAttach != null) {
      _drawSidePanelInnerHeights(
        canvas,
        ctx.rightAttach!,
        ctx,
        rightRef + ro.rightInnerH!,
        textOnLeft: false,
      );
    }

    // 🆕 Ana şekil ölçüleri sağ tarafa taşınmışsa (sol panel var, sağ panel yok)
    if (ro.mainExt != null) {
      _drawHDimLine(
        canvas,
        rightRef + ro.mainExt!,
        topPx,
        botPx,
        '${spec.baseHeight.toInt()}',
        textOnLeft: false,
      );
    }

    if (ro.mainInnerH != null) {
      _drawMainInnerHeights(
        canvas,
        spec,
        ctx,
        rightRef + ro.mainInnerH!,
        textOnLeft: false,
      );
    }
  }

  static void _drawMainInnerHeights(
    Canvas canvas,
    ShapeSpec spec,
    _MeasureContext ctx,
    double x, {
    bool textOnLeft = true,
  }) {
    final lines =
        spec.internalElements
            .where((e) => e.type == InternalElementType.horizontalLine)
            .map((e) => e.position.dy)
            .toList()
          ..sort((a, b) => b.compareTo(a));
    if (lines.isEmpty) return;
    for (final seg in _buildHeightSegments(spec, lines)) {
      final y1 = ctx.mmToPx(Offset(0, seg.y1), ctx.scale, ctx.offset).dy;
      final y2 = ctx.mmToPx(Offset(0, seg.y2), ctx.scale, ctx.offset).dy;
      _drawHDimLine(canvas, x, y1, y2, seg.label, textOnLeft: textOnLeft);
    }
  }

  /// 🆕 Yan panel iç yatay çizgilerin oluşturduğu yükseklik segmentlerini çizer.
  ///
  /// Panel üst kenarı = mainTopPx'e hizalı.
  /// Yerel Y=0 (panel alt) → panelTopPx + attach.height * scale
  /// Yerel Y=attach.height (panel üst) → panelTopPx
  static void _drawSidePanelInnerHeights(
    Canvas canvas,
    SideAttachment attach,
    _MeasureContext ctx,
    double x, {
    bool textOnLeft = true,
  }) {
    // Ana şekildeki _drawMainInnerHeights gibi TÜM yatay çizgileri
    // (kısa dahil) sayar — kısa çizgiler de Y seviyesi segmenti oluşturur.
    final hLines =
        attach.internalElements
            .where((e) => e.type == InternalElementType.horizontalLine)
            .map((e) => e.position.dy)
            .toList()
          ..sort((a, b) => b.compareTo(a)); // büyükten küçüğe (üstten alta)

    if (hLines.isEmpty) return;

    final panelTopPx = ctx.mainTopPx;
    // Yerel Y → piksel Y dönüşümü (panel üst hizalı)
    double localYToPx(double ly) =>
        panelTopPx + (attach.height - ly) * ctx.scale;

    // Segment listesi: [attach.height, line1, line2, ..., 0]
    final ys = <double>[attach.height, ...hLines, 0];
    for (int i = 0; i < ys.length - 1; i++) {
      final segH = ys[i] - ys[i + 1];
      if (segH <= 0) continue;
      final y1Px = localYToPx(ys[i]);
      final y2Px = localYToPx(ys[i + 1]);
      _drawHDimLine(
        canvas,
        x,
        y1Px,
        y2Px,
        '${segH.round()}',
        textOnLeft: textOnLeft,
      );
    }
  }

  static void _drawWidthSystem(
    Canvas canvas,
    ShapeSpec spec,
    _MeasureContext ctx,
  ) {
    final topPx = ctx.mainTopPx;
    final botPx = ctx.mainBottomPx;
    final mainWidthOff = ctx.hasMainInnerV ? _kBase + _kStep : _kBase;
    final mainWidthY = botPx + mainWidthOff;

    _drawWDimLine(
      canvas,
      ctx.mainLeftPx,
      ctx.mainRightPx,
      mainWidthY,
      '${spec.baseWidth.toInt()}',
    );

    if (ctx.hasMainInnerV) {
      _drawMainInnerWidths(canvas, spec, ctx, botPx + _kBase);
    }

    if (ctx.leftAttach != null) {
      final panelBotPx = topPx + ctx.leftAttach!.height * ctx.scale;
      // Collision: panel alt kenarı main alt kenarına çok yakın → total çizgisi kayar
      // Segment çizgisi her zaman @kBase (+15), sadece total etkilenir
      final collision =
          ctx.hasMainInnerV && (panelBotPx - botPx).abs() < _kStep;
      final hasInnerV = ctx.hasLeftInnerV;
      // Total: iç V var veya collision → +kBase+kStep (+35), yoksa +kBase (+15)
      final panelWidthY =
          panelBotPx + ((hasInnerV || collision) ? _kBase + _kStep : _kBase);
      _drawWDimLine(
        canvas,
        ctx.leftmostPx,
        ctx.mainLeftPx,
        panelWidthY,
        '${ctx.leftAttach!.width.toInt()}',
      );
      if (hasInnerV) {
        _drawSidePanelInnerWidths(
          canvas,
          ctx.leftAttach!,
          ctx,
          panelBotPx + _kBase, // segment her zaman +kBase
          ctx.leftmostPx,
        );
      }
    }

    if (ctx.rightAttach != null) {
      final panelBotPx = topPx + ctx.rightAttach!.height * ctx.scale;
      final collision =
          ctx.hasMainInnerV && (panelBotPx - botPx).abs() < _kStep;
      final hasInnerV = ctx.hasRightInnerV;
      final panelWidthY =
          panelBotPx + ((hasInnerV || collision) ? _kBase + _kStep : _kBase);
      _drawWDimLine(
        canvas,
        ctx.mainRightPx,
        ctx.rightmostPx,
        panelWidthY,
        '${ctx.rightAttach!.width.toInt()}',
      );
      if (hasInnerV) {
        _drawSidePanelInnerWidths(
          canvas,
          ctx.rightAttach!,
          ctx,
          panelBotPx + _kBase, // segment her zaman +kBase
          ctx.mainRightPx,
        );
      }
    }
  }

  static void _drawMainInnerWidths(
    Canvas canvas,
    ShapeSpec spec,
    _MeasureContext ctx,
    double y,
  ) {
    final lines =
        spec.internalElements
            .where((e) => e.type == InternalElementType.verticalLine)
            .map((e) => e.position.dx)
            .toList()
          ..sort();
    if (lines.isEmpty) return;
    for (final seg in _buildWidthSegments(spec, lines)) {
      _drawWDimLine(
        canvas,
        ctx.mainLeftPx + seg.x1 * ctx.scale,
        ctx.mainLeftPx + seg.x2 * ctx.scale,
        y,
        seg.label,
      );
    }
  }

  /// 🆕 Yan panel iç dikey çizgilerin oluşturduğu genişlik segmentlerini çizer.
  ///
  /// Panel-yerel X=0 → panelLeftPx, X=attach.width → panelRightPx.
  static void _drawSidePanelInnerWidths(
    Canvas canvas,
    SideAttachment attach,
    _MeasureContext ctx,
    double y,
    double panelLeftPx,
  ) {
    // TÜM dikey çizgileri (kısa dahil) sayar.
    final vLines =
        attach.internalElements
            .where((e) => e.type == InternalElementType.verticalLine)
            .map((e) => e.position.dx)
            .toList()
          ..sort();

    if (vLines.isEmpty) return;

    // Segment listesi: [0, line1, line2, ..., width]
    final xs = <double>[0, ...vLines, attach.width];
    for (int i = 0; i < xs.length - 1; i++) {
      final segW = xs[i + 1] - xs[i];
      if (segW <= 0) continue;
      _drawWDimLine(
        canvas,
        panelLeftPx + xs[i] * ctx.scale,
        panelLeftPx + xs[i + 1] * ctx.scale,
        y,
        '${segW.round()}',
      );
    }
  }

  static void _drawInternalLineDimensions(
    Canvas canvas,
    ShapeSpec spec,
    _MeasureContext ctx,
  ) {
    for (final e in spec.internalElements) {
      if (e.type == InternalElementType.horizontalLine) {
        final lineY = e.position.dy;
        final isShort = e.properties['isShort'] == true;
        final xL = isShort
            ? e.position.dx
            : ShapeCropGeometry.leftXAtY(spec, lineY);
        final xR = isShort
            ? e.position.dx + e.size.width
            : ShapeCropGeometry.rightXAtY(spec, lineY);
        final w = xR - xL;
        if (w <= 10 || (w - spec.baseWidth).abs() < 5.0) continue;
        final sL = ctx.mmToPx(Offset(xL, lineY), ctx.scale, ctx.offset);
        final sR = ctx.mmToPx(Offset(xR, lineY), ctx.scale, ctx.offset);
        PainterHelpers.drawLineLabel(
          canvas,
          Offset((sL.dx + sR.dx) / 2, sL.dy),
          '${w.toInt()}',
          isHorizontal: true,
          style: PainterHelpers.labelStyleOnLine(),
        );
      } else if (e.type == InternalElementType.verticalLine) {
        final lineX = e.position.dx;
        final isShort = e.properties['isShort'] == true;
        final yT = isShort
            ? e.position.dy
            : ShapeCropGeometry.topYAtX(spec, lineX);
        final yB = isShort
            ? e.position.dy - e.size.height
            : ShapeCropGeometry.bottomYAtX(spec, lineX);
        final h = yT - yB;
        if (h <= 10 || (h - spec.baseHeight).abs() < 5.0) continue;
        final sT = ctx.mmToPx(Offset(lineX, yT), ctx.scale, ctx.offset);
        final sB = ctx.mmToPx(Offset(lineX, yB), ctx.scale, ctx.offset);
        PainterHelpers.drawLineLabel(
          canvas,
          Offset(sT.dx, (sT.dy + sB.dy) / 2),
          '${h.toInt()}',
          isHorizontal: false,
          style: PainterHelpers.labelStyleOnLine(),
        );
      }
    }
  }

  /// 🆕 Yan panel iç çizgilerinin uzunluk etiketlerini çizginin üzerine çizer.
  /// Ana şekildeki `_drawInternalLineDimensions`'ın yan panel karşılığı.
  ///
  /// Yatay çizgi → genişliğini yatay etiketle,
  /// Dikey çizgi → yüksekliğini dikey etiketle gösterir.
  static void _drawSidePanelInternalLineDimensions(
    Canvas canvas,
    _MeasureContext ctx,
  ) {
    final panels = <SideAttachment?>[ctx.leftAttach, ctx.rightAttach];

    for (final attach in panels) {
      if (attach == null) continue;

      // Panel sol kenarı px
      final panelLeftPx = attach.side == 'left'
          ? ctx.leftmostPx
          : ctx.mainRightPx;

      // Yerel koordinat → piksel dönüşümleri
      double localXToPx(double lx) => panelLeftPx + lx * ctx.scale;
      double localYToPx(double ly) =>
          ctx.mainTopPx + (attach.height - ly) * ctx.scale;

      for (final e in attach.internalElements) {
        if (e.type == InternalElementType.horizontalLine) {
          // ── Yatay çizgi: genişlik etiketi ──
          final xL = e.position.dx;
          final xR = e.position.dx + e.size.width;
          final w = xR - xL;
          // Çok kısa veya panel tam genişliğine çok yakınsa atla
          if (w <= 10 || (w - attach.width).abs() < 5.0) continue;

          final pxL = localXToPx(xL);
          final pxR = localXToPx(xR);
          final pxY = localYToPx(e.position.dy);
          PainterHelpers.drawLineLabel(
            canvas,
            Offset((pxL + pxR) / 2, pxY),
            '${w.toInt()}',
            isHorizontal: true,
            style: PainterHelpers.labelStyleOnLine(),
          );
        } else if (e.type == InternalElementType.verticalLine) {
          // ── Dikey çizgi: yükseklik etiketi ──
          final yT = e.position.dy;
          final yB = e.position.dy - e.size.height;
          final h = yT - yB;
          if (h <= 10 || (h - attach.height).abs() < 5.0) continue;

          final pxX = localXToPx(e.position.dx);
          final pxT = localYToPx(yT);
          final pxB = localYToPx(yB);
          PainterHelpers.drawLineLabel(
            canvas,
            Offset(pxX, (pxT + pxB) / 2),
            '${h.toInt()}',
            isHorizontal: false,
            style: PainterHelpers.labelStyleOnLine(),
          );
        }
      }
    }
  }

  static void drawDimensions(
    Canvas canvas,
    ShapeSpec spec,
    List<Offset> pointsPx,
  ) {
    if (pointsPx.length < 8) return;
    final leftEdgeMm = spec.baseHeight - spec.topLeftY - spec.bottomLeftY;
    final topEdgeMm = spec.baseWidth - spec.topLeftX - spec.topRightX;
    final rightEdgeMm = spec.baseHeight - spec.topRightY - spec.bottomRightY;
    final bottomEdgeMm = spec.baseWidth - spec.bottomRightX - spec.bottomLeftX;

    if ((spec.topLeftY > 0 || spec.bottomLeftY > 0) && leftEdgeMm > 0) {
      PainterHelpers.drawEdgeLabel(
        canvas,
        pointsPx[1],
        pointsPx[7],
        '${leftEdgeMm.toInt()}',
        true,
      );
    }
    if ((spec.topLeftX > 0 || spec.topRightX > 0) && topEdgeMm > 0) {
      PainterHelpers.drawEdgeLabel(
        canvas,
        pointsPx[0],
        pointsPx[2],
        '${topEdgeMm.toInt()}',
        false,
      );
    }
    if ((spec.topRightY > 0 || spec.bottomRightY > 0) && rightEdgeMm > 0) {
      PainterHelpers.drawEdgeLabel(
        canvas,
        pointsPx[3],
        pointsPx[4],
        '${rightEdgeMm.toInt()}',
        true,
      );
    }
    if ((spec.bottomLeftX > 0 || spec.bottomRightX > 0) && bottomEdgeMm > 0) {
      PainterHelpers.drawEdgeLabel(
        canvas,
        pointsPx[6],
        pointsPx[5],
        '${bottomEdgeMm.toInt()}',
        false,
      );
    }

    _drawDiagonalIfNeeded(
      canvas,
      spec.topLeftX,
      spec.topLeftY,
      pointsPx[0],
      pointsPx[1],
    );
    _drawDiagonalIfNeeded(
      canvas,
      spec.topRightX,
      spec.topRightY,
      pointsPx[2],
      pointsPx[3],
    );
    _drawDiagonalIfNeeded(
      canvas,
      spec.bottomRightX,
      spec.bottomRightY,
      pointsPx[4],
      pointsPx[5],
    );
    _drawDiagonalIfNeeded(
      canvas,
      spec.bottomLeftX,
      spec.bottomLeftY,
      pointsPx[6],
      pointsPx[7],
    );
  }

  static void _drawHDimLine(
    Canvas canvas,
    double x,
    double topPx,
    double bottomPx,
    String label, {
    bool textOnLeft = true,
  }) {
    PainterHelpers.drawLeaderLine(
      canvas,
      Offset(x, topPx),
      Offset(x, bottomPx),
    );
    PainterHelpers.drawTickMarks(canvas, x, topPx, x, bottomPx);
    final midY = (topPx + bottomPx) / 2;
    final val = double.tryParse(label) ?? 0;
    if (textOnLeft) {
      if (val > 99) {
        PainterHelpers.drawVerticalText(canvas, x - 7, midY, label);
      } else {
        PainterHelpers.drawHorizontalText(canvas, x - 3, midY, label);
      }
    } else {
      if (val > 99) {
        PainterHelpers.drawVerticalText(canvas, x + 7, midY, label);
      } else {
        final tp = TextPainter(
          text: TextSpan(text: label, style: PainterHelpers.labelStyle()),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + 4, midY - tp.height / 2));
      }
    }
  }

  static void _drawWDimLine(
    Canvas canvas,
    double leftPx,
    double rightPx,
    double y,
    String label,
  ) {
    final paint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 1;
    canvas.drawLine(Offset(leftPx, y - 5), Offset(leftPx, y + 5), paint);
    canvas.drawLine(Offset(rightPx, y - 5), Offset(rightPx, y + 5), paint);
    canvas.drawLine(Offset(leftPx, y), Offset(rightPx, y), paint);
    PainterHelpers.drawLineLabel(
      canvas,
      Offset((leftPx + rightPx) / 2, y + 7),
      label,
      isHorizontal: true,
    );
  }

  static void _drawDiagonalIfNeeded(
    Canvas canvas,
    double dx,
    double dy,
    Offset p1,
    Offset p2,
  ) {
    if (dx <= 0 && dy <= 0) return;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d > 0) PainterHelpers.drawDiagonalLabel(canvas, p1, p2, '${d.toInt()}');
  }

  static List<_HeightSegment> _buildHeightSegments(
    ShapeSpec spec,
    List<double> lines,
  ) {
    final segs = <_HeightSegment>[];
    double used = 0;
    final topGap = spec.baseHeight - lines.first;
    used += topGap;
    segs.add(
      _HeightSegment(y1: spec.baseHeight, y2: lines.first, heightMm: topGap),
    );
    for (int i = 0; i < lines.length - 1; i++) {
      final h = lines[i] - lines[i + 1];
      used += h;
      segs.add(_HeightSegment(y1: lines[i], y2: lines[i + 1], heightMm: h));
    }
    segs.add(
      _HeightSegment(y1: lines.last, y2: 0, heightMm: spec.baseHeight - used),
    );
    return segs;
  }

  static List<_WidthSegment> _buildWidthSegments(
    ShapeSpec spec,
    List<double> lines,
  ) {
    final segs = <_WidthSegment>[];
    double used = 0;
    if (lines.first > 0.5) {
      used += lines.first;
      segs.add(_WidthSegment(x1: 0, x2: lines.first));
    }
    for (int i = 0; i < lines.length - 1; i++) {
      final w = lines[i + 1] - lines[i];
      used += w;
      segs.add(_WidthSegment(x1: lines[i], x2: lines[i + 1]));
    }
    final rg = spec.baseWidth - used;
    if (rg > 0.5) segs.add(_WidthSegment(x1: lines.last, x2: spec.baseWidth));
    return segs;
  }
}

class _MeasureContext {
  final ShapeSpec spec;
  final SideAttachment? leftAttach;
  final SideAttachment? rightAttach;
  final bool hasMainInnerH;
  final bool hasMainInnerV;
  final bool hasLeftInnerH;
  final bool hasRightInnerH;
  final bool hasLeftInnerV;
  final bool hasRightInnerV;
  final double scale;
  final Offset offset;
  final MmToPx mmToPx;
  final double leftmostPx;
  final double rightmostPx;
  final double mainLeftPx;
  final double mainRightPx;
  final double mainTopPx;
  final double mainBottomPx;

  _MeasureContext._({
    required this.spec,
    required this.leftAttach,
    required this.rightAttach,
    required this.hasMainInnerH,
    required this.hasMainInnerV,
    required this.hasLeftInnerH,
    required this.hasRightInnerH,
    required this.hasLeftInnerV,
    required this.hasRightInnerV,
    required this.scale,
    required this.offset,
    required this.mmToPx,
    required this.leftmostPx,
    required this.rightmostPx,
    required this.mainLeftPx,
    required this.mainRightPx,
    required this.mainTopPx,
    required this.mainBottomPx,
  });

  factory _MeasureContext.from(
    ShapeSpec spec,
    List<SideAttachment> attachments,
    double scale,
    Offset offset,
    MmToPx mmToPx,
    List<Offset> pointsPx,
  ) {
    SideAttachment? leftAttach, rightAttach;
    for (final a in attachments) {
      if (a.side == 'left') {
        leftAttach = a;
      } else if (a.side == 'right')
        rightAttach = a;
    }
    final hasMainInnerH = spec.internalElements.any(
      (e) => e.type == InternalElementType.horizontalLine,
    );
    final hasMainInnerV = spec.internalElements.any(
      (e) => e.type == InternalElementType.verticalLine,
    );
    final hasLeftInnerH =
        leftAttach?.internalElements.any(
          (e) => e.type == InternalElementType.horizontalLine,
        ) ??
        false;
    final hasRightInnerH =
        rightAttach?.internalElements.any(
          (e) => e.type == InternalElementType.horizontalLine,
        ) ??
        false;
    final hasLeftInnerV =
        leftAttach?.internalElements.any(
          (e) => e.type == InternalElementType.verticalLine,
        ) ??
        false;
    final hasRightInnerV =
        rightAttach?.internalElements.any(
          (e) => e.type == InternalElementType.verticalLine,
        ) ??
        false;

    final mainTopPx = pointsPx.map((p) => p.dy).reduce(math.min);
    final mainBottomPx = pointsPx.map((p) => p.dy).reduce(math.max);
    final mainLeftPx = mmToPx(Offset(0, 0), scale, offset).dx;
    final mainRightPx = mmToPx(Offset(spec.baseWidth, 0), scale, offset).dx;

    final leftmostPx = leftAttach != null
        ? mmToPx(Offset(-leftAttach.width, 0), scale, offset).dx
        : pointsPx.map((p) => p.dx).reduce(math.min);
    final rightmostPx = rightAttach != null
        ? mmToPx(
            Offset(spec.baseWidth + rightAttach.width, 0),
            scale,
            offset,
          ).dx
        : pointsPx.map((p) => p.dx).reduce(math.max);

    return _MeasureContext._(
      spec: spec,
      leftAttach: leftAttach,
      rightAttach: rightAttach,
      hasMainInnerH: hasMainInnerH,
      hasMainInnerV: hasMainInnerV,
      hasLeftInnerH: hasLeftInnerH,
      hasRightInnerH: hasRightInnerH,
      hasLeftInnerV: hasLeftInnerV,
      hasRightInnerV: hasRightInnerV,
      scale: scale,
      offset: offset,
      mmToPx: mmToPx,
      leftmostPx: leftmostPx,
      rightmostPx: rightmostPx,
      mainLeftPx: mainLeftPx,
      mainRightPx: mainRightPx,
      mainTopPx: mainTopPx,
      mainBottomPx: mainBottomPx,
    );
  }

  bool get leftSameHeight =>
      leftAttach != null && (leftAttach!.height - spec.baseHeight).abs() < 1.0;
  bool get rightSameHeight =>
      rightAttach != null &&
      (rightAttach!.height - spec.baseHeight).abs() < 1.0;

  _LeftOffsets get leftOffsets {
    const b = _kBase;
    const s = _kStep;

    // ── Sol panel yok → sadece ana şekil ölçüleri solda ──
    if (leftAttach == null) {
      if (!hasMainInnerH) return _LeftOffsets(mainExt: b);
      return _LeftOffsets(mainInnerH: b, mainExt: b + s);
    }

    // ── Sol panel var, AYNI yükseklik ──
    if (leftSameHeight) {
      if (rightAttach == null) {
        // Sağ taraf boş → mainInnerH sağa taşınır, sol sadece panel ölçüleri
        // 2a: iç H yok → leftExt @15 (değişmez)
        // 2b: ana iç H var, sol iç H yok → leftExt @15 (mainInnerH sağa)
        // 2c: her ikisinde iç H → leftInnerH @15, leftExt @35 (mainInnerH sağa)
        // 2d: sadece sol iç H → leftInnerH @15, leftExt @35 (değişmez)
        if (!hasLeftInnerH) return _LeftOffsets(leftExt: b);
        return _LeftOffsets(leftInnerH: b, leftExt: b + s);
      }
      // Sağ panel var → hepsi solda (mevcut davranış)
      if (!hasMainInnerH && !hasLeftInnerH) return _LeftOffsets(leftExt: b);
      if (hasMainInnerH && !hasLeftInnerH) {
        return _LeftOffsets(mainInnerH: b, leftExt: b + s);
      }
      if (hasMainInnerH && hasLeftInnerH) {
        return _LeftOffsets(
          mainInnerH: b,
          leftInnerH: b + s,
          leftExt: b + 2 * s,
        );
      }
      return _LeftOffsets(leftInnerH: b, leftExt: b + s);
    }

    // ── Sol panel var, FARKLI yükseklik ──
    if (rightAttach == null) {
      // Sağ taraf boş → mainExt/mainInnerH sağa taşınır
      // 3a: leftExt @15 (mainExt sağa)
      // 3b: leftExt @15 (mainInnerH + mainExt sağa)
      // 3c: leftInnerH @15, leftExt @35 (mainInnerH + mainExt sağa)
      // 3d: leftInnerH @15, leftExt @35 (mainExt sağa)
      if (!hasLeftInnerH) return _LeftOffsets(leftExt: b);
      return _LeftOffsets(leftInnerH: b, leftExt: b + s);
    }
    // Sağ panel var → ana ölçüler en yakın, panel ölçüleri en dışta
    // 3a: leftExt @15, mainExt @35
    if (!hasMainInnerH && !hasLeftInnerH) {
      return _LeftOffsets(mainExt: b, leftExt: b + s);
    }
    // 3b: mainInnerH @15, mainExt @35, leftExt @55
    if (hasMainInnerH && !hasLeftInnerH) {
      return _LeftOffsets(mainInnerH: b, mainExt: b + s, leftExt: b + 2 * s);
    }
    // 3c: mainInnerH @15, mainExt @35, leftInnerH @55, leftExt @75
    if (hasMainInnerH && hasLeftInnerH) {
      return _LeftOffsets(
        mainInnerH: b,
        mainExt: b + s,
        leftInnerH: b + 2 * s,
        leftExt: b + 3 * s,
      );
    }
    // 3d: mainExt @15, leftInnerH @35, leftExt @55
    return _LeftOffsets(mainExt: b, leftInnerH: b + s, leftExt: b + 2 * s);
  }

  _RightOffsets get rightOffsets {
    const b = _kBase;
    const s = _kStep;

    if (rightAttach == null) {
      // 🆕 Sol panel varken sağ boşsa, ana şekil ölçüleri sağa taşınır
      if (leftAttach != null) {
        if (!hasMainInnerH) return _RightOffsets(mainExt: b);
        return _RightOffsets(mainInnerH: b, mainExt: b + s);
      }
      return _RightOffsets();
    }

    // Sağ panel var
    if (rightSameHeight) {
      // Sen.5: İç yatay çizgi varsa hem iç ölçü hem dış yükseklik gerekli.
      // Sen.4: İç çizgi yoksa ana şekil yüksekliği zaten sol tarafta çizili.
      if (hasRightInnerH) return _RightOffsets(rightInnerH: b, rightExt: b + s);
      return _RightOffsets();
    }
    if (!hasRightInnerH) return _RightOffsets(rightExt: b);
    return _RightOffsets(rightInnerH: b, rightExt: b + s);
  }
}

class _LeftOffsets {
  final double? mainExt, mainInnerH, leftExt, leftInnerH;
  const _LeftOffsets({
    this.mainExt,
    this.mainInnerH,
    this.leftExt,
    this.leftInnerH,
  });
}

class _RightOffsets {
  final double? rightExt, rightInnerH;
  // 🆕 Sağda panel yokken ana şekil ölçüleri sağa taşınırsa kullanılır
  final double? mainExt, mainInnerH;
  const _RightOffsets({
    this.rightExt,
    this.rightInnerH,
    this.mainExt,
    this.mainInnerH,
  });
}

class _HeightSegment {
  final double y1, y2, heightMm;
  _HeightSegment({required this.y1, required this.y2, required this.heightMm});
  String get label => '${heightMm.round()}';
}

class _WidthSegment {
  final double x1, x2;
  _WidthSegment({required this.x1, required this.x2});
  double get widthMm => x2 - x1;
  String get label => '${widthMm.round()}';
}
