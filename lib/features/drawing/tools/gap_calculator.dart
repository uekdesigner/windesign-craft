// lib/features/drawing/tools/gap_calculator.dart

import 'dart:ui';

import '../../../models/shape_spec.dart';
import '../providers/drawing_controller_provider.dart';
import '../geometry/shape_crop_geometry.dart';

class GapCalculator {
  // ═══════════════════════════════════════════════════════════════════
  // ANA ŞEKIL — ShapeSpec tabanlı metodlar (mevcut, değişmedi)
  // ═══════════════════════════════════════════════════════════════════

  /// Yatay çizgiler için gap hesapla (üstten alta)
  static List<double> calculateGaps(
    ShapeSpec spec,
    List<InternalElement> lines,
  ) {
    return calculateGapsFromSize(spec.baseHeight, lines);
  }

  /// Dikey çizgiler için gap hesapla (soldan sağa)
  static List<double> calculateVerticalGaps(
    ShapeSpec spec,
    List<InternalElement> lines,
  ) {
    return calculateVerticalGapsFromSize(spec.baseWidth, lines);
  }

  /// Yeni gap'leri yatay çizgilere uygula (alttan üste)
  static void applyNewGaps(
    DrawingController controller,
    List<InternalElement> lines,
    List<double> newGaps,
  ) {
    lines.sort((a, b) => b.position.dy.compareTo(a.position.dy));
    double currentY = 0;

    for (int i = lines.length - 1; i >= 0; i--) {
      currentY += newGaps[i + 1];
      controller.updateHorizontalLineY(lines[i].id, currentY);
    }
  }

  /// Yeni gap'leri dikey çizgilere uygula (soldan sağa)
  static void applyNewVerticalGaps(
    DrawingController controller,
    List<InternalElement> lines,
    List<double> newGaps,
  ) {
    double currentX = 0;
    for (int i = 0; i < lines.length; i++) {
      currentX += newGaps[i];
      controller.updateVerticalLineX(lines[i].id, currentX);
    }
  }

  /// Gap'lerden yatay çizgi pozisyonları oluştur ve ekle
  static void createHorizontalLinesFromGaps(
    DrawingController controller,
    ShapeSpec spec,
    List<double> gaps,
  ) {
    double currentY = 0;
    final positions = <double>[];

    for (int i = gaps.length - 1; i > 0; i--) {
      currentY += gaps[i];
      positions.add(currentY);
    }

    for (final yPos in positions) {
      final xLeft = ShapeCropGeometry.leftXAtY(spec, yPos);
      final xRight = ShapeCropGeometry.rightXAtY(spec, yPos);

      final newElement = InternalElement(
        id: '${DateTime.now().millisecondsSinceEpoch}_$yPos',
        type: InternalElementType.horizontalLine,
        position: Offset(xLeft, yPos),
        size: Size(xRight - xLeft, 2),
        rotation: 0,
        properties: {},
      );

      controller.addInternalElement(newElement);
    }
  }

  /// Gap'lerden dikey çizgi pozisyonları oluştur ve ekle
  static void createVerticalLinesFromGaps(
    DrawingController controller,
    ShapeSpec spec,
    List<double> gaps,
  ) {
    double currentX = 0;
    final positions = <double>[];

    for (int i = 0; i < gaps.length - 1; i++) {
      currentX += gaps[i];
      positions.add(currentX);
    }

    for (final xPos in positions) {
      final yTop = ShapeCropGeometry.topYAtX(spec, xPos);
      final yBottom = ShapeCropGeometry.bottomYAtX(spec, xPos);

      final newElement = InternalElement(
        id: '${DateTime.now().millisecondsSinceEpoch}_$xPos',
        type: InternalElementType.verticalLine,
        position: Offset(xPos, yTop),
        size: Size(2, yTop - yBottom),
        rotation: 0,
        properties: {},
      );

      controller.addInternalElement(newElement);
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // GENEL — totalSize tabanlı metodlar (ana şekil + yan panel paylaşır)
  // ═══════════════════════════════════════════════════════════════════

  /// Yatay gap hesapla — ShapeSpec bağımsız, totalSize alır.
  /// Ana şekil ve SideAttachment paylaşır.
  static List<double> calculateGapsFromSize(
    double totalSize,
    List<InternalElement> lines,
  ) {
    final normalLines = lines
        .where((l) => l.properties['isShort'] != true)
        .toList();

    if (normalLines.isEmpty) {
      return [totalSize];
    }

    final gaps = <double>[];
    normalLines.sort((a, b) => b.position.dy.compareTo(a.position.dy));

    // Üst boşluk
    gaps.add(totalSize - normalLines.first.position.dy);

    // Paneller arası
    for (int i = 0; i < normalLines.length - 1; i++) {
      gaps.add(normalLines[i].position.dy - normalLines[i + 1].position.dy);
    }

    // Alt boşluk
    gaps.add(normalLines.last.position.dy);

    return gaps;
  }

  /// Dikey gap hesapla — ShapeSpec bağımsız, totalSize alır.
  static List<double> calculateVerticalGapsFromSize(
    double totalSize,
    List<InternalElement> lines,
  ) {
    final normalLines = lines
        .where((l) => l.properties['isShort'] != true)
        .toList();

    if (normalLines.isEmpty) {
      return [totalSize];
    }

    final gaps = <double>[];
    normalLines.sort((a, b) => a.position.dx.compareTo(b.position.dx));

    // Sol boşluk
    gaps.add(normalLines.first.position.dx);

    // Paneller arası
    for (int i = 0; i < normalLines.length - 1; i++) {
      gaps.add(normalLines[i + 1].position.dx - normalLines[i].position.dx);
    }

    // Sağ boşluk
    gaps.add(totalSize - normalLines.last.position.dx);

    return gaps;
  }

  // ═══════════════════════════════════════════════════════════════════
  // YAN PANEL (SideAttachment) — gap uygulama / çizgi oluşturma
  // Controller yerine güncellenmiş SideAttachment döndürür.
  // ═══════════════════════════════════════════════════════════════════

  /// Yatay gap'leri SideAttachment içindeki uzun çizgilere uygula.
  /// Yeni pozisyonları hesaplar, güncellenmiş SideAttachment döner.
  static SideAttachment applyGapsToAttachment(
    SideAttachment attach,
    List<InternalElement> longLines, // isShort != true olan H çizgiler
    List<double> newGaps,
  ) {
    final sorted = [...longLines]
      ..sort((a, b) => b.position.dy.compareTo(a.position.dy));

    // Yeni Y pozisyonları: alttan üste hesapla
    final Map<String, double> newYs = {};
    double currentY = 0;
    for (int i = sorted.length - 1; i >= 0; i--) {
      currentY += newGaps[i + 1];
      newYs[sorted[i].id] = currentY;
    }

    final newElements = attach.internalElements.map((e) {
      if (e.type == InternalElementType.horizontalLine &&
          e.properties['isShort'] != true &&
          newYs.containsKey(e.id)) {
        return InternalElement(
          id: e.id,
          type: e.type,
          position: Offset(0, newYs[e.id]!),
          size: Size(attach.width, e.size.height),
          rotation: e.rotation,
          properties: e.properties,
        );
      }
      return e;
    }).toList();

    return attach.copyWith(internalElements: newElements);
  }

  /// Dikey gap'leri SideAttachment içindeki uzun çizgilere uygula.
  static SideAttachment applyVerticalGapsToAttachment(
    SideAttachment attach,
    List<InternalElement> longLines, // isShort != true olan V çizgiler
    List<double> newGaps,
  ) {
    final sorted = [...longLines]
      ..sort((a, b) => a.position.dx.compareTo(b.position.dx));

    final Map<String, double> newXs = {};
    double currentX = 0;
    for (int i = 0; i < sorted.length; i++) {
      currentX += newGaps[i];
      newXs[sorted[i].id] = currentX;
    }

    final newElements = attach.internalElements.map((e) {
      if (e.type == InternalElementType.verticalLine &&
          e.properties['isShort'] != true &&
          newXs.containsKey(e.id)) {
        return InternalElement(
          id: e.id,
          type: e.type,
          position: Offset(newXs[e.id]!, attach.height),
          size: Size(e.size.width, attach.height),
          rotation: e.rotation,
          properties: e.properties,
        );
      }
      return e;
    }).toList();

    return attach.copyWith(internalElements: newElements);
  }

  /// Gap listesinden yatay çizgiler oluştur, SideAttachment'a ekle.
  static SideAttachment createHorizontalLinesInAttachment(
    SideAttachment attach,
    List<double> gaps,
  ) {
    double currentY = 0;
    final newElements = <InternalElement>[];

    for (int i = gaps.length - 1; i > 0; i--) {
      currentY += gaps[i];
      newElements.add(
        InternalElement(
          id: '${DateTime.now().millisecondsSinceEpoch}_h_$currentY',
          type: InternalElementType.horizontalLine,
          position: Offset(0, currentY),
          size: Size(attach.width, 2),
          rotation: 0,
          properties: {},
        ),
      );
    }

    return attach.copyWith(
      internalElements: [...attach.internalElements, ...newElements],
    );
  }

  /// Gap listesinden dikey çizgiler oluştur, SideAttachment'a ekle.
  static SideAttachment createVerticalLinesInAttachment(
    SideAttachment attach,
    List<double> gaps,
  ) {
    double currentX = 0;
    final newElements = <InternalElement>[];

    for (int i = 0; i < gaps.length - 1; i++) {
      currentX += gaps[i];
      newElements.add(
        InternalElement(
          id: '${DateTime.now().millisecondsSinceEpoch}_v_$currentX',
          type: InternalElementType.verticalLine,
          position: Offset(currentX, attach.height),
          size: Size(2, attach.height),
          rotation: 0,
          properties: {},
        ),
      );
    }

    return attach.copyWith(
      internalElements: [...attach.internalElements, ...newElements],
    );
  }
}
