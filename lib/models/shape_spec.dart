import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';

enum InternalElementType {
  verticalLine,
  horizontalLine,
  triangle,
  parallelLines,
}

class InternalElement {
  final String id;
  final InternalElementType type;
  final Offset position; // mm cinsinden pozisyon (sol-üst köşesi)
  final Size size; // mm cinsinden boyut
  final double rotation; // derece cinsinden
  final Map<String, dynamic> properties;

  const InternalElement({
    required this.id,
    required this.type,
    required this.position,
    required this.size,
    this.rotation = 0,
    this.properties = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'position': {'x': position.dx, 'y': position.dy},
    'size': {'width': size.width, 'height': size.height},
    'rotation': rotation,
    'properties': properties,
  };

  factory InternalElement.fromJson(Map<String, dynamic> json) {
    return InternalElement(
      id: json['id'],
      type: InternalElementType.values.byName(json['type']),
      position: Offset(json['position']['x'], json['position']['y']),
      size: Size(json['size']['width'], json['size']['height']),
      rotation: json['rotation'],
      properties: json['properties'] ?? {},
    );
  }

  InternalElement copyWith({Offset? position, Size? size, double? rotation}) {
    return InternalElement(
      id: id,
      type: type,
      position: position ?? this.position,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
      properties: properties,
    );
  }
}

class ShapeSpec {
  String id;
  String name; // "1. Şekil", "2. Şekil" vb.

  // Ana ölçüler
  double baseWidth;
  double baseHeight;

  // Köşe kırpma değerleri (X: yatay mesafe, Y: dikey mesafe)
  double topLeftX; // Üst kenardan sağa
  double topLeftY; // Sol kenardan yukarı
  double topRightX; // Üst kenardan sola
  double topRightY; // Sağ kenardan yukarı
  double bottomLeftX; // Alt kenardan sağa
  double bottomLeftY; // Sol kenardan aşağı
  double bottomRightX; // Alt kenardan sola
  double bottomRightY; // Sağ kenardan aşağı

  // Eski sistemle uyumluluk için (opsiyonel, default 0)
  double get cropTopLeft => topLeftX;
  double get cropTopRight => topRightX;
  double get cropBottomLeft => bottomLeftX;
  double get cropBottomRight => bottomRightX;

  // İç elemanlar
  List<InternalElement> internalElements;

  // Canvas pozisyonu (mm cinsinden merkez noktası)
  Offset canvasPosition;

  // Görsel ayarlar
  bool showDimensions;
  Color strokeColor;
  double strokeWidth;

  ShapeSpec({
    required this.id,
    required this.name,
    required this.baseWidth,
    required this.baseHeight,
    this.topLeftX = 0,
    this.topLeftY = 0,
    this.topRightX = 0,
    this.topRightY = 0,
    this.bottomLeftX = 0,
    this.bottomLeftY = 0,
    this.bottomRightX = 0,
    this.bottomRightY = 0,
    this.internalElements = const [],
    this.canvasPosition = Offset.zero,
    this.showDimensions = true,
    this.strokeColor = Colors.black,
    this.strokeWidth = 2.0,
  });

  factory ShapeSpec.rectangle({double width = 1000, double height = 1000}) {
    return ShapeSpec(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Yeni Şekil',
      baseWidth: width,
      baseHeight: height,
    );
  }

  // Poligon noktalarını hesapla (saat yönünde)
  List<Offset> getPolygonPoints() {
    final w = baseWidth;
    final h = baseHeight;

    return [
      // === SOL ÜST KÖŞE ===
      Offset(topLeftX, h), // 0: X₁ (Üst kenarda, sola topLeftX mesafede)
      Offset(0, h - topLeftY), // 1: Y₁ (Sol kenarda, üstten topLeftY mesafede)
      // === SAĞ ÜST KÖŞE ===
      Offset(w - topRightX, h), // 2: X₂ (Üst kenarda, sağa topRightX mesafede)
      Offset(
        w,
        h - topRightY,
      ), // 3: Y₂ (Sağ kenarda, üstten topRightY mesafede)
      // === SAĞ ALT KÖŞE ===
      Offset(
        w,
        bottomRightY,
      ), // 4: Y₃ (Sağ kenarda, alttan bottomRightY mesafede)
      Offset(
        w - bottomRightX,
        0,
      ), // 5: X₃ (Alt kenarda, sağa bottomRightX mesafede)
      // === SOL ALT KÖŞE ===
      Offset(bottomLeftX, 0), // 6: X₄ (Alt kenarda, sola bottomLeftX mesafede)
      Offset(
        0,
        bottomLeftY,
      ), // 7: Y₄ (Sol kenarda, alttan bottomLeftY mesafede)
    ];
  }

  Size get boundingSize {
    final points = getPolygonPoints();
    if (points.isEmpty) return Size(baseWidth, baseHeight);

    final maxX = points.map((p) => p.dx).reduce(math.max);
    final minX = points.map((p) => p.dx).reduce(math.min);
    final maxY = points.map((p) => p.dy).reduce(math.max);
    final minY = points.map((p) => p.dy).reduce(math.min);

    return Size(maxX - minX, maxY - minY);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'baseWidth': baseWidth,
    'baseHeight': baseHeight,
    'topLeftX': topLeftX,
    'topLeftY': topLeftY,
    'topRightX': topRightX,
    'topRightY': topRightY,
    'bottomLeftX': bottomLeftX,
    'bottomLeftY': bottomLeftY,
    'bottomRightX': bottomRightX,
    'bottomRightY': bottomRightY,
    'internalElements': internalElements.map((e) => e.toJson()).toList(),
    'canvasPosition': {'x': canvasPosition.dx, 'y': canvasPosition.dy},
    'showDimensions': showDimensions,
  };

  factory ShapeSpec.fromJson(Map<String, dynamic> json) {
    return ShapeSpec(
      id: json['id'],
      name: json['name'],
      baseWidth: (json['baseWidth'] as num?)?.toDouble() ?? 1000,
      baseHeight: (json['baseHeight'] as num?)?.toDouble() ?? 1000,
      topLeftX: (json['topLeftX'] as num?)?.toDouble() ?? 0,
      topLeftY: (json['topLeftY'] as num?)?.toDouble() ?? 0,
      topRightX: (json['topRightX'] as num?)?.toDouble() ?? 0,
      topRightY: (json['topRightY'] as num?)?.toDouble() ?? 0,
      bottomLeftX: (json['bottomLeftX'] as num?)?.toDouble() ?? 0,
      bottomLeftY: (json['bottomLeftY'] as num?)?.toDouble() ?? 0,
      bottomRightX: (json['bottomRightX'] as num?)?.toDouble() ?? 0,
      bottomRightY: (json['bottomRightY'] as num?)?.toDouble() ?? 0,
      internalElements:
          (json['internalElements'] as List?)
              ?.map((e) => InternalElement.fromJson(e))
              .toList() ??
          [],
      canvasPosition: Offset(
        json['canvasPosition']?['x'] ?? 0,
        json['canvasPosition']?['y'] ?? 0,
      ),
      showDimensions: json['showDimensions'] as bool? ?? true,
    );
  }

  ShapeSpec copyWith({
    String? name,
    double? baseWidth,
    double? baseHeight,
    double? topLeftX,
    double? topLeftY,
    double? topRightX,
    double? topRightY,
    double? bottomLeftX,
    double? bottomLeftY,
    double? bottomRightX,
    double? bottomRightY,
    List<InternalElement>? internalElements,
    bool? showDimensions,
  }) {
    return ShapeSpec(
      id: id,
      name: name ?? this.name,
      baseWidth: baseWidth ?? this.baseWidth,
      baseHeight: baseHeight ?? this.baseHeight,
      topLeftX: topLeftX ?? this.topLeftX,
      topLeftY: topLeftY ?? this.topLeftY,
      topRightX: topRightX ?? this.topRightX,
      topRightY: topRightY ?? this.topRightY,
      bottomLeftX: bottomLeftX ?? this.bottomLeftX,
      bottomLeftY: bottomLeftY ?? this.bottomLeftY,
      bottomRightX: bottomRightX ?? this.bottomRightX,
      bottomRightY: bottomRightY ?? this.bottomRightY,
      internalElements: internalElements ?? this.internalElements,
      canvasPosition: canvasPosition,
      showDimensions: showDimensions ?? this.showDimensions,
      strokeColor: strokeColor,
      strokeWidth: strokeWidth,
    );
  }
}
