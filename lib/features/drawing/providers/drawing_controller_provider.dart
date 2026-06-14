import 'dart:math' as math show min, max;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/shape_spec.dart';
import '../../../models/drawing.dart';
import 'drawing_provider.dart';
import '../geometry/shape_crop_geometry.dart';
import '../tools/line_calculator.dart';
import 'drawing_controller_side_panel.dart';

// State sınıfı - Tüm değerler final ve required
class DrawingControllerState {
  final List<ShapeSpec> shapes;
  final int selectedIndex;
  final List<List<ShapeSpec>> undoStack;
  final List<List<ShapeSpec>> redoStack;
  final bool isUndoing;

  const DrawingControllerState({
    required this.shapes,
    required this.selectedIndex,
    this.undoStack = const [],
    this.redoStack = const [],
    this.isUndoing = false,
  });

  DrawingControllerState copyWith({
    List<ShapeSpec>? shapes,
    int? selectedIndex,
    List<List<ShapeSpec>>? undoStack,
    List<List<ShapeSpec>>? redoStack,
    bool? isUndoing,
  }) {
    return DrawingControllerState(
      shapes: shapes ?? this.shapes,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      isUndoing: isUndoing ?? this.isUndoing,
    );
  }

  ShapeSpec? get currentShape =>
      shapes.isNotEmpty && selectedIndex >= 0 && selectedIndex < shapes.length
      ? shapes[selectedIndex]
      : null;
  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;
}

// Provider
final drawingControllerProvider = StateNotifierProvider.autoDispose
    .family<
      DrawingController,
      DrawingControllerState,
      ({String projectId, String drawingId})
    >((ref, params) {
      return DrawingController(ref, params.projectId, params.drawingId);
    });

class DrawingController extends StateNotifier<DrawingControllerState> {
  final Ref _ref;
  final String projectId;
  final String drawingId;

  DrawingControllerState get controllerState => state;

  // 🆕 Başlangıçta loading true ile başla
  DrawingController(this._ref, this.projectId, this.drawingId)
    : super(const DrawingControllerState(shapes: [], selectedIndex: -1)) {
    // Sync initialize
    try {
      final drawings = _ref.read(drawingProvider(projectId));
      final drawing = drawings.firstWhere(
        (d) => d.id == drawingId,
        orElse: () => Drawing(
          id: drawingId,
          projectId: projectId,
          name: 'Yeni Çizim',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      state = DrawingControllerState(
        shapes: drawing.shapes.isNotEmpty
            ? drawing.shapes
            : [ShapeSpec.rectangle(width: 1000, height: 1000)],
        selectedIndex: 0,
      );
    } catch (e) {
      state = DrawingControllerState(
        shapes: [ShapeSpec.rectangle(width: 1000, height: 1000)],
        selectedIndex: 0,
      );
    }
  }

  // ==================== SHAPE OPERATIONS ====================

  void selectShape(int index) {
    if (index >= 0 && index < state.shapes.length) {
      state = state.copyWith(selectedIndex: index);
    }
  }

  void addShape(ShapeSpec shape) {
    _saveForUndo();
    final newShapes = [...state.shapes, shape];
    state = state.copyWith(
      shapes: newShapes,
      selectedIndex: newShapes.length - 1,
    );
    _syncToRepository();
  }

  void updateShape(int index, ShapeSpec newShape) {
    if (index < 0 || index >= state.shapes.length) return;
    _saveForUndo();

    state = state.copyWith(
      shapes: [
        for (int i = 0; i < state.shapes.length; i++)
          if (i == index) newShape else state.shapes[i],
      ],
    );
    _syncToRepository();
  }

  void deleteShape(int index) {
    if (state.shapes.length <= 1) return;
    _saveForUndo();

    final newShapes = [...state.shapes]..removeAt(index);
    int newIndex = state.selectedIndex;

    if (newIndex >= newShapes.length) {
      newIndex = newShapes.length - 1;
    }

    state = state.copyWith(shapes: newShapes, selectedIndex: newIndex);
    _syncToRepository();
  }

  // ==================== INTERNAL ELEMENTS ====================

  void addInternalElement(InternalElement element) {
    final current = state.currentShape;
    if (current == null) return;

    _saveForUndo();
    final updated = current.copyWith(
      internalElements: [...current.internalElements, element],
    );
    updateShape(state.selectedIndex, updated);
  }

  void updateInternalElement(
    String elementId,
    InternalElement Function(InternalElement) updater,
  ) {
    final current = state.currentShape;
    if (current == null) return;

    final index = current.internalElements.indexWhere((e) => e.id == elementId);
    if (index == -1) return;

    _saveForUndo();
    final newElements = [...current.internalElements];
    newElements[index] = updater(newElements[index]);

    final updated = current.copyWith(internalElements: newElements);
    updateShape(state.selectedIndex, updated);
  }

  void deleteInternalElement(String elementId) {
    final current = state.currentShape;
    if (current == null) return;

    _saveForUndo();
    final updated = current.copyWith(
      internalElements: current.internalElements
          .where((e) => e.id != elementId)
          .toList(),
    );
    updateShape(state.selectedIndex, updated);
  }

  void updateHorizontalLineY(String elementId, double newY) {
    final current = state.currentShape;
    if (current == null) return;

    final index = current.internalElements.indexWhere((e) => e.id == elementId);
    if (index == -1) return;

    final oldElement = current.internalElements[index];
    final updated = LineCalculator.calculateHorizontalUpdate(
      current,
      oldElement,
      newY,
    );

    if (updated != null) {
      updateInternalElement(elementId, (_) => updated);
    }
  }

  void updateVerticalLineX(String elementId, double newX) {
    final current = state.currentShape;
    if (current == null) return;

    final index = current.internalElements.indexWhere((e) => e.id == elementId);
    if (index == -1) return;

    final oldElement = current.internalElements[index];
    final updated = LineCalculator.calculateVerticalUpdate(
      current,
      oldElement,
      newX,
    );

    if (updated != null) {
      updateInternalElement(elementId, (_) => updated);
    }
  }

  // ==================== KISA ÇİZGİ GÜNCELLEME ====================
  void updateShortHorizontalLine(String elementId, double newY) {
    final current = state.currentShape;
    if (current == null) return;

    final index = current.internalElements.indexWhere((e) => e.id == elementId);
    if (index == -1) return;

    final oldElement = current.internalElements[index];
    if (oldElement.type != InternalElementType.horizontalLine) return;

    // Çizginin orta noktası X (hangi hücrede olduğunu bulmak için)
    final midX = oldElement.position.dx + oldElement.size.width / 2;

    // 🆕 TÜM DİKEY ÇİZGİLER (uzun + kısa), kendini hariç tut
    // Kısa dikeyler: sadece yeni Y'de geçerli olanlar (yTop >= newY >= yBottom)
    final allVerticalXs =
        current.internalElements
            .where((e) {
              if (e.id == elementId) return false;
              if (e.type != InternalElementType.verticalLine) return false;
              if (e.properties['isShort'] == true) {
                final yTop = e.position.dy;
                final yBottom = e.position.dy - e.size.height;
                return newY <= yTop && newY >= yBottom;
              }
              return true;
            })
            .map((e) => e.position.dx)
            .toList()
          ..sort();

    // Sol sınır: midX'in solundaki en yakın dikey çizgi
    double cellLeft = 0;
    for (final x in allVerticalXs) {
      if (x < midX) cellLeft = x;
    }

    // Sağ sınır: midX'in sağındaki en yakın dikey çizgi
    double cellRight = current.baseWidth;
    for (final x in allVerticalXs) {
      if (x > midX) {
        cellRight = x;
        break;
      }
    }

    // Yeni Y'deki crop sınırları
    final cropLeft = ShapeCropGeometry.leftXAtY(current, newY);
    final cropRight = ShapeCropGeometry.rightXAtY(current, newY);

    // 🆕 KESİŞİM: Hücre sınırları ile crop sınırlarının kesişimi
    final newLeft = math.max(cellLeft, cropLeft);
    final newRight = math.min(cellRight, cropRight);
    final newWidth = newRight - newLeft;

    if (newWidth < 10) return;

    final updatedElement = InternalElement(
      id: oldElement.id,
      type: oldElement.type,
      position: Offset(newLeft, newY),
      size: Size(newWidth, oldElement.size.height),
      rotation: oldElement.rotation,
      properties: oldElement.properties,
    );

    updateInternalElement(elementId, (_) => updatedElement);
  }

  void updateShortVerticalLine(String elementId, double newX) {
    final current = state.currentShape;
    if (current == null) return;

    final index = current.internalElements.indexWhere((e) => e.id == elementId);
    if (index == -1) return;

    final oldElement = current.internalElements[index];
    if (oldElement.type != InternalElementType.verticalLine) return;

    final midY = oldElement.position.dy - oldElement.size.height / 2;

    // 🆕 TÜM YATAY ÇİZGİLER - KÜÇÜKTEN BÜYÜĞE sıralı
    // Kısa yataylar: sadece yeni X'de geçerli olanlar (xRight >= newX >= xLeft)
    final allHorizontalYs =
        current.internalElements
            .where((e) {
              if (e.id == elementId) return false;
              if (e.type != InternalElementType.horizontalLine) return false;
              if (e.properties['isShort'] == true) {
                final xLeft = e.position.dx;
                final xRight = e.position.dx + e.size.width;
                return newX >= xLeft && newX <= xRight;
              }
              return true;
            })
            .map((e) => e.position.dy)
            .toList()
          ..sort();

    // Alt sınır: midY'nin altındaki en yakın (son koşulu sağlayan)
    double cellBottom = 0;
    for (final y in allHorizontalYs) {
      if (y < midY) cellBottom = y;
    }

    // Üst sınır: midY'nin üstündeki en yakın (ilk koşulu sağlayan)
    double cellTop = current.baseHeight;
    for (final y in allHorizontalYs) {
      if (y > midY) {
        cellTop = y;
        break;
      }
    }

    final cropTop = ShapeCropGeometry.topYAtX(current, newX);
    final cropBottom = ShapeCropGeometry.bottomYAtX(current, newX);

    final newTop = math.min(cellTop, cropTop);
    final newBottom = math.max(cellBottom, cropBottom);
    final newHeight = newTop - newBottom;

    if (newHeight < 10) return;

    final updatedElement = InternalElement(
      id: oldElement.id,
      type: oldElement.type,
      position: Offset(newX, newTop),
      size: Size(oldElement.size.width, newHeight),
      rotation: oldElement.rotation,
      properties: oldElement.properties,
    );

    updateInternalElement(elementId, (_) => updatedElement);
  }
  // ==================== UNDO / REDO ====================

  void _saveForUndo() {
    if (state.isUndoing) return;

    final deepCopy = _deepCopyShapes(state.shapes);
    final newUndo = [...state.undoStack, deepCopy];

    if (newUndo.length > 20) {
      newUndo.removeAt(0);
    }

    state = state.copyWith(undoStack: newUndo, redoStack: []);
  }

  List<ShapeSpec> _deepCopyShapes(List<ShapeSpec> shapes) {
    return shapes.map((shape) {
      return shape.copyWith(
        internalElements: shape.internalElements.map((element) {
          return InternalElement(
            id: element.id,
            type: element.type,
            position: element.position,
            size: element.size,
            rotation: element.rotation,
            properties: Map<String, dynamic>.from(element.properties),
          );
        }).toList(),
      );
    }).toList();
  }

  void undo() {
    if (state.undoStack.isEmpty) return;

    state = state.copyWith(isUndoing: true);

    final currentState = _deepCopyShapes(state.shapes);
    final previousShapes = state.undoStack.last;

    state = state.copyWith(
      shapes: previousShapes,
      undoStack: state.undoStack.sublist(0, state.undoStack.length - 1),
      redoStack: [...state.redoStack, currentState],
    );

    _syncToRepository();
    state = state.copyWith(isUndoing: false);
  }

  void redo() {
    if (state.redoStack.isEmpty) return;

    state = state.copyWith(isUndoing: true);

    final currentState = _deepCopyShapes(state.shapes);
    final nextShapes = state.redoStack.last;

    state = state.copyWith(
      shapes: nextShapes,
      redoStack: state.redoStack.sublist(0, state.redoStack.length - 1),
      undoStack: [...state.undoStack, currentState],
    );

    _syncToRepository();
    state = state.copyWith(isUndoing: false);
  }

  Future<void> _syncToRepository() async {
    final drawings = _ref.read(drawingProvider(projectId));

    // 🆕 orElse eklendi: Bulunamazsa null dön, çökme
    final drawing = drawings.firstWhere(
      (d) => d.id == drawingId,
      orElse: () => Drawing(
        id: drawingId,
        projectId: projectId,
        name: 'Yeni Çizim',
        createdAt: DateTime.now().toIso8601String(),
      ),
    );

    final updated = drawing.copyWithShapes(state.shapes);
    await _ref.read(drawingProvider(projectId).notifier).updateDrawing(updated);
  }
}
