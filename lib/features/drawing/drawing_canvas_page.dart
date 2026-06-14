// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/dialogs/measure_dialog.dart';
import '../../models/shape_spec.dart';
import 'painters/quadrilateral_painter.dart';
import 'providers/drawing_provider.dart';
import 'providers/drawing_controller_provider.dart';
import 'providers/tool_mode_provider.dart';
import '../../shared/dialogs/section_editor_dialog.dart';
import '../../shared/dialogs/delete_elements_dialog.dart';
import '../drawing/geometry/shape_crop_geometry.dart';
import 'tools/line_drag_tool.dart';
import 'tools/short_line_drag_tool.dart';
import 'tools/triangle_tool.dart';
import 'tools/slide_arrow_tool.dart';
import 'tools/dot_grid_tool.dart';
import 'tools/line_grid_tool.dart';
import 'tools/panel_hit_tester.dart';
import 'tools/gap_calculator.dart';
import 'tools/coord_converter.dart';
import 'widgets/system_bottom_panel.dart';
import 'widgets/corner_side_panels.dart';
import 'tools/side_panel_tool_handler.dart';
import 'drawing_canvas_side_panel_editor.dart';

class DrawingCanvasPage extends ConsumerStatefulWidget {
  final String projectId;
  final String drawingId;
  final String customerName;

  const DrawingCanvasPage({
    super.key,
    required this.projectId,
    required this.drawingId,
    required this.customerName,
  });

  @override
  ConsumerState<DrawingCanvasPage> createState() => _DrawingCanvasPageState();
}

class _DrawingCanvasPageState extends ConsumerState<DrawingCanvasPage>
    with SidePanelEditorMixin {
  // ignore: unused_field
  static const bool _debugMode = false;

  final TransformationController _transformationController =
      TransformationController();
  double _currentScale = 1.0;

  bool _showSideHandles = true;
  bool _isShapeListPanelOpen = true;
  bool _isNewBottomPanelOpen = false;
  bool _isSystemPanelOpen = false;
  double _systemPanelHeight = 0;

  String? _selectedHorizontalLineId;
  double? _previewHorizontalLineY;
  double? _previewVerticalLineX;
  double? _previewShortHorizontalLineY;
  double? _previewShortVerticalLineX;
  // 🆕 Yan panel drag state
  bool _dragInSidePanel = false;
  String? _dragSidePanelSide;
  SideAttachment? _dragSideAttach;
  // 🆕 Yan panel drag önizleme (gölge) — panel-yerel koordinatlar
  String? _sidePreviewSide;
  double? _sidePreviewLocalY;
  double? _sidePreviewLocalX;

  Offset? _lastShortHorizontalMmPos;
  Offset? _lastShortVerticalMmPos;

  double _canvasScale = 1.0;
  Offset _canvasOffset = Offset.zero;

  bool _canPan = false;
  Timer? _panEnableTimer;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_updateScale);
  }

  @override
  void dispose() {
    _panEnableTimer?.cancel(); // 🆕
    _transformationController.dispose();
    super.dispose();
  }

  CoordConverter get _coordConverter => CoordConverter(
    transformationController: _transformationController,
    canvasScale: _canvasScale,
    canvasOffset: _canvasOffset,
  );
  bool _hasAnyMaterial(ShapeSpec? shape) {
    if (shape == null) return false;
    final hasCrop =
        shape.topLeftX > 0 ||
        shape.topLeftY > 0 ||
        shape.topRightX > 0 ||
        shape.topRightY > 0 ||
        shape.bottomLeftX > 0 ||
        shape.bottomLeftY > 0 ||
        shape.bottomRightX > 0 ||
        shape.bottomRightY > 0;
    return hasCrop ||
        shape.internalElements.isNotEmpty ||
        shape.sideAttachments.isNotEmpty;
  }

  Offset _screenToMm(Offset screenPos) {
    final controllerState = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )),
    );
    if (controllerState.currentShape == null) return Offset.zero;
    return _coordConverter.screenToMm(screenPos, controllerState.currentShape!);
  }

  void _processTap(Offset position) {
    final currentTool = ref.read(toolModeProvider);

    if (currentTool == ToolMode.selection) {
      if (_selectedHorizontalLineId != null) {
        setState(() => _selectedHorizontalLineId = null);
      }
    } else if (currentTool == ToolMode.triangleUp ||
        currentTool == ToolMode.triangleLeft ||
        currentTool == ToolMode.triangleRight) {
      _addTriangleToPanel(position, currentTool);
    } else if (currentTool == ToolMode.slideRight ||
        currentTool == ToolMode.slideLeft) {
      _addSlideArrowToPanel(position, currentTool);
    } else if (currentTool == ToolMode.dotGrid) {
      _addDotGridToPanel(position);
    } else if (currentTool == ToolMode.lineGrid) {
      _addLineGridToPanel(position);
    } else if (currentTool == ToolMode.attachPanel) {
      _addSidePanelAt(position);
    }
  }

  void _addElementToSidePanel(
    String side,
    SideAttachment oldAttach,
    InternalElement newElement,
  ) {
    final controllerState = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )),
    );
    final controller = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )).notifier,
    );

    if (controllerState.currentShape == null) return;
    final spec = controllerState.currentShape!;

    final updatedAttachments = spec.sideAttachments.map((a) {
      if (a.side == side) {
        return a.copyWith(
          internalElements: [...a.internalElements, newElement],
        );
      }
      return a;
    }).toList();

    final updated = spec.copyWith(sideAttachments: updatedAttachments);
    controller.updateShape(controllerState.selectedIndex, updated);
  }

  void _addSidePanelAt(Offset screenPos) {
    final controllerState = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )),
    );
    final controller = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )).notifier,
    );

    if (controllerState.currentShape == null) return;
    final spec = controllerState.currentShape!;
    final mmPos = _screenToMm(screenPos);

    final bounds = spec.boundingSize;
    final xShift = (spec.baseWidth - bounds.width) / 2;
    final leftEdge = xShift;
    final rightEdge = xShift + bounds.width;

    final String side;
    if (mmPos.dx < leftEdge) {
      side = 'left';
    } else if (mmPos.dx > rightEdge) {
      side = 'right';
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ana şeklin sağına veya soluna dokunun')),
      );
      return;
    }

    _showAttachPanelDialog(
      side,
      spec,
      controller,
      controllerState.selectedIndex,
    );
  }

  void _showAttachPanelDialog(
    String side,
    ShapeSpec spec,
    DrawingController controller,
    int selectedIndex,
  ) async {
    final widthCtrl = TextEditingController(text: '700');
    final heightCtrl = TextEditingController(
      text: spec.baseHeight.toInt().toString(),
    );

    final result = await showDialog<Map<String, double>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          side == 'right' ? 'Sağ Panel Ekle' : 'Sol Panel Ekle',
          style: const TextStyle(fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: widthCtrl,
              decoration: const InputDecoration(
                labelText: 'Genişlik (mm)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: heightCtrl,
              decoration: const InputDecoration(
                labelText: 'Yükseklik (mm)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              final w = double.tryParse(widthCtrl.text.trim()) ?? 700;
              final h =
                  double.tryParse(heightCtrl.text.trim()) ?? spec.baseHeight;
              if (w <= 0 || h <= 0) return;
              Navigator.pop(ctx, {'width': w, 'height': h});
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );

    if (result != null) {
      final updated = spec.copyWith(
        sideAttachments: [
          ...spec.sideAttachments,
          SideAttachment(
            side: side,
            width: result['width']!,
            height: result['height']!,
          ),
        ],
      );
      controller.updateShape(selectedIndex, updated);
      ref.read(toolModeProvider.notifier).reset();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            side == 'right'
                ? 'Sağ panel eklendi: ${result['width']!.toInt()}×${result['height']!.toInt()} mm'
                : 'Sol panel eklendi: ${result['width']!.toInt()}×${result['height']!.toInt()} mm',
          ),
          duration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  void _addDotGridToPanel(Offset position) {
    final controllerState = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )),
    );
    final controller = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )).notifier,
    );

    if (controllerState.currentShape == null) return;
    final spec = controllerState.currentShape!;
    final mmPos = _screenToMm(position);

    // 🆕 YAN PANEL KONTROLÜ — erken çıkış
    final sideHit = PanelHitTester.findSidePanelAtPosition(spec, mmPos);
    if (sideHit != null) {
      final side = sideHit['side'] as String;
      final attach = sideHit['attach'] as SideAttachment;
      final localX = sideHit['localX'] as double;
      final localY = sideHit['localY'] as double;
      final updated = SidePanelToolHandler.addDotGrid(attach, localX, localY);
      if (updated == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu yan panelde zaten desenli cam var'),
            duration: Duration(milliseconds: 1200),
          ),
        );
        return;
      }
      final newSpec = SidePanelToolHandler.updateAttachInSpec(
        spec,
        side,
        updated,
      );
      controller.updateShape(controllerState.selectedIndex, newSpec);
      ref.read(toolModeProvider.notifier).reset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yan panele desenli cam eklendi'),
          duration: Duration(milliseconds: 500),
        ),
      );
      return; // ← ana şekil kodu çalışmaz
    }

    final panel = PanelHitTester.findPanelAtPosition(
      spec,
      mmPos,
      includeShortLines: true,
    );
    if (panel == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bir panel seçin')));
      return;
    }

    if (DotGridTool.alreadyExists(spec, panel)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu panelde zaten desenli cam var'),
          duration: Duration(milliseconds: 1200),
        ),
      );
      return;
    }

    try {
      final element = DotGridTool.createForPanel(panel);
      controller.addInternalElement(element);
      ref.read(toolModeProvider.notifier).reset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Desenli cam eklendi'),
          duration: Duration(milliseconds: 500),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Desenli cam eklenemedi: $e')));
    }
  }

  void _showDeleteElementsDialog() async {
    final controllerState = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )),
    );
    final controller = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )).notifier,
    );

    if (controllerState.currentShape == null) return;
    final spec = controllerState.currentShape!;

    final selectedIds = await showDialog<List<String>>(
      context: context,
      builder: (context) => DeleteElementsDialog(
        shapeSpec: spec,
        totalShapesCount: controllerState.shapes.length,
        currentShapeIndex: controllerState.selectedIndex,
        onDeleteMainShape: () => _deleteCurrentShapeAndNavigate(),
      ),
    );

    if (selectedIds != null && selectedIds.isNotEmpty) {
      // Yan panel ID'lerini ayır
      final sideIdsToDelete = selectedIds
          .where((id) => isSideId(id))
          .map((id) => sideFromId(id))
          .toSet();
      final elementIdsToDelete = selectedIds
          .where((id) => !isSideId(id))
          .toSet();

      // internalElements filtrele
      final updatedElements = spec.internalElements
          .where((e) => !elementIdsToDelete.contains(e.id))
          .toList();

      // sideAttachments filtrele
      final updatedAttachments = spec.sideAttachments
          .where((a) => !sideIdsToDelete.contains(a.side))
          .toList();

      final updated = spec.copyWith(
        internalElements: updatedElements,
        sideAttachments: updatedAttachments,
      );
      controller.updateShape(controllerState.selectedIndex, updated);

      final deletedCount = elementIdsToDelete.length + sideIdsToDelete.length;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$deletedCount adet şekil silindi'),
            duration: const Duration(milliseconds: 1000),
          ),
        );
      }
    }
  }

  void _deleteCurrentShapeAndNavigate() async {
    final controllerState = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )),
    );

    if (controllerState.shapes.length <= 1) {
      await ref
          .read(drawingProvider(widget.projectId).notifier)
          .deleteDrawing(widget.drawingId);

      if (mounted) Navigator.pop(context);
      return;
    }

    final controller = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )).notifier,
    );
    controller.deleteShape(controllerState.selectedIndex);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Çizim silindi'),
        duration: Duration(milliseconds: 800),
      ),
    );
  }

  void _showPanelEditorForHorizontalLine(InternalElement element) async {
    if (!mounted) return;
    final controllerState = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )),
    );
    final controller = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )).notifier,
    );

    final stillExists =
        controllerState.currentShape?.internalElements.any(
          (e) => e.id == element.id,
        ) ??
        false;

    if (!stillExists) return;

    if (controllerState.currentShape == null) return;
    final spec = controllerState.currentShape!;

    final horizontalLines =
        spec.internalElements
            .where(
              (e) =>
                  e.type == InternalElementType.horizontalLine &&
                  e.properties['isShort'] != true,
            )
            .toList()
          ..sort((a, b) => a.position.dy.compareTo(b.position.dy));

    final lineIndex = horizontalLines.indexWhere((l) => l.id == element.id);
    if (lineIndex == -1) return;

    final gaps = GapCalculator.calculateGaps(spec, horizontalLines);
    final shortHorizontalLines = spec.internalElements
        .where(
          (e) =>
              e.type == InternalElementType.horizontalLine &&
              e.properties['isShort'] == true,
        )
        .toList();

    final result = await showDialog<List<double>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SectionEditorDialog(
        axis: SectionAxis.horizontal,
        shapeSpec: spec,
        totalSize: spec.baseHeight,
        initialGaps: gaps,
        shortLines: shortHorizontalLines,
        selectedLineIndex: lineIndex,
        onShortLineChanged: (id, newY) {
          controller.updateShortHorizontalLine(id, newY);
        },
      ),
    );

    if (result != null && mounted) {
      GapCalculator.applyNewGaps(controller, horizontalLines, result);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Panel ölçüleri güncellendi'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _showVerticalPanelEditor(InternalElement element) async {
    if (!mounted) return;

    final controllerState = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )),
    );
    final controller = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )).notifier,
    );

    if (controllerState.currentShape == null) return;
    final spec = controllerState.currentShape!;

    final verticalLines =
        spec.internalElements
            .where(
              (e) =>
                  e.type == InternalElementType.verticalLine &&
                  e.properties['isShort'] != true,
            )
            .toList()
          ..sort((a, b) => a.position.dx.compareTo(b.position.dx));

    final lineIndex = verticalLines.indexWhere((l) => l.id == element.id);
    if (lineIndex == -1) return;

    final gaps = GapCalculator.calculateVerticalGaps(spec, verticalLines);
    final shortVerticalLines = spec.internalElements
        .where(
          (e) =>
              e.type == InternalElementType.verticalLine &&
              e.properties['isShort'] == true,
        )
        .toList();

    final result = await showDialog<List<double>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SectionEditorDialog(
        axis: SectionAxis.vertical,
        shapeSpec: spec,
        totalSize: spec.baseWidth,
        initialGaps: gaps,
        shortLines: shortVerticalLines,
        selectedLineIndex: lineIndex,
        onShortLineChanged: (id, newX) {
          controller.updateShortVerticalLine(id, newX);
        },
      ),
    );

    if (result != null && mounted) {
      GapCalculator.applyNewVerticalGaps(controller, verticalLines, result);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dikey panel ölçüleri güncellendi'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _clearPreview() {
    setState(() {
      _previewHorizontalLineY = null;
      _previewVerticalLineX = null;
      _previewShortHorizontalLineY = null;
      _previewShortVerticalLineX = null;
      _sidePreviewSide = null;
      _sidePreviewLocalY = null;
      _sidePreviewLocalX = null;
    });
  }

  Widget _buildSingleShapeCanvas(
    ShapeSpec? currentShape,
    ToolMode currentTool,
  ) {
    if (currentShape == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.crop_square, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Henüz şekil yok',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);

        final lineDragTool = LineDragTool(
          ref: ref,
          context: context,
          projectId: widget.projectId,
          drawingId: widget.drawingId,
          onHorizontalPreviewChanged: (mmY) =>
              setState(() => _previewHorizontalLineY = mmY),
          onVerticalPreviewChanged: (mmX) =>
              setState(() => _previewVerticalLineX = mmX),
          onClearPreview: _clearPreview,
        );

        final shortLineDragTool = ShortLineDragTool(ref: ref, context: context);

        final isDrawingLine = [
          ToolMode.horizontalLine,
          ToolMode.verticalLine,
          ToolMode.shortHorizontalLine,
          ToolMode.shortVerticalLine,
        ].contains(currentTool);

        final bounds = ShapeCropGeometry.totalBounds(currentShape);
        const padding = 0.75;
        final scaleX = (canvasSize.width * padding) / bounds.width;
        final scaleY = (canvasSize.height * padding) / bounds.height;
        final scale = math.min(scaleX, scaleY);

        final scaledW = bounds.width * scale;
        final scaledH = bounds.height * scale;

        const leftMeasureSpace = 40.0;
        const rightSpace = 20.0;
        const bottomMeasureSpace = 30.0;
        const topSpace = 20.0;

        final usableWidth = canvasSize.width - leftMeasureSpace - rightSpace;
        final usableHeight = canvasSize.height - bottomMeasureSpace - topSpace;

        final offsetX = leftMeasureSpace + (usableWidth - scaledW) / 2;
        final offsetY = topSpace + (usableHeight - scaledH) / 2;

        if (_canvasScale != scale ||
            _canvasOffset != Offset(offsetX, offsetY)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _canvasScale = scale;
                _canvasOffset = Offset(offsetX, offsetY);
              });
            }
          });
        }

        return Listener(
          onPointerDown: (_) {
            if (!isDrawingLine) {
              _panEnableTimer?.cancel();
              _panEnableTimer = Timer(const Duration(seconds: 5), () {
                if (mounted) setState(() => _canPan = true);
              });
            }
          },
          onPointerUp: (_) {
            _panEnableTimer?.cancel();
            if (_canPan) setState(() => _canPan = false);
          },
          onPointerCancel: (_) {
            _panEnableTimer?.cancel();
            if (_canPan) setState(() => _canPan = false);
          },
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 0.5,
            maxScale: 5.0,
            boundaryMargin: const EdgeInsets.all(500),
            panEnabled: _canPan && !isDrawingLine,
            scaleEnabled: !isDrawingLine, // zoom her zaman serbest
            constrained: true,
            child: Container(
              width: canvasSize.width,
              height: canvasSize.height,
              color: Colors.white,
              child: isDrawingLine
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (details) {
                        final pos = details.localPosition;
                        final mmPos = _screenToMm(pos);

                        // 🆕 Drag yan panelde başladıysa orada devam et:
                        // gölgeyi imleci takip edecek şekilde güncelle.
                        if (_dragInSidePanel) {
                          final sideHit =
                              PanelHitTester.findSidePanelAtPosition(
                                currentShape,
                                mmPos,
                              );
                          if (sideHit != null) {
                            final attach = sideHit['attach'] as SideAttachment;
                            setState(() {
                              _dragSidePanelSide = sideHit['side'] as String;
                              _dragSideAttach = attach;
                              _sidePreviewSide = sideHit['side'] as String;
                              if (currentTool == ToolMode.horizontalLine) {
                                _sidePreviewLocalY =
                                    (sideHit['localY'] as double).clamp(
                                      0.0,
                                      attach.height,
                                    );
                                _sidePreviewLocalX = null;
                              } else if (currentTool == ToolMode.verticalLine) {
                                _sidePreviewLocalX =
                                    (sideHit['localX'] as double).clamp(
                                      0.0,
                                      attach.width,
                                    );
                                _sidePreviewLocalY = null;
                              } else if (currentTool ==
                                  ToolMode.shortHorizontalLine) {
                                _sidePreviewLocalY =
                                    (sideHit['localY'] as double).clamp(
                                      0.0,
                                      attach.height,
                                    );
                                _sidePreviewLocalX =
                                    (sideHit['localX'] as double).clamp(
                                      0.0,
                                      attach.width,
                                    );
                              } else if (currentTool ==
                                  ToolMode.shortVerticalLine) {
                                _sidePreviewLocalX =
                                    (sideHit['localX'] as double).clamp(
                                      0.0,
                                      attach.width,
                                    );
                                _sidePreviewLocalY =
                                    (sideHit['localY'] as double).clamp(
                                      0.0,
                                      attach.height,
                                    );
                              }
                            });
                          }
                          return;
                        }

                        switch (currentTool) {
                          case ToolMode.horizontalLine:
                            // 🆕 Yan panel kontrolü
                            final sideHit =
                                PanelHitTester.findSidePanelAtPosition(
                                  currentShape,
                                  mmPos,
                                );
                            if (sideHit != null) {
                              final attach =
                                  sideHit['attach'] as SideAttachment;
                              setState(() {
                                _dragInSidePanel = true;
                                _dragSidePanelSide = sideHit['side'] as String;
                                _dragSideAttach = attach;
                                // Ana şekil önizlemesini temizle ki gölge
                                // ana şeklin üzerinde görünmesin.
                                _previewHorizontalLineY = null;
                                _previewVerticalLineX = null;
                                _sidePreviewSide = sideHit['side'] as String;
                                _sidePreviewLocalX = null;
                                _sidePreviewLocalY =
                                    (sideHit['localY'] as double).clamp(
                                      0.0,
                                      attach.height,
                                    );
                              });
                              return;
                            }
                            lineDragTool.onHorizontalPanUpdate(
                              pos,
                              _screenToMm,
                            );
                            break;

                          case ToolMode.verticalLine:
                            final sideHit =
                                PanelHitTester.findSidePanelAtPosition(
                                  currentShape,
                                  mmPos,
                                );
                            if (sideHit != null) {
                              final attach =
                                  sideHit['attach'] as SideAttachment;
                              setState(() {
                                _dragInSidePanel = true;
                                _dragSidePanelSide = sideHit['side'] as String;
                                _dragSideAttach = attach;
                                _previewHorizontalLineY = null;
                                _previewVerticalLineX = null;
                                _sidePreviewSide = sideHit['side'] as String;
                                _sidePreviewLocalY = null;
                                _sidePreviewLocalX =
                                    (sideHit['localX'] as double).clamp(
                                      0.0,
                                      attach.width,
                                    );
                              });
                              return;
                            }
                            lineDragTool.onVerticalPanUpdate(pos, _screenToMm);
                            break;

                          case ToolMode.shortHorizontalLine:
                            _updatePreviewShortHorizontalLine(pos);
                            break;
                          case ToolMode.shortVerticalLine:
                            _updatePreviewShortVerticalLine(pos);
                            break;
                          default:
                            break;
                        }
                      },

                      onPanEnd: (_) {
                        // 🆕 Yan panel drag'i bitişi
                        if (_dragInSidePanel) {
                          final controllerState = ref.read(
                            drawingControllerProvider((
                              projectId: widget.projectId,
                              drawingId: widget.drawingId,
                            )),
                          );
                          final controller = ref.read(
                            drawingControllerProvider((
                              projectId: widget.projectId,
                              drawingId: widget.drawingId,
                            )).notifier,
                          );
                          final spec = controllerState.currentShape;

                          if (spec != null &&
                              _dragSideAttach != null &&
                              _dragSidePanelSide != null) {
                            SideAttachment updated;

                            if (currentTool == ToolMode.horizontalLine &&
                                _sidePreviewLocalY != null) {
                              updated = SidePanelToolHandler.addHorizontalLine(
                                _dragSideAttach!,
                                _sidePreviewLocalY!,
                              );
                            } else if (currentTool == ToolMode.verticalLine &&
                                _sidePreviewLocalX != null) {
                              updated = SidePanelToolHandler.addVerticalLine(
                                _dragSideAttach!,
                                _sidePreviewLocalX!,
                              );
                            } else if (currentTool ==
                                    ToolMode.shortHorizontalLine &&
                                _sidePreviewLocalY != null &&
                                _sidePreviewLocalX != null) {
                              updated =
                                  SidePanelToolHandler.addShortHorizontalLine(
                                    _dragSideAttach!,
                                    _sidePreviewLocalX!,
                                    _sidePreviewLocalY!,
                                  );
                            } else if (currentTool ==
                                    ToolMode.shortVerticalLine &&
                                _sidePreviewLocalX != null &&
                                _sidePreviewLocalY != null) {
                              updated =
                                  SidePanelToolHandler.addShortVerticalLine(
                                    _dragSideAttach!,
                                    _sidePreviewLocalX!,
                                    _sidePreviewLocalY!,
                                  );
                            } else {
                              // Geçersiz state — sadece temizle
                              setState(() {
                                _dragInSidePanel = false;
                                _dragSidePanelSide = null;
                                _dragSideAttach = null;
                              });
                              _clearPreview();
                              return;
                            }

                            final newSpec =
                                SidePanelToolHandler.updateAttachInSpec(
                                  spec,
                                  _dragSidePanelSide!,
                                  updated,
                                );
                            controller.updateShape(
                              controllerState.selectedIndex,
                              newSpec,
                            );

                            // Uzun çizgi eklendiyse editörü otomatik aç
                            if (currentTool == ToolMode.horizontalLine ||
                                currentTool == ToolMode.verticalLine) {
                              final savedSide = _dragSidePanelSide!;
                              final addedElement =
                                  updated.internalElements.last;
                              final isH =
                                  currentTool == ToolMode.horizontalLine;

                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                final freshSpec = ref
                                    .read(
                                      drawingControllerProvider((
                                        projectId: widget.projectId,
                                        drawingId: widget.drawingId,
                                      )),
                                    )
                                    .currentShape;
                                if (freshSpec == null) return;
                                final freshAttach = freshSpec.sideAttachments
                                    .firstWhere((a) => a.side == savedSide);
                                if (isH) {
                                  showSidePanelHorizontalEditor(
                                    savedSide,
                                    freshAttach,
                                    addedElement,
                                  );
                                } else {
                                  showSidePanelVerticalEditor(
                                    savedSide,
                                    freshAttach,
                                    addedElement,
                                  );
                                }
                              });
                            }

                            ref.read(toolModeProvider.notifier).reset();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  currentTool == ToolMode.horizontalLine ||
                                          currentTool ==
                                              ToolMode.shortHorizontalLine
                                      ? 'Yan panele yatay çizgi eklendi'
                                      : 'Yan panele dikey çizgi eklendi',
                                ),
                                duration: const Duration(milliseconds: 500),
                              ),
                            );
                          }

                          setState(() {
                            _dragInSidePanel = false;
                            _dragSidePanelSide = null;
                            _dragSideAttach = null;
                          });
                          _clearPreview();
                          return; // ← ana şekil onPanEnd çalışmaz
                        }
                        switch (currentTool) {
                          case ToolMode.horizontalLine:
                            lineDragTool.onHorizontalPanEnd(
                              _previewHorizontalLineY,
                              _addHorizontalLineAtY,
                            );
                            break;
                          case ToolMode.verticalLine:
                            lineDragTool.onVerticalPanEnd(
                              _previewVerticalLineX,
                              _addVerticalLineAtX,
                            );
                            break;
                          case ToolMode.shortHorizontalLine:
                            shortLineDragTool.onHorizontalPanEnd(
                              _previewShortHorizontalLineY,
                              _lastShortHorizontalMmPos,
                              _addShortHorizontalLineAtMm,
                              _clearPreview,
                            );
                            break;
                          case ToolMode.shortVerticalLine:
                            shortLineDragTool.onVerticalPanEnd(
                              _previewShortVerticalLineX,
                              _lastShortVerticalMmPos,
                              _addShortVerticalLineAtMm,
                              _clearPreview,
                            );
                            break;
                          default:
                            _clearPreview();
                        }
                      },
                      child: CustomPaint(
                        size: canvasSize,
                        painter: ShapePainter(
                          currentShape,
                          sideAttachments: currentShape.sideAttachments,
                          selectedElementId: _selectedHorizontalLineId,
                          previewHorizontalLineY: _previewHorizontalLineY,
                          previewVerticalLineX: _previewVerticalLineX,
                          previewShortHorizontalLineY:
                              _previewShortHorizontalLineY,
                          previewShortVerticalLineX: _previewShortVerticalLineX,
                          sidePreviewSide: _sidePreviewSide,
                          sidePreviewLocalY: _sidePreviewLocalY,
                          sidePreviewLocalX: _sidePreviewLocalX,
                        ),
                      ),
                    )
                  : Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (event) {
                        _processTap(event.localPosition);
                      },
                      child: CustomPaint(
                        size: canvasSize,
                        painter: ShapePainter(
                          currentShape,
                          sideAttachments: currentShape.sideAttachments,
                          selectedElementId: _selectedHorizontalLineId,
                        ),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  void _addShortHorizontalLineAtMm(Offset mmPos) {
    final controllerState = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )),
    );
    final controller = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )).notifier,
    );

    if (controllerState.currentShape == null) return;
    final spec = controllerState.currentShape!;

    final sidePanel = PanelHitTester.findSidePanelAtPosition(spec, mmPos);
    if (sidePanel != null) {
      final side = sidePanel['side'] as String;
      final attach = sidePanel['attach'] as SideAttachment;
      final localX = sidePanel['localX'] as double;
      final localY = sidePanel['localY'] as double;

      final verticalXs = <double>{};
      for (final e in attach.internalElements) {
        if (e.type == InternalElementType.verticalLine) {
          final isShort = e.properties['isShort'] == true;
          if (isShort) {
            final vTop = e.position.dy;
            final vBot = e.position.dy - e.size.height;
            if (localY < vBot || localY > vTop) continue;
          }
          verticalXs.add(e.position.dx);
        }
      }
      verticalXs.add(0);
      verticalXs.add(attach.width);
      final sortedXs = verticalXs.toList()..sort();

      double leftBound = 0;
      double rightBound = attach.width;
      for (int i = 0; i < sortedXs.length - 1; i++) {
        // ← Eski kod localY ile karşılaştırıyordu — localX olmalı!
        if (sortedXs[i] <= localX && localX <= sortedXs[i + 1]) {
          leftBound = sortedXs[i];
          rightBound = sortedXs[i + 1];
          break;
        }
      }

      final newElement = InternalElement(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: InternalElementType.horizontalLine,
        position: Offset(leftBound, localY),
        size: Size(rightBound - leftBound, 2),
        rotation: 0,
        properties: {'isShort': true},
      );
      _addElementToSidePanel(side, attach, newElement);
      ref.read(toolModeProvider.notifier).reset();
      _clearPreview();
      return;
    }

    final panel = PanelHitTester.findPanelAtPosition(spec, mmPos);
    if (panel != null) {
      final panelLeft = panel['leftX']!;
      final panelRight = panel['rightX']!;
      final panelTopY = panel['topY']!;
      final panelBottomY = panel['bottomY']!;
      final minY = panelBottomY + 10;
      final maxY = panelTopY - 10;
      final clampedY = minY > maxY
          ? (panelTopY + panelBottomY) / 2
          : mmPos.dy.clamp(minY, maxY);

      final verticalXs = <double>{};
      for (final e in spec.internalElements) {
        if (e.type != InternalElementType.verticalLine) continue;
        final x = e.position.dx;
        final yTop = e.position.dy;
        final yBottom = e.position.dy - e.size.height;
        if (yTop >= clampedY &&
            yBottom <= clampedY &&
            x >= panelLeft &&
            x <= panelRight) {
          verticalXs.add(x);
        }
      }
      verticalXs.add(panelLeft);
      verticalXs.add(panelRight);
      final sortedXs = verticalXs.toList()..sort();

      double leftBound = panelLeft;
      double rightBound = panelRight;
      for (int i = 0; i < sortedXs.length - 1; i++) {
        if (sortedXs[i] <= mmPos.dx && mmPos.dx <= sortedXs[i + 1]) {
          leftBound = sortedXs[i];
          rightBound = sortedXs[i + 1];
          break;
        }
      }

      final cropLeft = ShapeCropGeometry.leftXAtY(spec, clampedY);
      final cropRight = ShapeCropGeometry.rightXAtY(spec, clampedY);
      final finalLeft = math.max(leftBound, cropLeft);
      final finalRight = math.min(rightBound, cropRight);
      if (finalRight - finalLeft < 10) return;

      final newElement = InternalElement(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: InternalElementType.horizontalLine,
        position: Offset(finalLeft, clampedY),
        size: Size(finalRight - finalLeft, 2),
        rotation: 0,
        properties: {'isShort': true},
      );
      controller.addInternalElement(newElement);
      ref.read(toolModeProvider.notifier).reset();
      _clearPreview();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kısa yatay çizgi eklendi'),
          duration: Duration(milliseconds: 500),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bir panel veya yan panel seçin')),
    );
  }

  void _addShortVerticalLineAtMm(Offset mmPos) {
    final controllerState = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )),
    );
    final controller = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )).notifier,
    );

    if (controllerState.currentShape == null) return;
    final spec = controllerState.currentShape!;

    final sidePanel = PanelHitTester.findSidePanelAtPosition(spec, mmPos);
    if (sidePanel != null) {
      final side = sidePanel['side'] as String;
      final attach = sidePanel['attach'] as SideAttachment;
      final localX = sidePanel['localX'] as double;
      final localY = sidePanel['localY'] as double;

      final horizontalYs = <double>[];
      for (final e in attach.internalElements) {
        if (e.type == InternalElementType.horizontalLine) {
          final isShort = e.properties['isShort'] == true;
          if (isShort) {
            final hLeft = e.position.dx;
            final hRight = e.position.dx + e.size.width;
            if (localX < hLeft || localX > hRight) continue;
          }
          horizontalYs.add(e.position.dy);
        }
      }
      horizontalYs.add(0);
      horizontalYs.add(attach.height);
      horizontalYs.sort((a, b) => b.compareTo(a));

      double topBound = attach.height;
      double bottomBound = 0;
      for (int i = 0; i < horizontalYs.length - 1; i++) {
        // ← Eski kod localX ile karşılaştırıyordu — localY olmalı!
        if (horizontalYs[i] >= localY && localY >= horizontalYs[i + 1]) {
          topBound = horizontalYs[i];
          bottomBound = horizontalYs[i + 1];
          break;
        }
      }

      final newElement = InternalElement(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: InternalElementType.verticalLine,
        position: Offset(localX, topBound),
        size: Size(2, topBound - bottomBound),
        rotation: 0,
        properties: {'isShort': true},
      );
      _addElementToSidePanel(side, attach, newElement);
      ref.read(toolModeProvider.notifier).reset();
      _clearPreview();
      return;
    }

    final panel = PanelHitTester.findPanelAtPosition(spec, mmPos);
    if (panel != null) {
      final panelLeft = panel['leftX']!;
      final panelRight = panel['rightX']!;
      final panelTopY = panel['topY']!;
      final panelBottomY = panel['bottomY']!;
      final minX = panelLeft + 10;
      final maxX = panelRight - 10;
      final clampedX = minX > maxX
          ? (panelLeft + panelRight) / 2
          : mmPos.dx.clamp(minX, maxX);

      final horizontalYs = <double>[];
      for (final e in spec.internalElements) {
        if (e.type != InternalElementType.horizontalLine) continue;
        final y = e.position.dy;
        final xLeft = e.position.dx;
        final xRight = e.position.dx + e.size.width;
        if (xRight >= clampedX &&
            xLeft <= clampedX &&
            y >= panelBottomY &&
            y <= panelTopY) {
          horizontalYs.add(y);
        }
      }
      horizontalYs.add(panelBottomY);
      horizontalYs.add(panelTopY);
      horizontalYs.sort((a, b) => b.compareTo(a));

      double topBound = panelTopY;
      double bottomBound = panelBottomY;
      for (int i = 0; i < horizontalYs.length - 1; i++) {
        if (horizontalYs[i] >= mmPos.dy && mmPos.dy >= horizontalYs[i + 1]) {
          topBound = horizontalYs[i];
          bottomBound = horizontalYs[i + 1];
          break;
        }
      }

      final cropTop = ShapeCropGeometry.topYAtX(spec, clampedX);
      final cropBottom = ShapeCropGeometry.bottomYAtX(spec, clampedX);
      final finalTop = math.min(topBound, cropTop);
      final finalBottom = math.max(bottomBound, cropBottom);
      if (finalTop - finalBottom < 10) return;

      final newElement = InternalElement(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: InternalElementType.verticalLine,
        position: Offset(clampedX, finalTop),
        size: Size(2, finalTop - finalBottom),
        rotation: 0,
        properties: {'isShort': true},
      );
      controller.addInternalElement(newElement);
      ref.read(toolModeProvider.notifier).reset();
      _clearPreview();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kısa dikey çizgi eklendi'),
          duration: Duration(milliseconds: 500),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bir panel veya yan panel seçin')),
    );
  }

  void _updatePreviewShortHorizontalLine(Offset localPosition) {
    final controllerState = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )),
    );
    if (controllerState.currentShape == null) return;
    final mmPos = _screenToMm(localPosition);
    final spec = controllerState.currentShape!;

    // 🆕 Yan panel kontrolü — kısa yatay çizgi
    final sideHit = PanelHitTester.findSidePanelAtPosition(spec, mmPos);
    if (sideHit != null) {
      final attach = sideHit['attach'] as SideAttachment;
      setState(() {
        _dragInSidePanel = true;
        _dragSidePanelSide = sideHit['side'] as String;
        _dragSideAttach = attach;
        _previewShortHorizontalLineY = null;
        _sidePreviewSide = sideHit['side'] as String;
        _sidePreviewLocalY = (sideHit['localY'] as double).clamp(
          0.0,
          attach.height,
        );
        _sidePreviewLocalX = (sideHit['localX'] as double).clamp(
          0.0,
          attach.width,
        );
      });
      return;
    }

    final panel = PanelHitTester.findPanelAtPosition(
      spec,
      mmPos,
      snapToNearest: true,
    );
    if (panel == null) {
      setState(() {
        _previewShortHorizontalLineY = null;
        _lastShortHorizontalMmPos = null;
      });
      return;
    }
    final bottomY = panel['bottomY']!;
    final topY = panel['topY']!;
    final minY = bottomY + 10;
    final maxY = topY - 10;
    final mmY = minY > maxY ? (topY + bottomY) / 2 : mmPos.dy.clamp(minY, maxY);

    setState(() {
      _previewShortHorizontalLineY = mmY;
      _lastShortHorizontalMmPos = mmPos;
    });
  }

  void _updatePreviewShortVerticalLine(Offset localPosition) {
    final controllerState = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )),
    );
    if (controllerState.currentShape == null) return;
    final mmPos = _screenToMm(localPosition);
    final spec = controllerState.currentShape!;

    // 🆕 Yan panel kontrolü — kısa dikey çizgi
    final sideHit = PanelHitTester.findSidePanelAtPosition(spec, mmPos);
    if (sideHit != null) {
      final attach = sideHit['attach'] as SideAttachment;
      setState(() {
        _dragInSidePanel = true;
        _dragSidePanelSide = sideHit['side'] as String;
        _dragSideAttach = attach;
        _previewShortVerticalLineX = null;
        _sidePreviewSide = sideHit['side'] as String;
        _sidePreviewLocalX = (sideHit['localX'] as double).clamp(
          0.0,
          attach.width,
        );
        _sidePreviewLocalY = (sideHit['localY'] as double).clamp(
          0.0,
          attach.height,
        );
      });
      return;
    }

    final panel = PanelHitTester.findPanelAtPosition(spec, mmPos);
    if (panel == null) {
      setState(() {
        _previewShortVerticalLineX = null;
        _lastShortVerticalMmPos = null;
      });
      return;
    }

    final leftX = panel['leftX']!;
    final rightX = panel['rightX']!;
    final minX = leftX + 10;
    final maxX = rightX - 10;
    final mmX = minX > maxX ? (leftX + rightX) / 2 : mmPos.dx.clamp(minX, maxX);

    setState(() {
      _previewShortVerticalLineX = mmX;
      _lastShortVerticalMmPos = mmPos;
    });
  }

  void _addVerticalLineAtX(double mmX) {
    final controllerState = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )),
    );

    if (controllerState.currentShape == null) return;

    final spec = controllerState.currentShape!;
    final yTop = ShapeCropGeometry.topYAtX(spec, mmX);
    final yBottom = ShapeCropGeometry.bottomYAtX(spec, mmX);
    final height = yTop - yBottom;

    if (height < 10) return;

    final newElement = InternalElement(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: InternalElementType.verticalLine,
      position: Offset(mmX, yTop),
      size: Size(2, height),
      rotation: 0,
      properties: {},
    );

    final controller = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )).notifier,
    );

    controller.addInternalElement(newElement);

    setState(() {
      _showSideHandles = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showVerticalPanelEditor(newElement);
    });
  }

  void _addHorizontalLineAtY(double mmY) {
    final controllerState = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )),
    );
    final controller = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )).notifier,
    );

    if (controllerState.currentShape == null) return;

    final spec = controllerState.currentShape!;
    final xLeft = ShapeCropGeometry.leftXAtY(spec, mmY);
    final xRight = ShapeCropGeometry.rightXAtY(spec, mmY);

    if ((xRight - xLeft) < 10) return;

    for (final element in spec.internalElements) {
      if (element.type == InternalElementType.horizontalLine &&
          element.position.dy == mmY) {
        return;
      }
    }

    final newElement = InternalElement(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: InternalElementType.horizontalLine,
      position: Offset(xLeft, mmY),
      size: Size(xRight - xLeft, 2),
      rotation: 0,
      properties: {},
    );

    controller.addInternalElement(newElement);
    setState(() => _showSideHandles = false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showPanelEditorForHorizontalLine(newElement);
    });
  }

  void _addLineGridToPanel(Offset position) {
    final controllerState = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )),
    );
    final controller = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )).notifier,
    );

    if (controllerState.currentShape == null) return;
    final spec = controllerState.currentShape!;
    final mmPos = _screenToMm(position);
    // 🆕 YAN PANEL KONTROLÜ — erken çıkış
    final sideHit = PanelHitTester.findSidePanelAtPosition(spec, mmPos);
    if (sideHit != null) {
      final side = sideHit['side'] as String;
      final attach = sideHit['attach'] as SideAttachment;
      final localX = sideHit['localX'] as double;
      final localY = sideHit['localY'] as double;
      final updated = SidePanelToolHandler.addLineGrid(attach, localX, localY);
      if (updated == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu yan panelde zaten camsız profil var'),
            duration: Duration(milliseconds: 1200),
          ),
        );
        return;
      }
      final newSpec = SidePanelToolHandler.updateAttachInSpec(
        spec,
        side,
        updated,
      );
      controller.updateShape(controllerState.selectedIndex, newSpec);
      ref.read(toolModeProvider.notifier).reset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yan panele camsız profil eklendi'),
          duration: Duration(milliseconds: 500),
        ),
      );
      return; // ← ana şekil kodu çalışmaz
    }

    final panel = PanelHitTester.findPanelAtPosition(
      spec,
      mmPos,
      includeShortLines: true,
    );
    if (panel == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bir panel seçin')));
      return;
    }

    if (LineGridTool.alreadyExists(spec, panel)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu panelde zaten çizgili cam var'),
          duration: Duration(milliseconds: 1200),
        ),
      );
      return;
    }

    try {
      final element = LineGridTool.createForPanel(panel);
      controller.addInternalElement(element);
      ref.read(toolModeProvider.notifier).reset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Çizgili cam eklendi'),
          duration: Duration(milliseconds: 500),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Çizgili cam eklenemedi: $e')));
    }
  }

  void _createNewShape() async {
    final result = await showDialog<ShapeSpec>(
      context: context,
      builder: (context) => MeasureDialog(
        initial: ShapeSpec.rectangle(width: 1000, height: 1000),
        title: "Yeni Pencere Şekli",
      ),
    );

    if (result != null) {
      final controller = ref.read(
        drawingControllerProvider((
          projectId: widget.projectId,
          drawingId: widget.drawingId,
        )).notifier,
      );
      controller.addShape(result);
    }
  }

  void _editShape() async {
    final controllerState = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )),
    );

    if (controllerState.currentShape == null) return;

    final result = await showDialog<ShapeSpec>(
      context: context,
      builder: (context) => MeasureDialog(
        initial: controllerState.currentShape!,
        title: "Ölçüleri Düzenle",
      ),
    );

    if (result != null) {
      final controller = ref.read(
        drawingControllerProvider((
          projectId: widget.projectId,
          drawingId: widget.drawingId,
        )).notifier,
      );
      controller.updateShape(controllerState.selectedIndex, result);
    }
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
    setState(() => _currentScale = 1.0);
  }

  void _updateScale() {
    final matrix = _transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();
    setState(() => _currentScale = scale);
  }

  void _selectShape(int index) {
    final controller = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )).notifier,
    );
    controller.selectShape(index);
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )),
    );

    final currentTool = ref.watch(toolModeProvider);
    final controller = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )).notifier,
    );

    final shapes = controllerState.shapes;
    final currentShape = controllerState.currentShape;
    const double drawingOpenHeight = 70.0;
    final double navBarHeight = MediaQuery.of(context).padding.bottom;
    final double handleBottom = _isSystemPanelOpen
        ? _systemPanelHeight
        : (_isShapeListPanelOpen && shapes.length > 1
              ? drawingOpenHeight + navBarHeight
              : navBarHeight);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0, // ← geri okuna yaklaştırır
        title: () {
          final parts = widget.customerName.trim().split(' ');
          final firstName = parts.first;
          final lastName = parts.length > 1 ? parts.skip(1).join(' ') : '';
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                firstName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
              if (lastName.isNotEmpty)
                Text(
                  lastName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
            ],
          );
        }(),
        backgroundColor: const Color.fromARGB(255, 110, 178, 247),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo, size: 20),
            onPressed: controllerState.canUndo ? () => controller.undo() : null,
            tooltip: 'Geri Al',
            color: controllerState.canUndo ? Colors.white : Colors.white54,
          ),
          IconButton(
            icon: const Icon(Icons.redo, size: 20),
            onPressed: controllerState.canRedo ? () => controller.redo() : null,
            tooltip: 'İleri Al',
            color: controllerState.canRedo ? Colors.white : Colors.white54,
          ),
          const SizedBox(width: 4),
          if (_currentScale != 1.0)
            Chip(
              label: Text(
                '%${(_currentScale * 100).toInt()}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color.fromARGB(179, 14, 13, 13),
                ),
              ),
              backgroundColor: Colors.transparent,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              side: BorderSide.none,
            ),
          IconButton(
            icon: const Icon(Icons.zoom_out_map, size: 20),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            onPressed: _resetZoom,
            tooltip: 'Zoom Sıfırla',
          ),
          IconButton(
            // YENİ:
            icon: Icon(
              _showSideHandles ? Icons.visibility : Icons.visibility_off,
              color: !_hasAnyMaterial(controllerState.currentShape)
                  ? const Color.fromARGB(255, 3, 3, 3)
                  : Colors.white38,
            ),
            onPressed: !_hasAnyMaterial(controllerState.currentShape)
                ? () => setState(() => _showSideHandles = !_showSideHandles)
                : null,
            tooltip: 'Panelleri Göster/Gizle',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopToolbar(currentTool),
              Expanded(
                child: Container(
                  color: const Color.fromARGB(255, 236, 236, 236),
                  child: _buildSingleShapeCanvas(currentShape, currentTool),
                ),
              ),
            ],
          ),
          CornerSidePanels(
            projectId: widget.projectId,
            drawingId: widget.drawingId,
            currentShape: currentShape,
            showSideHandles: _showSideHandles,
          ),
          _buildBottomShapePanel(controller, shapes, navBarHeight),
          SystemBottomPanel(
            projectId: widget.projectId,
            drawingId: widget.drawingId,
            isVisible: true,
            hasDrawingTableHandle: shapes.length > 1,
            isDrawingOpen: _isShapeListPanelOpen && shapes.length > 1,
            drawingHandleBottom: handleBottom,
            onToggle: () =>
                setState(() => _isNewBottomPanelOpen = !_isNewBottomPanelOpen),
            onOpenChanged: (isOpen) => setState(() {
              _isSystemPanelOpen = isOpen;
              if (isOpen) _isShapeListPanelOpen = false;
            }),
            onHeightChanged: (h) => setState(() => _systemPanelHeight = h),
          ),
        ],
      ),
    );
  }

  void _addTriangleToPanel(Offset position, ToolMode toolMode) {
    final controllerState = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )),
    );
    final controller = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )).notifier,
    );

    if (controllerState.currentShape == null) return;
    final spec = controllerState.currentShape!;
    final mmPos = _screenToMm(position);
    final direction = TriangleTool.directionFromTool(toolMode);

    // 🆕 YAN PANEL KONTROLÜ — erken çıkış
    final sideHit = PanelHitTester.findSidePanelAtPosition(spec, mmPos);
    if (sideHit != null) {
      final side = sideHit['side'] as String;
      final attach = sideHit['attach'] as SideAttachment;
      final updated = SidePanelToolHandler.addTriangle(attach, direction);
      final newSpec = SidePanelToolHandler.updateAttachInSpec(
        spec,
        side,
        updated,
      );
      controller.updateShape(controllerState.selectedIndex, newSpec);
      _resetToolAndNotify('Yan panele üçgen eklendi');
      return; // ← ana şekil kodu çalışmaz
    }

    final panel = PanelHitTester.findPanelAtPosition(
      spec,
      mmPos,
      includeShortLines: true,
    );
    if (panel != null) {
      final element = TriangleTool.createForMainPanel(panel, direction, spec);
      controller.addInternalElement(element);
      _resetToolAndNotify('Üçgen eklendi');
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Bir panel seçin')));
  }

  void _resetToolAndNotify(String message) {
    ref.read(toolModeProvider.notifier).reset();
    setState(() {
      _showSideHandles = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _addSlideArrowToPanel(Offset position, ToolMode toolMode) {
    final controllerState = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )),
    );
    final controller = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )).notifier,
    );

    if (controllerState.currentShape == null) return;
    final spec = controllerState.currentShape!;
    final mmPos = _screenToMm(position);
    final direction = toolMode == ToolMode.slideRight ? 'right' : 'left';

    // 🆕 YAN PANEL KONTROLÜ — erken çıkış
    final sideHit = PanelHitTester.findSidePanelAtPosition(spec, mmPos);
    if (sideHit != null) {
      final side = sideHit['side'] as String;
      final attach = sideHit['attach'] as SideAttachment;
      final localX = sideHit['localX'] as double;
      final localY = sideHit['localY'] as double;
      final updated = SidePanelToolHandler.addSlideArrow(
        attach,
        direction,
        localX,
        localY,
      );
      final newSpec = SidePanelToolHandler.updateAttachInSpec(
        spec,
        side,
        updated,
      );
      controller.updateShape(controllerState.selectedIndex, newSpec);
      ref.read(toolModeProvider.notifier).reset();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            direction == 'right'
                ? 'Yan panele sağa ok eklendi'
                : 'Yan panele sola ok eklendi',
          ),
          duration: const Duration(milliseconds: 500),
        ),
      );
      return; // ← ana şekil kodu çalışmaz
    }

    final panel = PanelHitTester.findPanelAtPosition(
      spec,
      mmPos,
      includeShortLines: true,
    );
    if (panel == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bir panel seçin')));
      return;
    }

    final width = panel['rightX']! - panel['leftX']!;
    final height = panel['topY']! - panel['bottomY']!;
    final pos = Offset(panel['leftX']!, panel['topY']!);
    final sz = Size(width, height);

    if (SlideArrowTool.sameDirectionExists(spec, pos, sz, direction)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            direction == 'right'
                ? 'Bu panelde sağa ok zaten var'
                : 'Bu panelde sola ok zaten var',
          ),
          duration: const Duration(milliseconds: 1200),
        ),
      );
      return;
    }

    final element = SlideArrowTool.createForPanel(panel, direction);
    controller.addInternalElement(element);
    ref.read(toolModeProvider.notifier).reset();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          direction == 'right'
              ? 'Sağa sürme oku eklendi'
              : 'Sola sürme oku eklendi',
        ),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }

  Widget _buildTopToolbar(ToolMode currentTool) {
    final toolNotifier = ref.read(toolModeProvider.notifier);
    final controllerState = ref.watch(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )),
    );

    final shape = controllerState.currentShape;

    final hasHorizontalLines =
        (shape?.internalElements.any(
              (e) => e.type == InternalElementType.horizontalLine,
            ) ??
            false) ||
        (shape?.sideAttachments.any(
              (a) => a.internalElements.any(
                (e) => e.type == InternalElementType.horizontalLine,
              ),
            ) ??
            false);

    final hasVerticalLines =
        (shape?.internalElements.any(
              (e) => e.type == InternalElementType.verticalLine,
            ) ??
            false) ||
        (shape?.sideAttachments.any(
              (a) => a.internalElements.any(
                (e) => e.type == InternalElementType.verticalLine,
              ),
            ) ??
            false);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: Container(
        padding: const EdgeInsets.all(4),
        color: const Color.fromARGB(255, 228, 228, 228),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGridCell(
                  icon: Icons.add_box_outlined,
                  onTap: _createNewShape,
                  tooltip: 'Yeni Çizim',
                ),
                _buildDividerV(),
                _buildGridCell(
                  icon: Icons.first_page,
                  onTap: hasVerticalLines
                      ? _openVerticalEditorWithPanelPicker
                      : null,
                  tooltip: 'Dikey panel konumlarını ayarlayın.',
                  isActive: false,
                ),
                _buildDividerV(),
                _buildGridCell(
                  icon: Icons.horizontal_rule,
                  rotationTurns: 1,
                  isActive: currentTool == ToolMode.verticalLine,
                  onTap: () {
                    if (currentTool == ToolMode.verticalLine) {
                      toolNotifier.setMode(ToolMode.selection);
                    } else {
                      toolNotifier.setMode(ToolMode.verticalLine);
                    }
                  },
                  tooltip: 'Dikey çizgi ekle. Ekranda sürükle bırak.',
                ),
                _buildDividerV(),
                _buildGridCell(
                  icon: Icons.more_vert,
                  isActive: currentTool == ToolMode.shortVerticalLine,
                  onTap: () {
                    if (currentTool == ToolMode.shortVerticalLine) {
                      toolNotifier.setMode(ToolMode.selection);
                    } else {
                      toolNotifier.setMode(ToolMode.shortVerticalLine);
                    }
                  },
                  tooltip: 'Kısa dikey çizgi ekle.Ekranda sürükle bırak.',
                ),
                _buildDividerV(),
                _buildTriangleCell(
                  direction: TriangleDirection.left,
                  isActive: currentTool == ToolMode.triangleLeft,
                  onTap: () {
                    if (currentTool == ToolMode.triangleLeft) {
                      toolNotifier.setMode(ToolMode.selection);
                    } else {
                      toolNotifier.setMode(ToolMode.triangleLeft);
                    }
                  },
                  tooltip: 'Sol açılır pencereler için üçgen ekle.',
                ),
                _buildDividerV(),
                _buildSidePanelCell(
                  isActive: currentTool == ToolMode.attachPanel,
                  onTap: () {
                    currentTool == ToolMode.attachPanel
                        ? toolNotifier.setMode(ToolMode.selection)
                        : toolNotifier.setMode(ToolMode.attachPanel);
                  },
                  tooltip: 'Ana şekle bitişik yan panel ekle.',
                ),
                _buildDividerV(),
                _buildGridCell(
                  icon: Icons.arrow_back,
                  isActive: currentTool == ToolMode.slideLeft,
                  onTap: () {
                    if (currentTool == ToolMode.slideLeft) {
                      toolNotifier.setMode(ToolMode.selection);
                    } else {
                      toolNotifier.setMode(ToolMode.slideLeft);
                    }
                  },
                  tooltip: 'Sürme Sistemi - Sola kayar kanat ekle.',
                ),
                _buildDotGridCell(
                  isActive: currentTool == ToolMode.dotGrid,
                  onTap: () {
                    if (currentTool == ToolMode.dotGrid) {
                      toolNotifier.setMode(ToolMode.selection);
                    } else {
                      toolNotifier.setMode(ToolMode.dotGrid);
                    }
                  },
                  tooltip: 'Desenli cam ekle.',
                ),
                _buildDividerV(),
                _buildGridCell(
                  icon: Icons.touch_app,
                  isActive: currentTool == ToolMode.selection,
                  onTap: () => toolNotifier.setMode(ToolMode.selection),
                  tooltip: 'Çizimleri seçin ve taşıyın.',
                ),
              ],
            ),
            _buildDividerH(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGridCell(
                  icon: Icons.edit_outlined,
                  onTap: !_hasAnyMaterial(controllerState.currentShape)
                      ? _editShape
                      : null,
                  tooltip: 'Çizimi düzenle.',
                ),
                _buildDividerV(),
                _buildGridCell(
                  icon: Icons.last_page,
                  rotationTurns: 1,
                  onTap: hasHorizontalLines
                      ? _openHorizontalEditorWithPanelPicker
                      : null,
                  tooltip: 'Yatay Panel konumlarını ayarlayın.',
                  isActive: false,
                ),
                _buildDividerV(),
                _buildGridCell(
                  icon: Icons.horizontal_rule,
                  isActive: currentTool == ToolMode.horizontalLine,
                  onTap: () {
                    if (currentTool == ToolMode.horizontalLine) {
                      toolNotifier.setMode(ToolMode.selection);
                    } else {
                      toolNotifier.setMode(ToolMode.horizontalLine);
                    }
                  },
                  tooltip: 'Yatay çizgi ekle. Ekranda sürükle bırak.',
                ),
                _buildDividerV(),
                _buildGridCell(
                  icon: Icons.more_horiz,
                  isActive: currentTool == ToolMode.shortHorizontalLine,
                  onTap: () {
                    if (currentTool == ToolMode.shortHorizontalLine) {
                      toolNotifier.setMode(ToolMode.selection);
                    } else {
                      toolNotifier.setMode(ToolMode.shortHorizontalLine);
                    }
                  },
                  tooltip: 'Kısa Yatay çizgi ekle. Ekranda sürükle bırak.',
                ),
                _buildDividerV(),
                _buildTriangleCell(
                  direction: TriangleDirection.right,
                  isActive: currentTool == ToolMode.triangleRight,
                  onTap: () {
                    if (currentTool == ToolMode.triangleRight) {
                      toolNotifier.setMode(ToolMode.selection);
                    } else {
                      toolNotifier.setMode(ToolMode.triangleRight);
                    }
                  },
                  tooltip: 'Sağa açılır pencereler için üçgen ekle.',
                ),
                _buildDividerV(),
                _buildTriangleCell(
                  direction: TriangleDirection.up,
                  isActive: currentTool == ToolMode.triangleUp,
                  onTap: () {
                    if (currentTool == ToolMode.triangleUp) {
                      toolNotifier.setMode(ToolMode.selection);
                    } else {
                      toolNotifier.setMode(ToolMode.triangleUp);
                    }
                  },
                  tooltip: 'Yukarı açılır pencereler için üçgen ekle.',
                ),
                _buildDividerV(),
                _buildGridCell(
                  icon: Icons.arrow_forward,
                  isActive: currentTool == ToolMode.slideRight,
                  onTap: () {
                    if (currentTool == ToolMode.slideRight) {
                      toolNotifier.setMode(ToolMode.selection);
                    } else {
                      toolNotifier.setMode(ToolMode.slideRight);
                    }
                  },
                  tooltip: 'Sürme sistemi - Sağa kayar kanat ekle.',
                ),
                _buildDividerV(),
                _buildGridCell(
                  icon: Icons.format_align_justify,
                  rotationTurns: 1,
                  isActive: currentTool == ToolMode.lineGrid,
                  onTap: () {
                    if (currentTool == ToolMode.lineGrid) {
                      toolNotifier.setMode(ToolMode.selection);
                    } else {
                      toolNotifier.setMode(ToolMode.lineGrid);
                    }
                  },
                  tooltip: 'Profil kaplı Camsız.',
                ),
                _buildDividerV(),
                _buildGridCell(
                  icon: Icons.delete_outline,
                  isActive: false,
                  onTap: _showDeleteElementsDialog,
                  tooltip: 'Ekrandaki şekilleri sil.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidePanelCell({
    required bool isActive,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    final borderColor = isActive
        ? const Color.fromARGB(255, 145, 198, 248)
        : Colors.grey.shade400;
    final bgColor = isActive
        ? const Color.fromARGB(255, 215, 240, 252)
        : Colors.white;
    final lineColor = isActive
        ? const Color.fromARGB(255, 39, 153, 247)
        : Colors.grey.shade600;

    return Container(
      width: 38,
      height: 38,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: isActive ? 2 : 1),
        borderRadius: BorderRadius.circular(4),
        color: bgColor,
      ),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ana dikdörtgen (büyük)
                Container(
                  width: 14,
                  height: 20,
                  decoration: BoxDecoration(
                    border: Border.all(color: lineColor, width: 1.5),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 2),
                // Yan panel (küçük)
                Container(
                  width: 7,
                  height: 14,
                  decoration: BoxDecoration(
                    border: Border.all(color: lineColor, width: 1.5),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openHorizontalPanelsManually() async {
    final controllerState = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )),
    );
    final controller = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )).notifier,
    );

    if (controllerState.currentShape == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Önce bir şekil oluşturun')));
      return;
    }

    final spec = controllerState.currentShape!;
    final horizontalLines =
        spec.internalElements
            .where(
              (e) =>
                  e.type == InternalElementType.horizontalLine &&
                  e.properties['isShort'] != true,
            )
            .toList()
          ..sort((a, b) => b.position.dy.compareTo(a.position.dy));

    List<double> gaps;
    int selectedIndex = 0;

    if (horizontalLines.isEmpty) {
      gaps = [spec.baseHeight];
      selectedIndex = 0;
    } else {
      gaps = GapCalculator.calculateGaps(spec, horizontalLines);
      selectedIndex = horizontalLines.length ~/ 2;
    }

    final shortHorizontalLines = spec.internalElements
        .where(
          (e) =>
              e.type == InternalElementType.horizontalLine &&
              e.properties['isShort'] == true,
        )
        .toList();

    final result = await showDialog<List<double>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SectionEditorDialog(
        axis: SectionAxis.horizontal,
        shapeSpec: spec,
        totalSize: spec.baseHeight,
        initialGaps: gaps,
        shortLines: shortHorizontalLines,
        selectedLineIndex: selectedIndex,
        onShortLineChanged: (id, newY) {
          controller.updateShortHorizontalLine(id, newY);
        },
      ),
    );

    if (result != null && mounted) {
      if (horizontalLines.isEmpty && result.length > 1) {
        GapCalculator.createHorizontalLinesFromGaps(controller, spec, result);
      } else if (horizontalLines.isNotEmpty) {
        GapCalculator.applyNewGaps(controller, horizontalLines, result);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yatay panel yapısı güncellendi'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _openVerticalPanelsManually() async {
    final controllerState = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )),
    );
    final controller = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )).notifier,
    );

    if (controllerState.currentShape == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Önce bir şekil oluşturun')));
      return;
    }

    final spec = controllerState.currentShape!;
    final verticalLines =
        spec.internalElements
            .where(
              (e) =>
                  e.type == InternalElementType.verticalLine &&
                  e.properties['isShort'] != true,
            )
            .toList()
          ..sort((a, b) => a.position.dx.compareTo(b.position.dx));

    List<double> gaps;
    int selectedIndex = 0;

    if (verticalLines.isEmpty) {
      gaps = [spec.baseWidth];
      selectedIndex = 0;
    } else {
      gaps = GapCalculator.calculateVerticalGaps(spec, verticalLines);
      selectedIndex = verticalLines.length ~/ 2;
    }

    final shortVerticalLines = spec.internalElements
        .where(
          (e) =>
              e.type == InternalElementType.verticalLine &&
              e.properties['isShort'] == true,
        )
        .toList();

    final result = await showDialog<List<double>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SectionEditorDialog(
        axis: SectionAxis.vertical,
        shapeSpec: spec,
        totalSize: spec.baseWidth,
        initialGaps: gaps,
        shortLines: shortVerticalLines,
        selectedLineIndex: selectedIndex,
        onShortLineChanged: (id, newX) {
          controller.updateShortVerticalLine(id, newX);
        },
      ),
    );

    if (result != null && mounted) {
      if (verticalLines.isEmpty && result.length > 1) {
        GapCalculator.createVerticalLinesFromGaps(controller, spec, result);
      } else if (verticalLines.isNotEmpty) {
        GapCalculator.applyNewVerticalGaps(controller, verticalLines, result);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dikey panel yapısı güncellendi'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Widget _buildDividerV() => Container(
    width: 1,
    height: 38,
    color: const Color.fromARGB(255, 167, 166, 166),
    margin: const EdgeInsets.symmetric(horizontal: 1),
  );

  // ─── Panel seçici: yatay bölüm editörü ──────────────────────────────────────
  void _openHorizontalEditorWithPanelPicker() async {
    final spec = ref
        .read(
          drawingControllerProvider((
            projectId: widget.projectId,
            drawingId: widget.drawingId,
          )),
        )
        .currentShape;
    if (spec == null) return;

    final sources = <_PanelSource>[];

    // Kısa çizgi dahil herhangi bir yatay çizgi varsa ana şekli ekle
    final hasAnyH = spec.internalElements.any(
      (e) => e.type == InternalElementType.horizontalLine,
    );
    if (hasAnyH) sources.add(_PanelSource.main());

    for (final attach in spec.sideAttachments) {
      final hasH = attach.internalElements.any(
        (e) => e.type == InternalElementType.horizontalLine,
      );
      if (hasH) sources.add(_PanelSource.side(attach.side));
    }

    if (sources.isEmpty) return;

    if (sources.length == 1) {
      _openHorizontalForSource(sources.first, spec);
      return;
    }

    final picked = await _showPanelPickerSheet(sources, SectionAxis.horizontal);
    if (picked == null || !mounted) return;
    _openHorizontalForSource(picked, spec);
  }

  void _openHorizontalForSource(_PanelSource source, ShapeSpec spec) {
    if (source.isMain) {
      _openHorizontalPanelsManually();
      return;
    }
    final attach = spec.sideAttachments.firstWhere(
      (a) => a.side == source.side,
    );
    final firstLine = attach.internalElements
        .cast<InternalElement?>()
        .firstWhere(
          (e) =>
              e!.type == InternalElementType.horizontalLine &&
              e.properties['isShort'] != true,
          orElse: () => null,
        );
    if (firstLine == null) {
      showSidePanelHorizontalEditor(source.side!, attach, null);
      return;
    }
    showSidePanelHorizontalEditor(source.side!, attach, firstLine);
  }

  // ─── Panel seçici: dikey bölüm editörü ──────────────────────────────────────
  void _openVerticalEditorWithPanelPicker() async {
    final spec = ref
        .read(
          drawingControllerProvider((
            projectId: widget.projectId,
            drawingId: widget.drawingId,
          )),
        )
        .currentShape;
    if (spec == null) return;

    final sources = <_PanelSource>[];

    // Kısa çizgi dahil herhangi bir dikey çizgi varsa ana şekli ekle
    final hasAnyV = spec.internalElements.any(
      (e) => e.type == InternalElementType.verticalLine,
    );
    if (hasAnyV) sources.add(_PanelSource.main());

    for (final attach in spec.sideAttachments) {
      final hasV = attach.internalElements.any(
        (e) => e.type == InternalElementType.verticalLine,
      );
      if (hasV) sources.add(_PanelSource.side(attach.side));
    }

    if (sources.isEmpty) return;

    if (sources.length == 1) {
      _openVerticalForSource(sources.first, spec);
      return;
    }

    final picked = await _showPanelPickerSheet(sources, SectionAxis.vertical);
    if (picked == null || !mounted) return;
    _openVerticalForSource(picked, spec);
  }

  void _openVerticalForSource(_PanelSource source, ShapeSpec spec) {
    if (source.isMain) {
      _openVerticalPanelsManually();
      return;
    }
    final attach = spec.sideAttachments.firstWhere(
      (a) => a.side == source.side,
    );
    final firstLine = attach.internalElements
        .cast<InternalElement?>()
        .firstWhere(
          (e) =>
              e!.type == InternalElementType.verticalLine &&
              e.properties['isShort'] != true,
          orElse: () => null,
        );
    if (firstLine == null) {
      showSidePanelVerticalEditor(source.side!, attach, null);
      return;
    }
    showSidePanelVerticalEditor(source.side!, attach, firstLine);
  }

  // ─── Panel seçim bottom sheet ────────────────────────────────────────────────
  Future<_PanelSource?> _showPanelPickerSheet(
    List<_PanelSource> sources,
    SectionAxis axis,
  ) {
    final axisLabel = axis == SectionAxis.horizontal ? 'Yatay' : 'Dikey';

    return showModalBottomSheet<_PanelSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '$axisLabel Bölümler — Hangi panel?',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Düzenlemek istediğin panele dokun.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Row(
              children: sources.map((src) {
                final isLeft = src.side == 'left';
                final label = src.isMain
                    ? 'Ana Şekil'
                    : isLeft
                    ? 'Sol Panel'
                    : 'Sağ Panel';
                final icon = src.isMain
                    ? Icons.crop_portrait
                    : isLeft
                    ? Icons.first_page
                    : Icons.last_page;
                final color = src.isMain
                    ? Colors.blue.shade700
                    : isLeft
                    ? Colors.teal.shade700
                    : Colors.orange.shade700;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () => Navigator.pop(context, src),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: color.withOpacity(0.4),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: color.withOpacity(0.06),
                        ),
                        child: Column(
                          children: [
                            Icon(icon, color: color, size: 28),
                            const SizedBox(height: 8),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDividerH() => Container(
    height: 1,
    color: const Color.fromARGB(255, 182, 180, 180),
    margin: const EdgeInsets.symmetric(vertical: 1),
  );

  Widget _buildGridCell({
    required IconData icon,
    required VoidCallback? onTap,
    required String tooltip,
    bool isActive = false,
    bool isDestructive = false,
    int rotationTurns = 0,
  }) {
    final borderColor = isDestructive
        ? const Color.fromARGB(255, 243, 1, 1)
        : (isActive
              ? const Color.fromARGB(255, 145, 198, 248)
              : Colors.grey.shade400);

    final bgColor = isActive
        ? const Color.fromARGB(255, 215, 240, 252)
        : Colors.white;
    final iconColor = isDestructive
        ? Colors.red
        : (isActive
              ? const Color.fromARGB(255, 39, 153, 247)
              : Colors.grey.shade600);

    Widget iconWidget = Icon(
      icon,
      size: 28,
      color: onTap != null ? iconColor : Colors.grey.shade400,
    );
    if (rotationTurns > 0) {
      iconWidget = RotatedBox(quarterTurns: rotationTurns, child: iconWidget);
    }

    return Container(
      width: 38,
      height: 38,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(
          color: onTap != null ? borderColor : Colors.grey.shade300,
          width: isActive ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(4),
        color: onTap != null ? bgColor : Colors.grey.shade100,
      ),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Center(child: iconWidget),
        ),
      ),
    );
  }

  Widget _buildTriangleCell({
    required TriangleDirection direction,
    required bool isActive,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    final borderColor = isActive
        ? const Color.fromARGB(255, 145, 198, 248)
        : Colors.grey.shade400;
    final bgColor = isActive
        ? const Color.fromARGB(255, 215, 240, 252)
        : Colors.white;
    final lineColor = isActive
        ? const Color.fromARGB(255, 39, 153, 247)
        : Colors.grey.shade600;

    return Container(
      width: 38,
      height: 38,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: isActive ? 2 : 1),
        borderRadius: BorderRadius.circular(4),
        color: bgColor,
      ),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Center(
            child: CustomPaint(
              size: const Size(16, 16),
              painter: TriangleOutlinePainter(
                color: lineColor,
                direction: direction,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDotGridCell({
    required bool isActive,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    final borderColor = isActive
        ? const Color.fromARGB(255, 145, 198, 248)
        : Colors.grey.shade400;
    final bgColor = isActive
        ? const Color.fromARGB(255, 215, 240, 252)
        : Colors.white;
    final dotColor = isActive
        ? const Color.fromARGB(255, 39, 153, 247)
        : Colors.grey.shade600;

    final rows = <Widget>[];
    for (int i = 0; i < 4; i++) {
      final cols = <Widget>[];
      for (int j = 0; j < 4; j++) {
        cols.add(
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
          ),
        );
        if (j < 3) cols.add(const SizedBox(width: 2));
      }
      rows.add(Row(mainAxisSize: MainAxisSize.min, children: cols));
      if (i < 3) rows.add(const SizedBox(height: 2));
    }

    return Container(
      width: 38,
      height: 38,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: isActive ? 2 : 1),
        borderRadius: BorderRadius.circular(4),
        color: bgColor,
      ),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: rows),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomShapePanel(
    DrawingController controller,
    List<ShapeSpec> shapes,
    double navBarHeight,
  ) {
    if (shapes.length <= 1) {
      return Container();
    }
    const double handleWidth = 120;
    const double handleHeight = 36;
    const double openHeight = 70;

    final double handleBottom = _isSystemPanelOpen
        ? _systemPanelHeight
        : (_isShapeListPanelOpen ? openHeight : 0);

    return Visibility(
      visible: !_isNewBottomPanelOpen,
      child: Stack(
        children: [
          if (_isShapeListPanelOpen)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom,
              child: Container(
                height: openHeight,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 236, 236, 236),
                  border: Border(
                    top: BorderSide(
                      color: const Color.fromARGB(255, 172, 171, 171),
                    ),
                  ),
                ),
                child: shapes.isEmpty
                    ? const Center(
                        child: Text(
                          'Henüz çizim yok',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        itemCount: shapes.length,
                        itemBuilder: (context, index) {
                          final isSelected =
                              index == controller.controllerState.selectedIndex;

                          return GestureDetector(
                            onTap: () => _selectShape(index),
                            child: Container(
                              width: 74,
                              height: 54,
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color.fromARGB(255, 155, 219, 248)
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color.fromARGB(255, 184, 222, 236)
                                      : Colors.grey.shade400,
                                  width: 1.5,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  CustomPaint(
                                    size: const Size(50, 50),
                                    painter: ShapePainter(
                                      shapes[index].copyWith(
                                        showDimensions: false,
                                        internalElements: [],
                                      ),
                                      sideAttachments: shapes[index]
                                          .sideAttachments
                                          .map(
                                            (a) => a.copyWith(
                                              internalElements: [],
                                            ),
                                          )
                                          .toList(),

                                      overrideStrokeColor: isSelected
                                          ? const Color.fromARGB(255, 0, 0, 0)
                                          : Colors.black87,
                                      overrideStrokeWidth: isSelected ? 2 : 1.2,
                                    ),
                                  ),
                                  Positioned(
                                    right: 1,
                                    bottom: 0,
                                    child: Text(
                                      'P${index + 1}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? const Color.fromARGB(
                                                255,
                                                5,
                                                90,
                                                201,
                                              )
                                            : Colors.grey.shade500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          Positioned(
            left: 8,
            bottom: handleBottom + navBarHeight,
            child: GestureDetector(
              onTap: () => setState(() {
                _isShapeListPanelOpen = !_isShapeListPanelOpen;
                if (_isShapeListPanelOpen) _isSystemPanelOpen = false;
              }),
              child: Container(
                width: handleWidth,
                height: handleHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isSystemPanelOpen
                        ? [Colors.grey.shade400, Colors.grey.shade300]
                        : [
                            const Color.fromARGB(255, 5, 90, 201),
                            const Color.fromARGB(255, 142, 182, 241),
                          ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                    bottom: Radius.circular(0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Çizim (${shapes.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isShapeListPanelOpen
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_up,
                      color: const Color.fromARGB(255, 255, 255, 255),
                      size: 26,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Yardımcı: panel seçimi ───────────────────────────────────────────────────
class _PanelSource {
  final bool isMain;
  final String? side;

  const _PanelSource._({required this.isMain, this.side});

  factory _PanelSource.main() => const _PanelSource._(isMain: true);
  factory _PanelSource.side(String side) =>
      _PanelSource._(isMain: false, side: side);
}

class TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class TriangleOutlinePainter extends CustomPainter {
  final Color color;
  final TriangleDirection direction;
  final bool dashed;

  TriangleOutlinePainter({
    required this.color,
    required this.direction,
    this.dashed = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = _getTrianglePath(size);

    if (dashed) {
      _drawDashedPath(canvas, path, paint, dashLength: 3, gapLength: 2);
    } else {
      canvas.drawPath(path, paint);
    }
  }

  Path _getTrianglePath(Size size) {
    final path = Path();
    final padding = 2.0;

    switch (direction) {
      case TriangleDirection.up:
        path.moveTo(size.width / 2, padding);
        path.lineTo(size.width - padding, size.height - padding);
        path.lineTo(padding, size.height - padding);
        path.close();
        break;
      case TriangleDirection.down:
        break;
      case TriangleDirection.left:
        path.moveTo(size.width - padding, padding);
        path.lineTo(size.width - padding, size.height - padding);
        path.lineTo(padding, size.height / 2);
        path.close();
        break;
      case TriangleDirection.right:
        path.moveTo(padding, padding);
        path.lineTo(padding, size.height - padding);
        path.lineTo(size.width - padding, size.height / 2);
        path.close();
        break;
    }
    return path;
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dashLength,
    required double gapLength,
  }) {
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final start = distance;
        final end = (distance + dashLength).clamp(0.0, metric.length);

        final dashPath = metric.extractPath(start, end);
        canvas.drawPath(dashPath, paint);

        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
