// lib/features/drawing/providers/drawing_controller_side_panel.dart
//
// DrawingController üzerine extension — yan panel (SideAttachment) metodları.
// drawing_controller_provider.dart'a dokunmadan yan panel state işlemlerini
// ayrı bir dosyada tutar.
//
// KURULUM:
//   1. drawing_controller_provider.dart içinde DrawingController class'ına
//      şu getter'ı ekle (state'e @protected olmadan erişmek için):
//
//        DrawingControllerState get controllerState => state;
//
//   2. Bu dosyayı import et (kullanıldığı yerde):
//        import 'drawing_controller_side_panel.dart';

import 'dart:ui';

import '../../../models/shape_spec.dart';
import 'drawing_controller_provider.dart';

extension DrawingControllerSidePanel on DrawingController {
  // ─── Temel güncelleme ────────────────────────────────────────────────────────

  /// Belirli bir side'daki SideAttachment'ı spec içinde değiştirir.
  void updateSideAttachment(String side, SideAttachment newAttach) {
    final current = controllerState.currentShape;
    if (current == null) return;

    final updated = current.copyWith(
      sideAttachments: current.sideAttachments
          .map((a) => a.side == side ? newAttach : a)
          .toList(),
    );
    updateShape(controllerState.selectedIndex, updated);
  }

  // ─── Kısa yatay çizgi güncelleme ────────────────────────────────────────────

  /// Yan panel içindeki kısa yatay çizginin Y pozisyonunu günceller.
  /// Hücre sınırları (sol/sağ) attach.internalElements'ten hesaplanır.
  /// Ana şekin aksine crop yoktur — sınırlar her zaman [0, attach.width].
  void updateSideAttachShortHorizontalLine(
    String side,
    String elementId,
    double newY,
  ) {
    final current = controllerState.currentShape;
    if (current == null) return;

    final attach = _getAttach(current, side);
    if (attach == null) return;

    final elIdx = attach.internalElements.indexWhere((e) => e.id == elementId);
    if (elIdx == -1) return;

    final old = attach.internalElements[elIdx];
    if (old.type != InternalElementType.horizontalLine) return;

    // Çizginin orta X noktası → hangi dikey hücrede?
    final midX = old.position.dx + old.size.width / 2;

    // Geçerli dikey çizgileri topla (kısa olanlar için newY'yi kapsıyor mu? kontrol et)
    final verticalXs = <double>[0.0, attach.width];
    for (final e in attach.internalElements) {
      if (e.id == elementId) continue;
      if (e.type != InternalElementType.verticalLine) continue;
      if (e.properties['isShort'] == true) {
        final yTop = e.position.dy;
        final yBot = e.position.dy - e.size.height;
        if (newY > yTop || newY < yBot) continue;
      }
      verticalXs.add(e.position.dx);
    }
    verticalXs.sort();

    double cellLeft = 0, cellRight = attach.width;
    for (final x in verticalXs) {
      if (x < midX) cellLeft = x;
      if (x > midX) {
        cellRight = x;
        break;
      }
    }

    final newWidth = cellRight - cellLeft;
    if (newWidth < 10) return;

    final updated = InternalElement(
      id: old.id,
      type: old.type,
      position: Offset(cellLeft, newY.clamp(0.0, attach.height)),
      size: Size(newWidth, old.size.height),
      rotation: old.rotation,
      properties: old.properties,
    );

    final newElements = List<InternalElement>.from(attach.internalElements);
    newElements[elIdx] = updated;
    updateSideAttachment(side, attach.copyWith(internalElements: newElements));
  }

  // ─── Kısa dikey çizgi güncelleme ────────────────────────────────────────────

  /// Yan panel içindeki kısa dikey çizginin X pozisyonunu günceller.
  void updateSideAttachShortVerticalLine(
    String side,
    String elementId,
    double newX,
  ) {
    final current = controllerState.currentShape;
    if (current == null) return;

    final attach = _getAttach(current, side);
    if (attach == null) return;

    final elIdx = attach.internalElements.indexWhere((e) => e.id == elementId);
    if (elIdx == -1) return;

    final old = attach.internalElements[elIdx];
    if (old.type != InternalElementType.verticalLine) return;

    // Çizginin orta Y noktası → hangi yatay hücrede?
    final midY = old.position.dy - old.size.height / 2;

    final horizontalYs = <double>[0.0, attach.height];
    for (final e in attach.internalElements) {
      if (e.id == elementId) continue;
      if (e.type != InternalElementType.horizontalLine) continue;
      if (e.properties['isShort'] == true) {
        final xLeft = e.position.dx;
        final xRight = e.position.dx + e.size.width;
        if (newX < xLeft || newX > xRight) continue;
      }
      horizontalYs.add(e.position.dy);
    }
    horizontalYs.sort();

    double cellBottom = 0, cellTop = attach.height;
    for (final y in horizontalYs) {
      if (y < midY) cellBottom = y;
      if (y > midY) {
        cellTop = y;
        break;
      }
    }

    final newHeight = cellTop - cellBottom;
    if (newHeight < 10) return;

    final updated = InternalElement(
      id: old.id,
      type: old.type,
      position: Offset(newX.clamp(0.0, attach.width), cellTop),
      size: Size(old.size.width, newHeight),
      rotation: old.rotation,
      properties: old.properties,
    );

    final newElements = List<InternalElement>.from(attach.internalElements);
    newElements[elIdx] = updated;
    updateSideAttachment(side, attach.copyWith(internalElements: newElements));
  }

  // ─── Yardımcı ────────────────────────────────────────────────────────────────

  SideAttachment? _getAttach(ShapeSpec spec, String side) {
    try {
      return spec.sideAttachments.firstWhere((a) => a.side == side);
    } catch (_) {
      return null;
    }
  }
}
