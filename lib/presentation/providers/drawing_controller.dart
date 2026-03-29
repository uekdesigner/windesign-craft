import 'package:flutter/material.dart';
import '../../models/shape_spec.dart';

class DrawingCommand {
  final String
  type; // 'add_shape', 'delete_shape', 'modify_shape', 'add_element'
  final String? shapeId;
  final dynamic previousState;
  final dynamic newState;

  DrawingCommand({
    required this.type,
    this.shapeId,
    this.previousState,
    this.newState,
  });
}

class DrawingController extends ChangeNotifier {
  String pageTitle = "";
  List<ShapeSpec> shapes = [];
  int? selectedShapeIndex;

  // Undo/Redo history
  final List<DrawingCommand> _undoStack = [];
  final List<DrawingCommand> _redoStack = [];

  ShapeSpec? get selectedShape =>
      selectedShapeIndex != null ? shapes[selectedShapeIndex!] : null;

  void initialize(String title) {
    pageTitle = title;
    notifyListeners();
  }

  void selectShape(int index) {
    selectedShapeIndex = index;
    notifyListeners();
  }

  void addShape(ShapeSpec shape) {
    _undoStack.add(DrawingCommand(type: 'add_shape', newState: shape.toJson()));
    _redoStack.clear();

    shapes.add(shape);
    selectedShapeIndex = shapes.length - 1;
    notifyListeners();
  }

  void deleteSelectedShape() {
    if (selectedShapeIndex == null) return;

    final shape = shapes[selectedShapeIndex!];
    _undoStack.add(
      DrawingCommand(
        type: 'delete_shape',
        shapeId: shape.id,
        previousState: shape.toJson(),
      ),
    );
    _redoStack.clear();

    shapes.removeAt(selectedShapeIndex!);
    selectedShapeIndex = shapes.isNotEmpty ? 0 : null;
    notifyListeners();
  }

  void updateSelectedShape(ShapeSpec newShape) {
    if (selectedShapeIndex == null) return;

    final oldShape = shapes[selectedShapeIndex!];
    _undoStack.add(
      DrawingCommand(
        type: 'modify_shape',
        shapeId: oldShape.id,
        previousState: oldShape.toJson(),
        newState: newShape.toJson(),
      ),
    );
    _redoStack.clear();

    shapes[selectedShapeIndex!] = newShape;
    notifyListeners();
  }

  void addInternalElement(InternalElement element) {
    if (selectedShapeIndex == null) return;
    final shape = shapes[selectedShapeIndex!];

    _undoStack.add(
      DrawingCommand(
        type: 'add_element',
        shapeId: shape.id,
        previousState: shape.internalElements.map((e) => e.toJson()).toList(),
      ),
    );
    _redoStack.clear();

    final updatedElements = [...shape.internalElements, element];
    shapes[selectedShapeIndex!] = shape.copyWith(
      internalElements: updatedElements,
    );
    notifyListeners();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    final cmd = _undoStack.removeLast();
    _redoStack.add(cmd);

    _executeInverseCommand(cmd);
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    final cmd = _redoStack.removeLast();
    _undoStack.add(cmd);

    _executeCommand(cmd);
    notifyListeners();
  }

  void _executeCommand(DrawingCommand cmd) {
    switch (cmd.type) {
      case 'add_shape':
        final shape = ShapeSpec.fromJson(cmd.newState);
        shapes.add(shape);
        selectedShapeIndex = shapes.length - 1;
        break;
      case 'delete_shape':
        shapes.removeWhere((s) => s.id == cmd.shapeId);
        break;
      case 'modify_shape':
        final index = shapes.indexWhere((s) => s.id == cmd.shapeId);
        if (index != -1) {
          shapes[index] = ShapeSpec.fromJson(cmd.newState);
        }
        break;
      case 'add_element':
        // Handled in addInternalElement
        break;
    }
  }

  void _executeInverseCommand(DrawingCommand cmd) {
    switch (cmd.type) {
      case 'add_shape':
        shapes.removeWhere((s) => s.id == (cmd.newState['id']));
        break;
      case 'delete_shape':
        final shape = ShapeSpec.fromJson(cmd.previousState);
        shapes.add(shape);
        break;
      case 'modify_shape':
        final index = shapes.indexWhere((s) => s.id == cmd.shapeId);
        if (index != -1) {
          shapes[index] = ShapeSpec.fromJson(cmd.previousState);
        }
        break;
    }
  }

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
}
