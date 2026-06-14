import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'shape_spec.dart';

class Drawing {
  final String id;
  final String projectId;
  final String name;
  final String createdAt;
  final String? updatedAt;
  final String? drawingData;

  final String? location;
  final String? direction;
  final double? height;
  final double? width;
  final String? roomDescription;

  final List<ShapeSpec> shapes;

  Drawing({
    required this.id,
    required this.projectId,
    required this.name,
    required this.createdAt,
    this.updatedAt,
    this.drawingData,
    this.location,
    this.direction,
    this.height,
    this.width,
    this.roomDescription,
    List<ShapeSpec>? shapes,
  }) : shapes = shapes ?? [] {
    // 🚨 GÜVENLİK: drawingData boşsa shapes'e göre oluştur
    if (drawingData == null && this.shapes.isNotEmpty) {
      // Bu constructor dışında kullanılmamalı, sadece güvenlik için
    }
  }

  Map<String, dynamic> toMap() {
    final serializedData = _serializeDrawingData();

    return {
      'id': id,
      'project_id': projectId,
      'name': name,
      'created_at': createdAt,
      'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
      'drawing_data': serializedData, // shapes buraya JSON olarak gidiyor
      'location': location,
      'direction': direction,
      'height': height,
      'width': width,
      'room_description': roomDescription,
    };
  }

  factory Drawing.fromMap(Map<String, dynamic> map) {
    try {
      final drawingData = map['drawing_data'] as String?;
      final name = map['name'] as String? ?? 'İsimsiz';

      return Drawing(
        id: map['id'] as String,
        projectId: map['project_id'] as String,
        name: name,
        createdAt: map['created_at'] as String,
        updatedAt: map['updated_at'] as String?,
        drawingData: drawingData,
        location: map['location'] as String?,
        direction: map['direction'] as String?,
        height: (map['height'] as num?)?.toDouble(),
        width: (map['width'] as num?)?.toDouble(),
        roomDescription: map['room_description'] as String?,
        shapes: _deserializeDrawingData(drawingData), // shapes buradan geliyor
      );
    } catch (e) {
      print('❌ Drawing.fromMap error: $e');
      rethrow;
    }
  }

  // 🚨 GÜVENLİ SERİALİZASYON
  String? _serializeDrawingData() {
    if (shapes.isEmpty) return null;

    try {
      final List<Map<String, dynamic>> shapesJson = shapes
          .map((shape) {
            try {
              return shape.toJson();
            } catch (e) {
              print('⚠️ Shape serialization error: $e');
              return <String, dynamic>{};
            }
          })
          .where((json) => json.isNotEmpty)
          .toList();

      if (shapesJson.isEmpty) return null;

      return jsonEncode({
        'shapes': shapesJson,
        'version': '1.1.0', // 🚨 Version güncellendi
        'serializedAt': DateTime.now().toIso8601String(),
        'shapesCount': shapes.length,
      });
    } catch (e) {
      print('❌ Drawing data serialization error: $e');
      return null;
    }
  }

  // 🚨 GÜVENLİ DESERIALİZASYON
  static List<ShapeSpec> _deserializeDrawingData(String? drawingData) {
    if (drawingData == null || drawingData.trim().isEmpty) {
      return [];
    }

    try {
      final Map<String, dynamic> json = jsonDecode(drawingData);
      final List<dynamic> shapesJson = json['shapes'] ?? [];

      return shapesJson.map((shapeJson) {
        try {
          return ShapeSpec.fromJson(Map<String, dynamic>.from(shapeJson));
        } catch (e) {
          print('⚠️ Shape deserialization error: $e');
          return ShapeSpec.rectangle(); // Fallback
        }
      }).toList();
    } catch (e) {
      print('❌ Drawing data deserialization error: $e');
      return [];
    }
  }

  // 🚨 GÜNCELLENMİŞ copyWith
  // 🚨 copyWith metoduna name parametresi ekle
  Drawing copyWith({
    String? name, // 🚨 YENİ
    String? updatedAt,
    List<ShapeSpec>? shapes,
    String? location,
    String? direction,
    double? height,
    double? width,
    String? roomDescription,
  }) {
    final newShapes = shapes ?? this.shapes;
    final newUpdatedAt = updatedAt ?? DateTime.now().toIso8601String();

    final newDrawingData = _serializeShapes(newShapes);

    return Drawing(
      id: id,
      projectId: projectId,
      name: name ?? this.name, // 🚨 YENİ: name parametresi kullan
      createdAt: createdAt,
      updatedAt: newUpdatedAt,
      drawingData: newDrawingData,
      location: location ?? this.location,
      direction: direction ?? this.direction,
      height: height ?? this.height,
      width: width ?? this.width,
      roomDescription: roomDescription ?? this.roomDescription,
      shapes: newShapes,
    );
  }

  // 🚨 YARDIMCI: Shapes serialize
  String? _serializeShapes(List<ShapeSpec> shapes) {
    if (shapes.isEmpty) return null;

    try {
      final List<Map<String, dynamic>> shapesJson = shapes
          .map((shape) => shape.toJson())
          .toList();

      return jsonEncode({
        'shapes': shapesJson,
        'version': '1.1.0',
        'createdAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Shape serialization error: $e');
      return null;
    }
  }

  // 🚨 YENİ: Shapes ile kopyalama
  Drawing copyWithShapes(List<ShapeSpec> newShapes) {
    return copyWith(
      shapes: newShapes,
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  // 🚨 YENİ: Shape ekleme
  Drawing addShape(ShapeSpec shape) {
    final newShapes = List<ShapeSpec>.from(shapes)..add(shape);
    return copyWithShapes(newShapes);
  }

  // 🚨 YENİ: Shape silme
  Drawing removeShapeAt(int index) {
    if (index < 0 || index >= shapes.length) return this;
    final newShapes = List<ShapeSpec>.from(shapes)..removeAt(index);
    return copyWithShapes(newShapes);
  }

  // 🚨 YENİ: Shape güncelleme
  Drawing updateShapeAt(int index, ShapeSpec newShape) {
    if (index < 0 || index >= shapes.length) return this;
    final newShapes = List<ShapeSpec>.from(shapes)..[index] = newShape;
    return copyWithShapes(newShapes);
  }

  // 🚨 YENİ: Oda bilgileri ile kopyalama
  Drawing copyWithRoomInfo({
    String? location,
    String? direction,
    double? height,
    double? width,
    String? roomDescription,
  }) {
    return copyWith(
      location: location,
      direction: direction,
      height: height,
      width: width,
      roomDescription: roomDescription,
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  // 🚨 YENİ: Çizim boyutlarını getir
  (double width, double height) getDrawingSize() {
    if (shapes.isEmpty) {
      return (width ?? 0.0, height ?? 0.0);
    }

    double maxWidth = 0;
    double maxHeight = 0;

    // for (final shape in shapes) {
    //   final bounds = shape.boundingSize();
    //   maxWidth = maxWidth > bounds.width ? maxWidth : bounds.width;
    //   maxHeight = maxHeight > bounds.height ? maxHeight : bounds.height;
    // }

    return (maxWidth, maxHeight);
  }

  // 🚨 YENİ: Çizim özeti
  Map<String, dynamic> toSummary() {
    final (drawingWidth, drawingHeight) = getDrawingSize();

    return {
      'id': id,
      'name': name,
      'projectId': projectId,
      'shapesCount': shapes.length,
      'width': drawingWidth,
      'height': drawingHeight,
      'location': location,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'hasRoomInfo':
          location != null ||
          direction != null ||
          height != null ||
          width != null ||
          roomDescription != null,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Drawing &&
        other.id == id &&
        other.projectId == projectId &&
        other.name == name &&
        listEquals(other.shapes, shapes);
  }

  @override
  int get hashCode {
    return Object.hash(id, projectId, name, Object.hashAll(shapes));
  }

  @override
  String toString() {
    return 'Drawing(id: $id, name: $name, projectId: $projectId, shapes: ${shapes.length})';
  }
}
