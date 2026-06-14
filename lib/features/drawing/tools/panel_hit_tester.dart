import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/shape_spec.dart';

class PanelHitTester {
  /// Ana şekil içinde MM koordinatlarında panel/hücre bulur.
  /// [includeShortLines] true ise kısa çizgiler de sınır olarak kullanılır.
  /// [snapToNearest] true ise en yakın panelin merkezine snap yapar.
  static Map<String, double>? findPanelAtPosition(
    ShapeSpec spec,
    Offset mmPos, {
    bool snapToNearest = false,
    bool includeShortLines = false,
  }) {
    final mmX = mmPos.dx;
    final mmY = mmPos.dy;

    final horizontalLines =
        spec.internalElements
            .where((e) => e.type == InternalElementType.horizontalLine)
            .where((e) {
              if (e.properties['isShort'] != true) return true;
              if (!includeShortLines) return false;
              final xLeft = e.position.dx;
              final xRight = e.position.dx + e.size.width;
              return mmX >= xLeft && mmX <= xRight;
            })
            .map((e) => e.position.dy)
            .toList()
          ..sort((a, b) => b.compareTo(a));

    final verticalLines =
        spec.internalElements
            .where((e) => e.type == InternalElementType.verticalLine)
            .where((e) {
              if (e.properties['isShort'] != true) return true;
              if (!includeShortLines) return false;
              final yTop = e.position.dy;
              final yBottom = e.position.dy - e.size.height;
              return mmY >= yBottom && mmY <= yTop;
            })
            .map((e) => e.position.dx)
            .toList()
          ..sort();

    // Segment sınırları
    List<double> ySegments = [spec.baseHeight, ...horizontalLines, 0.0];
    List<double> xSegments = [0.0, ...verticalLines, spec.baseWidth];

    // Y BELİRSİZLİĞİ GİDERME
    double topY = 0, bottomY = 0;
    bool foundY = false;

    for (int i = 0; i < ySegments.length - 1; i++) {
      final upperBound = ySegments[i];
      final lowerBound = ySegments[i + 1];
      final isLastSegment = i == ySegments.length - 2;

      if (isLastSegment) {
        if (mmY >= lowerBound && mmY <= upperBound) {
          topY = upperBound;
          bottomY = lowerBound;
          foundY = true;
          break;
        }
      } else {
        if (mmY >= lowerBound && mmY < upperBound) {
          topY = upperBound;
          bottomY = lowerBound;
          foundY = true;
          break;
        }
      }
    }

    // X için aynı mantık
    double leftX = 0, rightX = 0;
    bool foundX = false;

    for (int i = 0; i < xSegments.length - 1; i++) {
      final leftBound = xSegments[i];
      final rightBound = xSegments[i + 1];
      final isLastSegment = i == xSegments.length - 2;

      if (isLastSegment) {
        if (mmX >= leftBound && mmX <= rightBound) {
          leftX = leftBound;
          rightX = rightBound;
          foundX = true;
          break;
        }
      } else {
        if (mmX >= leftBound && mmX < rightBound) {
          leftX = leftBound;
          rightX = rightBound;
          foundX = true;
          break;
        }
      }
    }

    // EN YAKIN PANELE SNAP
    if ((!foundY || !foundX) && snapToNearest) {
      double bestDistY = double.infinity;
      int bestY = -1;

      for (int i = 0; i < ySegments.length - 1; i++) {
        final center = (ySegments[i] + ySegments[i + 1]) / 2;
        final d = (mmY - center).abs();
        if (d < bestDistY) {
          bestDistY = d;
          bestY = i;
        }
      }

      double bestDistX = double.infinity;
      int bestX = -1;
      for (int i = 0; i < xSegments.length - 1; i++) {
        final center = (xSegments[i] + xSegments[i + 1]) / 2;
        final d = (mmX - center).abs();
        if (d < bestDistX) {
          bestDistX = d;
          bestX = i;
        }
      }

      if (bestY != -1 && bestX != -1) {
        topY = ySegments[bestY + 1];
        bottomY = ySegments[bestY];
        leftX = xSegments[bestX];
        rightX = xSegments[bestX + 1];
        foundY = foundX = true;
      }
    }

    if (!foundY || !foundX) return null;
    return {'leftX': leftX, 'rightX': rightX, 'topY': topY, 'bottomY': bottomY};
  }

  /// Yan panel (SideAttachment) içinde MM pozisyonunda panel bulur.
  ///
  /// Panel ana şeklin ÜST kenarına hizalıdır.
  /// `_screenToMm` dönüş değeri olan mm koordinat sisteminde:
  ///   mainTopMm  = spec.baseHeight − yShift   (ana şeklin üst kenarı)
  ///   panelTopMm = mainTopMm                  (panel üst = ana üst)
  ///   panelBottomMm = mainTopMm − attach.height
  ///
  /// Eski kodda Y aralığı sabit [0, attach.height] idi; bu yalnızca
  /// attach.height == baseHeight olduğunda doğruydu. Panel yüksekse
  /// alt kısmına tıklanınca isabet algılanamıyordu.
  static Map<String, dynamic>? findSidePanelAtPosition(
    ShapeSpec spec,
    Offset mmPos,
  ) {
    final bounds = spec.boundingSize;
    final xShift = (spec.baseWidth - bounds.width) / 2;
    final yShift = (spec.baseHeight - bounds.height) / 2;
    final mainLeft = xShift;
    final mainRight = xShift + bounds.width;
    final mainTopMm = spec.baseHeight - yShift;

    for (final attach in spec.sideAttachments) {
      // Panel Y aralığı (mm, _screenToMm koordinatı)
      final panelTopMm = mainTopMm;
      final panelBottomMm = mainTopMm - attach.height;

      if (attach.side == 'left') {
        final panelLeft = mainLeft - attach.width;
        final panelRight = mainLeft;
        if (mmPos.dx >= panelLeft &&
            mmPos.dx <= panelRight &&
            mmPos.dy >= panelBottomMm &&
            mmPos.dy <= panelTopMm) {
          return {
            'side': 'left',
            'attach': attach,
            'localX': mmPos.dx - panelLeft,
            'localY': mmPos.dy - panelBottomMm, // 0 = panel alt, height = üst
          };
        }
      } else if (attach.side == 'right') {
        final panelLeft = mainRight;
        final panelRight = mainRight + attach.width;
        if (mmPos.dx >= panelLeft &&
            mmPos.dx <= panelRight &&
            mmPos.dy >= panelBottomMm &&
            mmPos.dy <= panelTopMm) {
          return {
            'side': 'right',
            'attach': attach,
            'localX': mmPos.dx - panelLeft,
            'localY': mmPos.dy - panelBottomMm,
          };
        }
      }
    }
    return null;
  }
}
