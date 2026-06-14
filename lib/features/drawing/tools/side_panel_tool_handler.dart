// lib/features/drawing/tools/side_panel_tool_handler.dart

import 'package:flutter/material.dart';
import '../../../models/shape_spec.dart';
import '../providers/tool_mode_provider.dart';

/// Yan panel (SideAttachment) üzerine araç ekleme mantığı.
/// Ana şekil koduna hiç dokunmaz.
/// Tüm koordinatlar yerel (panel sol-alt = 0,0) sisteminde saklanır.
class SidePanelToolHandler {
  const SidePanelToolHandler._();

  // ─────────────────────────────────────────
  // ÜÇGen
  // ─────────────────────────────────────────

  /// Yan panelin tamamını kaplayan üçgen ekler.
  /// Zaten varsa üzerine yazar (eski silinir).
  static SideAttachment addTriangle(
    SideAttachment attach,
    TriangleDirection direction,
  ) {
    // Aynı yönde üçgen varsa çıkar
    final filtered = attach.internalElements
        .where(
          (e) =>
              !(e.type == InternalElementType.triangle &&
                  (e.properties['direction'] as String?) == direction.name),
        )
        .toList();

    final element = InternalElement(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: InternalElementType.triangle,
      // Yerel koordinat: sol-alt = (0,0), sol-üst = (0, height)
      position: Offset(0, attach.height),
      size: Size(attach.width, attach.height),
      rotation: 0,
      properties: {'direction': direction.name},
    );

    return attach.copyWith(internalElements: [...filtered, element]);
  }

  // ─────────────────────────────────────────
  // SÜRME OKU
  // ─────────────────────────────────────────

  /// Yan panelde tıklanan alt bölüme sürme oku ekler.
  /// localX/localY: tıklama noktası (panel-yerel mm).
  static SideAttachment addSlideArrow(
    SideAttachment attach,
    String direction, // 'right' | 'left'
    double localX,
    double localY,
  ) {
    final bounds = findSubPanelBounds(attach, localX, localY);

    // Aynı alt bölümde aynı yönde ok varsa üzerine yaz
    final filtered = attach.internalElements
        .where(
          (e) =>
              !(e.type == InternalElementType.slideArrow &&
                  (e.properties['direction'] as String?) == direction &&
                  e.position.dx == bounds['leftX']! &&
                  e.position.dy == bounds['topY']!),
        )
        .toList();

    final element = InternalElement(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: InternalElementType.slideArrow,
      position: Offset(bounds['leftX']!, bounds['topY']!),
      size: Size(
        bounds['rightX']! - bounds['leftX']!,
        bounds['topY']! - bounds['bottomY']!,
      ),
      rotation: 0,
      properties: {'direction': direction},
    );

    return attach.copyWith(internalElements: [...filtered, element]);
  }

  // ─────────────────────────────────────────
  // UZUN YATAY ÇİZGİ
  // ─────────────────────────────────────────

  /// Yan panele tam genişlikte yatay çizgi ekler.
  /// localY: panel alt kenarından itibaren mm (0 = alt, height = üst).
  static SideAttachment addHorizontalLine(
    SideAttachment attach,
    double localY,
  ) {
    // Panel sınırı dışına çıkmasın
    final clampedY = localY.clamp(0.0, attach.height);

    final element = InternalElement(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: InternalElementType.horizontalLine,
      position: Offset(0, clampedY),
      size: Size(attach.width, 2),
      rotation: 0,
      properties: {},
    );

    return attach.copyWith(
      internalElements: [...attach.internalElements, element],
    );
  }

  // ─────────────────────────────────────────
  // UZUN DİKEY ÇİZGİ
  // ─────────────────────────────────────────

  /// Yan panele tam yükseklikte dikey çizgi ekler.
  /// localX: panel sol kenarından itibaren mm.
  static SideAttachment addVerticalLine(SideAttachment attach, double localX) {
    final clampedX = localX.clamp(0.0, attach.width);

    final element = InternalElement(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: InternalElementType.verticalLine,
      position: Offset(clampedX, attach.height),
      size: Size(2, attach.height),
      rotation: 0,
      properties: {},
    );

    return attach.copyWith(
      internalElements: [...attach.internalElements, element],
    );
  }

  // ─────────────────────────────────────────
  // KISA YATAY ÇİZGİ
  // ─────────────────────────────────────────

  /// Yan panele kısa yatay çizgi ekler.
  /// Mevcut dikey çizgilere göre segment bulur.
  static SideAttachment addShortHorizontalLine(
    SideAttachment attach,
    double localX,
    double localY,
  ) {
    final clampedY = localY.clamp(0.0, attach.height);

    // Dikey çizgi x pozisyonlarını topla
    final verticalXs = <double>{0.0, attach.width};
    for (final e in attach.internalElements) {
      if (e.type == InternalElementType.verticalLine) {
        final isShort = e.properties['isShort'] == true;
        if (isShort) {
          // Kısa dikey çizgi bu Y seviyesini kesiyor mu?
          final vTop = e.position.dy;
          final vBot = e.position.dy - e.size.height;
          if (clampedY < vBot || clampedY > vTop) continue;
        }
        verticalXs.add(e.position.dx);
      }
    }
    final sortedXs = verticalXs.toList()..sort();

    // localX'in hangi segmentte olduğunu bul
    double leftBound = 0;
    double rightBound = attach.width;
    for (int i = 0; i < sortedXs.length - 1; i++) {
      if (localX >= sortedXs[i] && localX <= sortedXs[i + 1]) {
        leftBound = sortedXs[i];
        rightBound = sortedXs[i + 1];
        break;
      }
    }

    final element = InternalElement(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: InternalElementType.horizontalLine,
      position: Offset(leftBound, clampedY),
      size: Size(rightBound - leftBound, 2),
      rotation: 0,
      properties: {'isShort': true},
    );

    return attach.copyWith(
      internalElements: [...attach.internalElements, element],
    );
  }

  // ─────────────────────────────────────────
  // KISA DİKEY ÇİZGİ
  // ─────────────────────────────────────────

  /// Yan panele kısa dikey çizgi ekler.
  /// Mevcut yatay çizgilere göre segment bulur.
  static SideAttachment addShortVerticalLine(
    SideAttachment attach,
    double localX,
    double localY,
  ) {
    final clampedX = localX.clamp(0.0, attach.width);

    // Yatay çizgi y pozisyonlarını topla
    final horizontalYs = <double>{0.0, attach.height};
    for (final e in attach.internalElements) {
      if (e.type == InternalElementType.horizontalLine) {
        final isShort = e.properties['isShort'] == true;
        if (isShort) {
          // Kısa yatay çizgi bu X seviyesini kesiyor mu?
          final hLeft = e.position.dx;
          final hRight = e.position.dx + e.size.width;
          if (clampedX < hLeft || clampedX > hRight) continue;
        }
        horizontalYs.add(e.position.dy);
      }
    }
    final sortedYs = horizontalYs.toList()..sort((a, b) => b.compareTo(a));

    // localY'nin hangi segmentte olduğunu bul
    double topBound = attach.height;
    double bottomBound = 0;
    for (int i = 0; i < sortedYs.length - 1; i++) {
      if (localY <= sortedYs[i] && localY >= sortedYs[i + 1]) {
        topBound = sortedYs[i];
        bottomBound = sortedYs[i + 1];
        break;
      }
    }

    final element = InternalElement(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: InternalElementType.verticalLine,
      position: Offset(clampedX, topBound),
      size: Size(2, topBound - bottomBound),
      rotation: 0,
      properties: {'isShort': true},
    );

    return attach.copyWith(
      internalElements: [...attach.internalElements, element],
    );
  }

  // ─────────────────────────────────────────
  // DOT GRİD (Desenli Cam)
  // ─────────────────────────────────────────

  /// Yan panelde tıklanan alt bölüme desenli cam ekler.
  /// Aynı alt bölümde zaten varsa tekrar eklemez.
  /// [returns] null → zaten var, SideAttachment → güncellendi
  static SideAttachment? addDotGrid(
    SideAttachment attach,
    double localX,
    double localY,
  ) {
    final bounds = findSubPanelBounds(attach, localX, localY);

    final alreadyExists = attach.internalElements.any(
      (e) =>
          e.type == InternalElementType.dotGrid &&
          e.position.dx == bounds['leftX']! &&
          e.position.dy == bounds['topY']!,
    );
    if (alreadyExists) return null;

    final element = InternalElement(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: InternalElementType.dotGrid,
      position: Offset(bounds['leftX']!, bounds['topY']!),
      size: Size(
        bounds['rightX']! - bounds['leftX']!,
        bounds['topY']! - bounds['bottomY']!,
      ),
      rotation: 0,
      properties: {},
    );

    return attach.copyWith(
      internalElements: [...attach.internalElements, element],
    );
  }

  // ─────────────────────────────────────────
  // LINE GRİD (Camsız Profil)
  // ─────────────────────────────────────────

  /// Yan panelde tıklanan alt bölüme camsız profil ekler.
  /// Aynı alt bölümde zaten varsa tekrar eklemez.
  /// [returns] null → zaten var, SideAttachment → güncellendi
  static SideAttachment? addLineGrid(
    SideAttachment attach,
    double localX,
    double localY,
  ) {
    final bounds = findSubPanelBounds(attach, localX, localY);

    final alreadyExists = attach.internalElements.any(
      (e) =>
          e.type == InternalElementType.lineGrid &&
          e.position.dx == bounds['leftX']! &&
          e.position.dy == bounds['topY']!,
    );
    if (alreadyExists) return null;

    final element = InternalElement(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: InternalElementType.lineGrid,
      position: Offset(bounds['leftX']!, bounds['topY']!),
      size: Size(
        bounds['rightX']! - bounds['leftX']!,
        bounds['topY']! - bounds['bottomY']!,
      ),
      rotation: 0,
      properties: {},
    );

    return attach.copyWith(
      internalElements: [...attach.internalElements, element],
    );
  }

  // ─────────────────────────────────────────
  // YARDIMCI: Alt bölüm sınırlarını bul
  // ─────────────────────────────────────────

  /// Yan panel içindeki iç çizgilerin oluşturduğu alt bölümü bulur.
  ///
  /// Ana şekildeki `findPanelAtPosition`'ın yan panel karşılığı.
  /// UZUN (tam genişlik/yükseklik) çizgileri sınır kabul eder;
  /// kısa çizgiler bölme oluşturmaz.
  ///
  /// Döndürülen harita: leftX, rightX, bottomY, topY  (panel-yerel mm).
  static Map<String, double> findSubPanelBounds(
    SideAttachment attach,
    double localX,
    double localY,
  ) {
    // ── Dikey çizgi X pozisyonları (sınırlar) ──
    // Uzun dikey çizgiler her zaman dahil.
    // Kısa dikey çizgiler: sadece tıklama Y'sini kapsıyorsa dahil et.
    final verticalXs = <double>{0.0, attach.width};
    for (final e in attach.internalElements) {
      if (e.type == InternalElementType.verticalLine) {
        final isShort = e.properties['isShort'] == true;
        if (isShort) {
          final yTop = e.position.dy;
          final yBot = e.position.dy - e.size.height;
          if (localY < yBot || localY > yTop) continue;
        }
        verticalXs.add(e.position.dx);
      }
    }
    final sortedXs = verticalXs.toList()..sort();

    double leftX = 0, rightX = attach.width;
    for (int i = 0; i < sortedXs.length - 1; i++) {
      if (localX >= sortedXs[i] && localX <= sortedXs[i + 1]) {
        leftX = sortedXs[i];
        rightX = sortedXs[i + 1];
        break;
      }
    }

    // ── Yatay çizgi Y pozisyonları (sınırlar) ──
    // Uzun yatay çizgiler her zaman dahil.
    // Kısa yatay çizgiler: sadece tıklama X'ini kapsıyorsa dahil et.
    final horizontalYs = <double>{0.0, attach.height};
    for (final e in attach.internalElements) {
      if (e.type == InternalElementType.horizontalLine) {
        final isShort = e.properties['isShort'] == true;
        if (isShort) {
          final xLeft = e.position.dx;
          final xRight = e.position.dx + e.size.width;
          if (localX < xLeft || localX > xRight) continue;
        }
        horizontalYs.add(e.position.dy);
      }
    }
    final sortedYs = horizontalYs.toList()..sort();

    double bottomY = 0, topY = attach.height;
    for (int i = 0; i < sortedYs.length - 1; i++) {
      if (localY >= sortedYs[i] && localY <= sortedYs[i + 1]) {
        bottomY = sortedYs[i];
        topY = sortedYs[i + 1];
        break;
      }
    }

    return {'leftX': leftX, 'rightX': rightX, 'bottomY': bottomY, 'topY': topY};
  }

  // ─────────────────────────────────────────
  // YARDIMCI: spec güncelle
  // ─────────────────────────────────────────

  /// Verilen attach'ı spec içinde günceller, yeni spec döner.
  static ShapeSpec updateAttachInSpec(
    ShapeSpec spec,
    String side,
    SideAttachment updatedAttach,
  ) {
    final updatedAttachments = spec.sideAttachments.map((a) {
      return a.side == side ? updatedAttach : a;
    }).toList();
    return spec.copyWith(sideAttachments: updatedAttachments);
  }
}
