// lib/presentation/pages/drawing_canvas_page.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/dialogs/measure_dialog.dart';
import '../../models/shape_spec.dart';
import '../../models/drawing.dart';
import 'painters/quadrilateral_painter.dart';
import '../../presentation/providers/drawing_provider.dart';
import '../../shared/dialogs/corner_edit_dialog.dart';

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

class _DrawingCanvasPageState extends ConsumerState<DrawingCanvasPage> {
  // 🎯 TEK ŞEKİL odaklı state
  List<ShapeSpec> _shapes = [];
  int _selectedShapeIndex = 0;
  ShapeSpec? get _currentShape =>
      _shapes.isNotEmpty ? _shapes[_selectedShapeIndex] : null;
  int? _draggedVertexIndex;
  bool _isDraggingVertex = false;

  //silmek gerekebilir
  bool _isLoading = false;
  bool _showVertices =
      true; // Vertex'ler her zaman görünür (opsiyonel kapatabilir)

  Drawing? _drawingData;
  final TransformationController _transformationController =
      TransformationController();
  double _currentScale = 1.0;
  Timer? _autoSaveTimer;

  bool _isLeftPanelOpen = false;
  bool _isRightPanelOpen = false;
  int _selectedLeftCorner = 0; // 0: Sol Üst, 1: Sol Alt
  int _selectedRightCorner = 0; // 0: Sağ Üst, 1: Sağ Alt

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_updateScale);
    _loadDrawing();

    _autoSaveTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_currentShape != null) _saveDrawing();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.customerName} - Pencere Çizimi'),
        backgroundColor: Colors.blue[700],
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          if (_currentScale != 1.0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text(
                  '%${(_currentScale * 100).toInt()}',
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: Colors.orange[100],
                visualDensity: VisualDensity.compact,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.zoom_out_map, size: 20),
            onPressed: _resetZoom,
            tooltip: 'Sıfırla',
          ),
          IconButton(
            icon: Icon(
              _showVertices ? Icons.visibility : Icons.visibility_off,
              size: 20,
            ),
            onPressed: () => setState(() => _showVertices = !_showVertices),
            tooltip: 'Köşeleri Göster/Gizle',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (value) {
              if (value == 'save')
                _saveDrawing();
              else if (value == 'new')
                _createNewShape();
              else if (value == 'edit')
                _editShape();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18),
                    SizedBox(width: 8),
                    Text('Ölçüleri Düzenle'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'new',
                child: Row(
                  children: [
                    Icon(Icons.add, size: 18, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Yeni Şekil', style: TextStyle(color: Colors.blue)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'save',
                child: Row(
                  children: [
                    Icon(Icons.save, size: 18),
                    SizedBox(width: 8),
                    Text('Kaydet'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      body: Stack(
        children: [
          // Ana içerik (Canvas + Alt çubuk)
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                color: Colors.grey[100],
                child: Row(
                  children: [
                    _buildIconButton(
                      icon: Icons.add_box_outlined,
                      tooltip: 'Yeni Şekil',
                      onPressed: _createNewShape,
                      color: Colors.blue,
                    ),
                    _buildIconButton(
                      icon: Icons.edit_outlined,
                      tooltip: 'Ölçüleri Düzenle (Dialog)',
                      onPressed: _currentShape != null ? _editShape : null,
                      color: Colors.orange,
                    ),
                    const Spacer(),
                    if (_currentShape != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          '${_currentShape!.baseWidth.toInt()} × ${_currentShape!.baseHeight.toInt()} mm',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              Expanded(child: _buildSingleShapeCanvas()),

              if (_currentShape != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildCropInfo(
                          'X₁→',
                          _currentShape!.topLeftX,
                          Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        _buildCropInfo(
                          'Y₁↓',
                          _currentShape!.topLeftY,
                          Colors.red,
                        ),
                        const SizedBox(width: 8),
                        _buildCropInfo(
                          'X₂←',
                          _currentShape!.topRightX,
                          Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        _buildCropInfo(
                          'Y₂↓',
                          _currentShape!.topRightY,
                          Colors.red,
                        ),
                        const SizedBox(width: 8),
                        _buildCropInfo(
                          'X₃←',
                          _currentShape!.bottomRightX,
                          Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        _buildCropInfo(
                          'Y₃↑',
                          _currentShape!.bottomRightY,
                          Colors.red,
                        ),
                        const SizedBox(width: 8),
                        _buildCropInfo(
                          'X₄→',
                          _currentShape!.bottomLeftX,
                          Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        _buildCropInfo(
                          'Y₄↑',
                          _currentShape!.bottomLeftY,
                          Colors.red,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // Sol ve Sağ Paneller
          _buildLeftSidePanel(),
          _buildRightSidePanel(),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Icon(
                icon,
                size: 24,
                color: onPressed == null ? Colors.grey.shade400 : color,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCropInfo(String label, double value, Color color) {
    final hasValue = value > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: hasValue ? color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${value.toInt()} mm',
            style: TextStyle(
              fontSize: 10,
              fontWeight: hasValue ? FontWeight.bold : FontWeight.normal,
              color: hasValue ? color : Colors.grey.shade400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleShapeCanvas() {
    if (_currentShape == null) {
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
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _createNewShape,
              icon: const Icon(Icons.add),
              label: const Text('Yeni Şekil Oluştur'),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
        final scale = _calculateScale(canvasSize, _currentShape!.boundingSize);
        final offset = _calculateOffset(
          canvasSize,
          _currentShape!.boundingSize,
          scale,
        );

        return InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.5,
          maxScale: 3.0,
          boundaryMargin: const EdgeInsets.all(50),
          child: Container(
            width: canvasSize.width,
            height: canvasSize.height,
            color: Colors.white,
            child: CustomPaint(
              size: canvasSize,
              painter: ShapePainter(_currentShape!),
            ),
          ),
        );
      },
    );
  }

  // Dialog'u göster
  void _showCornerEditDialog(int cornerIndex) async {
    if (_currentShape == null) return;

    final result = await showDialog<ShapeSpec>(
      context: context,
      builder: (context) =>
          CornerEditDialog(shape: _currentShape!, cornerIndex: cornerIndex),
    );

    if (result != null) {
      setState(() {
        _shapes[_selectedShapeIndex] = result;
      });
      _saveDrawing();
    }
  }

  void _handleVertexDrag(int index, DragUpdateDetails details, double scale) {
    if (_currentShape == null) return;

    final deltaX = details.delta.dx / scale;
    final deltaY = details.delta.dy / scale;

    setState(() {
      final current = _currentShape!;
      ShapeSpec updated;

      switch (index) {
        // === SOL ÜST KÖŞE ===
        case 0: // X₁: Üst kenar (sağa/sola) → X₂'ye kadar
          updated = current.copyWith(
            topLeftX: (current.topLeftX + deltaX).clamp(
              0.0,
              current.baseWidth - current.topRightX - 1, // X₂'ye değene kadar
            ),
          );
          break;

        case 1: // Y₁: Sol kenar (yukarı/aşağı) → Y₄'e kadar
          updated = current.copyWith(
            topLeftY: (current.topLeftY + deltaY).clamp(
              0.0,
              current.baseHeight - current.bottomLeftY - 1, // Y₄'e değene kadar
            ),
          );
          break;

        // === SAĞ ÜST KÖŞE ===
        case 2: // X₂: Üst kenar (sola/sağa) → X₁'e kadar
          updated = current.copyWith(
            topRightX: (current.topRightX - deltaX).clamp(
              0.0,
              current.baseWidth - current.topLeftX - 1,
            ),
          );
          break;

        case 3: // Y₂: Sağ kenar (yukarı/aşağı) → Y₃'e kadar
          updated = current.copyWith(
            topRightY: (current.topRightY + deltaY).clamp(
              0.0,
              current.baseHeight - current.bottomRightY - 1,
            ),
          );
          break;

        // === SAĞ ALT KÖŞE ===
        case 4: // Y₃: Sağ kenar (aşağı/yukarı) → Y₂'ye kadar
          updated = current.copyWith(
            bottomRightY: (current.bottomRightY - deltaY).clamp(
              0.0,
              current.baseHeight - current.topRightY - 1,
            ),
          );
          break;

        case 5: // X₃: Alt kenar (sağa/sola) → X₄'e kadar
          updated = current.copyWith(
            bottomRightX: (current.bottomRightX - deltaX).clamp(
              0.0,
              current.baseWidth - current.bottomLeftX - 1,
            ),
          );
          break;

        // === SOL ALT KÖŞE ===
        case 6: // X₄: Alt kenar (sağa/sola) → X₃'e kadar
          updated = current.copyWith(
            bottomLeftX: (current.bottomLeftX + deltaX).clamp(
              0.0,
              current.baseWidth - current.bottomRightX - 1,
            ),
          );
          break;

        case 7: // Y₄: Sol kenar (aşağı/yukarı) → Y₁'e kadar
          updated = current.copyWith(
            bottomLeftY: (current.bottomLeftY - deltaY).clamp(
              0.0,
              current.baseHeight - current.topLeftY - 1,
            ),
          );
          break;

        default:
          return;
      }

      _shapes[_selectedShapeIndex] = updated;
    });
  }

  // Hesaplamalar
  double _calculateScale(Size canvasSize, Size shapeSize) {
    const padding = 0.7;
    final scaleX = (canvasSize.width * padding) / shapeSize.width;
    final scaleY = (canvasSize.height * padding) / shapeSize.height;
    return math.min(scaleX, scaleY);
  }

  Offset _calculateOffset(Size canvasSize, Size shapeSize, double scale) {
    final scaledW = shapeSize.width * scale;
    final scaledH = shapeSize.height * scale;
    return Offset(
      (canvasSize.width - scaledW) / 2,
      (canvasSize.height - scaledH) / 2,
    );
  }

  // İşlemler
  void _createNewShape() async {
    final result = await showDialog<ShapeSpec>(
      context: context,
      builder: (context) => MeasureDialog(
        initial: ShapeSpec.rectangle(width: 1000, height: 1000),
        title: "Yeni Pencere Şekli",
      ),
    );

    if (result != null) {
      setState(() {
        _shapes.add(result); // Listeye ekle
        _selectedShapeIndex = _shapes.length - 1; // Yeni şekili seç
      });
      _saveDrawing();
    }
  }

  void _editShape() async {
    if (_currentShape == null) return;

    final result = await showDialog<ShapeSpec>(
      context: context,
      builder: (context) =>
          MeasureDialog(initial: _currentShape!, title: "Ölçüleri Düzenle"),
    );

    if (result != null) {
      setState(() {
        _shapes[_selectedShapeIndex] = result; // Listedeki şekli güncelle
      });
      _saveDrawing();
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

  // Veri işlemleri
  Future<void> _loadDrawing() async {
    setState(() => _isLoading = true);
    try {
      final drawings = ref.read(drawingProvider(widget.projectId));
      final drawing = drawings.firstWhere(
        (d) => d.id == widget.drawingId,
        orElse: () => Drawing(
          id: widget.drawingId,
          projectId: widget.projectId,
          name: 'Yeni Çizim',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      _drawingData = drawing;

      // YENİ: Shapes listesini yükle
      if (drawing.shapes.isNotEmpty) {
        _shapes = drawing.shapes;
        _selectedShapeIndex = 0;
      } else {
        // Varsayılan şekil oluştur
        _shapes = [ShapeSpec.rectangle(width: 1000, height: 1000)];
        _selectedShapeIndex = 0;
      }
    } catch (e) {
      _shapes = [ShapeSpec.rectangle(width: 1000, height: 1000)];
      _selectedShapeIndex = 0;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveDrawing() async {
    if (_drawingData == null || _shapes.isEmpty) return;
    try {
      final updated = _drawingData!.copyWithShapes(_shapes);
      await ref
          .read(drawingProvider(widget.projectId).notifier)
          .updateDrawing(updated);
      _drawingData = updated;
    } catch (e) {
      debugPrint('Save error: $e');
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _autoSaveTimer?.cancel();
    super.dispose();
  }

  // Sol Panel (Sol Üst + Sol Alt)
  Widget _buildLeftSidePanel() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      left: _isLeftPanelOpen ? 0 : -200,
      top: 100,
      bottom: 100,
      child: Row(
        children: [
          // Ana Panel İçeriği
          Container(
            width: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                // 🎯 Yeni Başlık: Sol Edit ikonu + Kapatma butonu
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Sol Edit ikon ve yazı
                      Row(
                        children: [
                          const Icon(Icons.edit, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Sol',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      // Geri/Kapat butonu
                      GestureDetector(
                        onTap: () => setState(() => _isLeftPanelOpen = false),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                _buildCornerButton(
                  label: 'Sol Üst',
                  xValue: _currentShape?.topLeftX ?? 0,
                  yValue: _currentShape?.topLeftY ?? 0,
                  isSelected: _selectedLeftCorner == 0,
                  isLeftSide: true,
                  onTap: () {
                    setState(() => _selectedLeftCorner = 0);
                    _showCornerValueDialog(0);
                  },
                ),

                const Divider(height: 1),

                _buildCornerButton(
                  label: 'Sol Alt',
                  xValue: _currentShape?.bottomLeftX ?? 0,
                  yValue: _currentShape?.bottomLeftY ?? 0,
                  isSelected: _selectedLeftCorner == 1,
                  isLeftSide: true,
                  onTap: () {
                    setState(() => _selectedLeftCorner = 1);
                    _showCornerValueDialog(3);
                  },
                ),

                const Spacer(),
              ],
            ),
          ),

          // 🎯 Post-it sapı - SADECE KAPALIYKEN GÖSTER
          if (!_isLeftPanelOpen)
            GestureDetector(
              onTap: () => setState(() {
                _isLeftPanelOpen = true;
                _isRightPanelOpen = false;
              }),
              child: Container(
                width: 40,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 5,
                      offset: const Offset(2, 0),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.edit, color: Colors.white, size: 20),
                    const SizedBox(height: 4),
                    RotatedBox(
                      quarterTurns: 1,
                      child: Text(
                        'SOL',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Sağ Panel (Sağ Üst + Sağ Alt)
  Widget _buildRightSidePanel() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      right: _isRightPanelOpen ? 0 : -200,
      top: 100,
      bottom: 100,
      child: Row(
        children: [
          // 🎯 Post-it sapı - SADECE KAPALIYKEN GÖSTER
          if (!_isRightPanelOpen)
            GestureDetector(
              onTap: () => setState(() {
                _isRightPanelOpen = true;
                _isLeftPanelOpen = false;
              }),
              child: Container(
                width: 40,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.orange.shade700,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 5,
                      offset: const Offset(-2, 0),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.edit, color: Colors.white, size: 20),
                    const SizedBox(height: 4),
                    RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        'SAĞ',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Ana Panel İçeriği
          Container(
            width: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                // 🎯 Yeni Başlık: Sağ Edit ikonu + Kapatma butonu
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Geri/Kapat butonu (solda)
                      GestureDetector(
                        onTap: () => setState(() => _isRightPanelOpen = false),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      // Sağ Edit ikon ve yazı
                      Row(
                        children: [
                          const Text(
                            'Sağ',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.edit, color: Colors.white, size: 20),
                        ],
                      ),
                    ],
                  ),
                ),

                _buildCornerButton(
                  label: 'Sağ Üst',
                  xValue: _currentShape?.topRightX ?? 0,
                  yValue: _currentShape?.topRightY ?? 0,
                  isSelected: _selectedRightCorner == 0,
                  isLeftSide: false,
                  onTap: () {
                    setState(() => _selectedRightCorner = 0);
                    _showCornerValueDialog(1);
                  },
                ),

                const Divider(height: 1),

                _buildCornerButton(
                  label: 'Sağ Alt',
                  xValue: _currentShape?.bottomRightX ?? 0,
                  yValue: _currentShape?.bottomRightY ?? 0,
                  isSelected: _selectedRightCorner == 1,
                  isLeftSide: false,
                  onTap: () {
                    setState(() => _selectedRightCorner = 1);
                    _showCornerValueDialog(2);
                  },
                ),

                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Köşe Butonu
  Widget _buildCornerButton({
    required String label,
    required double xValue,
    required double yValue,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isLeftSide, // Yeni parametre
  }) {
    // Sol taraf için L, Sağ taraf için R
    final prefix = isLeftSide ? 'L' : 'R';

    // Y yönünü belirle (Üst köşeler aşağı, Alt köşeler yukarı)
    final isBottomCorner = label.contains('Alt');

    return Material(
      color: isSelected ? Colors.blue.shade50 : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // LX veya RX (Yatay - Mavi)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${prefix}X',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          isLeftSide ? Icons.arrow_forward : Icons.arrow_back,
                          size: 14,
                          color: Colors.blue.shade800,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // LY veya RY (Dikey - Kırmızı)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${prefix}Y',
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          isBottomCorner
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 14,
                          color: Colors.red.shade800,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Değer Giriş Dialogu
  void _showCornerValueDialog(int cornerIndex) async {
    if (_currentShape == null) return;

    final xCtrl = TextEditingController();
    final yCtrl = TextEditingController();

    double currentX, currentY;
    String title;
    List<String> labels;

    switch (cornerIndex) {
      case 0:
        currentX = _currentShape!.topLeftX;
        currentY = _currentShape!.topLeftY;
        title = 'Sol Üst Köşe';
        labels = ['X₁ →', 'Y₁ ↓'];
        break;
      case 1:
        currentX = _currentShape!.topRightX;
        currentY = _currentShape!.topRightY;
        title = 'Sağ Üst Köşe';
        labels = ['X₂ ←', 'Y₂ ↓'];
        break;
      case 2:
        currentX = _currentShape!.bottomRightX;
        currentY = _currentShape!.bottomRightY;
        title = 'Sağ Alt Köşe';
        labels = ['X₃ ←', 'Y₃ ↑'];
        break;
      case 3:
        currentX = _currentShape!.bottomLeftX;
        currentY = _currentShape!.bottomLeftY;
        title = 'Sol Alt Köşe';
        labels = ['X₄ →', 'Y₄ ↑'];
        break;
      default:
        return;
    }

    xCtrl.text = currentX.toInt().toString();
    yCtrl.text = currentY.toInt().toString();

    final result = await showDialog<ShapeSpec>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      labels[0],
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: xCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Yatay (mm)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      labels[1],
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: yCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Dikey (mm)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              final newX = double.tryParse(xCtrl.text) ?? currentX;
              final newY = double.tryParse(yCtrl.text) ?? currentY;

              ShapeSpec updated;
              switch (cornerIndex) {
                case 0:
                  updated = _currentShape!.copyWith(
                    topLeftX: newX,
                    topLeftY: newY,
                  );
                  break;
                case 1:
                  updated = _currentShape!.copyWith(
                    topRightX: newX,
                    topRightY: newY,
                  );
                  break;
                case 2:
                  updated = _currentShape!.copyWith(
                    bottomRightX: newX,
                    bottomRightY: newY,
                  );
                  break;
                case 3:
                  updated = _currentShape!.copyWith(
                    bottomLeftX: newX,
                    bottomLeftY: newY,
                  );
                  break;
                default:
                  updated = _currentShape!;
              }
              Navigator.pop(context, updated);
            },
            child: const Text('Uygula'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _shapes[_selectedShapeIndex] = result;
      });
      _saveDrawing();
    }
  }
}
