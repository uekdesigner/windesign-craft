import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/shape_spec.dart';
import '../providers/drawing_controller_provider.dart';

class CornerSidePanels extends ConsumerStatefulWidget {
  final String projectId;
  final String drawingId;
  final ShapeSpec? currentShape;
  final bool showSideHandles;

  const CornerSidePanels({
    super.key,
    required this.projectId,
    required this.drawingId,
    required this.currentShape,
    required this.showSideHandles,
  });

  @override
  ConsumerState<CornerSidePanels> createState() => _CornerSidePanelsState();
}

class _CornerSidePanelsState extends ConsumerState<CornerSidePanels> {
  bool _isLeftPanelOpen = false;
  bool _isRightPanelOpen = false;

  TextEditingController? _activeController;

  String _activeFieldLabel = '';

  final TextEditingController _solUstX = TextEditingController();
  final TextEditingController _solUstY = TextEditingController();
  final TextEditingController _solAltX = TextEditingController();
  final TextEditingController _solAltY = TextEditingController();
  final TextEditingController _sagUstX = TextEditingController();
  final TextEditingController _sagUstY = TextEditingController();
  final TextEditingController _sagAltX = TextEditingController();
  final TextEditingController _sagAltY = TextEditingController();

  @override
  void didUpdateWidget(covariant CornerSidePanels oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentShape != oldWidget.currentShape) {
      _updateControllers(widget.currentShape);
    }
  }

  @override
  void initState() {
    super.initState();
    _updateControllers(widget.currentShape);
  }

  @override
  void dispose() {
    _solUstX.dispose();
    _solUstY.dispose();
    _solAltX.dispose();
    _solAltY.dispose();
    _sagUstX.dispose();
    _sagUstY.dispose();
    _sagAltX.dispose();
    _sagAltY.dispose();
    super.dispose();
  }

  void _updateControllers(ShapeSpec? currentShape) {
    if (currentShape == null) return;

    final topEdge =
        (currentShape.baseWidth -
                currentShape.topLeftX -
                currentShape.topRightX)
            .toInt();
    _solUstX.text = '$topEdge';
    _sagUstX.text = '$topEdge';

    final bottomEdge =
        (currentShape.baseWidth -
                currentShape.bottomLeftX -
                currentShape.bottomRightX)
            .toInt();
    _solAltX.text = '$bottomEdge';
    _sagAltX.text = '$bottomEdge';

    final leftEdge =
        (currentShape.baseHeight -
                currentShape.topLeftY -
                currentShape.bottomLeftY)
            .toInt();
    _solUstY.text = '$leftEdge';
    _solAltY.text = '$leftEdge';

    final rightEdge =
        (currentShape.baseHeight -
                currentShape.topRightY -
                currentShape.bottomRightY)
            .toInt();
    _sagUstY.text = '$rightEdge';
    _sagAltY.text = '$rightEdge';
  }

  void _updateShapeFromControllers() {
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
    if (_activeController == null) return;

    final spec = controllerState.currentShape!;
    ShapeSpec? updated;

    if (_activeController == _solUstX) {
      final val = double.tryParse(_solUstX.text) ?? 0;
      final newTopLeftX = (spec.baseWidth - val - spec.topRightX).clamp(
        0.0,
        spec.baseWidth,
      );
      updated = spec.copyWith(topLeftX: newTopLeftX);
    } else if (_activeController == _solAltX) {
      final val = double.tryParse(_solAltX.text) ?? 0;
      final newBottomLeftX = (spec.baseWidth - val - spec.bottomRightX).clamp(
        0.0,
        spec.baseWidth,
      );
      updated = spec.copyWith(bottomLeftX: newBottomLeftX);
    } else if (_activeController == _solUstY) {
      final val = double.tryParse(_solUstY.text) ?? 0;
      final newTopLeftY = (spec.baseHeight - val - spec.bottomLeftY).clamp(
        0.0,
        spec.baseHeight,
      );
      updated = spec.copyWith(topLeftY: newTopLeftY);
    } else if (_activeController == _solAltY) {
      final val = double.tryParse(_solAltY.text) ?? 0;
      final newBottomLeftY = (spec.baseHeight - val - spec.topLeftY).clamp(
        0.0,
        spec.baseHeight,
      );
      updated = spec.copyWith(bottomLeftY: newBottomLeftY);
    } else if (_activeController == _sagUstX) {
      final val = double.tryParse(_sagUstX.text) ?? 0;
      final newTopRightX = (spec.baseWidth - val - spec.topLeftX).clamp(
        0.0,
        spec.baseWidth,
      );
      updated = spec.copyWith(topRightX: newTopRightX);
    } else if (_activeController == _sagAltX) {
      final val = double.tryParse(_sagAltX.text) ?? 0;
      final newBottomRightX = (spec.baseWidth - val - spec.bottomLeftX).clamp(
        0.0,
        spec.baseWidth,
      );
      updated = spec.copyWith(bottomRightX: newBottomRightX);
    } else if (_activeController == _sagUstY) {
      final val = double.tryParse(_sagUstY.text) ?? 0;
      final newTopRightY = (spec.baseHeight - val - spec.bottomRightY).clamp(
        0.0,
        spec.baseHeight,
      );
      updated = spec.copyWith(topRightY: newTopRightY);
    } else if (_activeController == _sagAltY) {
      final val = double.tryParse(_sagAltY.text) ?? 0;
      final newBottomRightY = (spec.baseHeight - val - spec.topRightY).clamp(
        0.0,
        spec.baseHeight,
      );
      updated = spec.copyWith(bottomRightY: newBottomRightY);
    }

    if (updated != null) {
      controller.updateShape(controllerState.selectedIndex, updated);
    }
  }

  void _onKeyPressed(String key) {
    if (_activeController == null) return;

    if (key == '⌫') {
      final text = _activeController!.text;
      if (text.isNotEmpty) {
        _activeController!.text = text.substring(0, text.length - 1);
      }
    } else {
      final selection = _activeController!.selection;

      if (selection.isValid && selection.start != selection.end) {
        _activeController!.text = key;
      } else {
        final currentText = _activeController!.text;
        if (currentText.length < 4) {
          _activeController!.text = currentText + key;
        }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_activeController != null) {
          _activeController!.selection = TextSelection.collapsed(
            offset: _activeController!.text.length,
          );
        }
      });
    }
    _updateShapeFromControllers();
  }

  @override
  Widget build(BuildContext context) {
    final hasPanelMaterial =
        (widget.currentShape?.internalElements.isNotEmpty ?? false) ||
        (widget.currentShape?.sideAttachments.isNotEmpty ?? false);
    if (hasPanelMaterial) return Container();

    if (_isLeftPanelOpen) _updateControllers(widget.currentShape);
    if (_isRightPanelOpen) _updateControllers(widget.currentShape);

    return Stack(children: [_buildLeftPanel(), _buildRightPanel()]);
  }

  Widget _buildLeftPanel() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      left: _isLeftPanelOpen ? 0 : (widget.showSideHandles ? -200 : -240),
      top: 97,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                        const Row(
                          children: [
                            Icon(Icons.edit, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Sol',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => setState(() {
                            _isLeftPanelOpen = false;
                            _activeController = null;
                          }),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
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
                  _buildCornerEditor(
                    'Sol Üst',
                    _solUstX,
                    _solUstY,
                    'LX→',
                    'LY↓',
                    Colors.blue,
                  ),
                  const Divider(height: 1),
                  _buildCornerEditor(
                    'Sol Alt',
                    _solAltX,
                    _solAltY,
                    'LX→',
                    'LY↑',
                    Colors.blue,
                  ),
                  Container(
                    height: 2,
                    color: Colors.grey.shade300,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                  if (_isLeftPanelOpen) _buildFixedKeyboard(),
                ],
              ),
            ),
          ),
          if (!_isLeftPanelOpen)
            GestureDetector(
              onTap: () => setState(() {
                _isLeftPanelOpen = true;
                _isRightPanelOpen = false;
                _activeController = null;
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
                      color: Colors.black.withValues(alpha: 0.2),
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

  Widget _buildRightPanel() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      right: _isRightPanelOpen ? 0 : (widget.showSideHandles ? -200 : -240),
      top: 97,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isRightPanelOpen)
            GestureDetector(
              onTap: () => setState(() {
                _isRightPanelOpen = true;
                _isLeftPanelOpen = false;
                _activeController = null;
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
                      color: Colors.black.withValues(alpha: 0.2),
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
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                        GestureDetector(
                          onTap: () => setState(() {
                            _isRightPanelOpen = false;
                            _activeController = null;
                          }),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                        const Row(
                          children: [
                            Text(
                              'Sağ',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.edit, color: Colors.white, size: 20),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildCornerEditor(
                    'Sağ Üst',
                    _sagUstX,
                    _sagUstY,
                    'RX←',
                    'RY↓',
                    Colors.orange,
                  ),
                  const Divider(height: 1),
                  _buildCornerEditor(
                    'Sağ Alt',
                    _sagAltX,
                    _sagAltY,
                    'RX←',
                    'RY↑',
                    Colors.orange,
                  ),
                  Container(
                    height: 2,
                    color: Colors.grey.shade300,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                  if (_isRightPanelOpen) _buildFixedKeyboard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCornerEditor(
    String label,
    TextEditingController xCtrl,
    TextEditingController yCtrl,
    String xLabel,
    String yLabel,
    Color themeColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: xCtrl,
                  readOnly: true,
                  showCursor: true,
                  onTap: () => setState(() {
                    _activeController = xCtrl;
                    _activeFieldLabel = xLabel;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (xCtrl.text.isNotEmpty) {
                        xCtrl.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: xCtrl.text.length,
                        );
                      }
                    });
                  }),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: xLabel,
                    labelStyle: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: _activeController == xCtrl
                        ? Colors.blue.shade50
                        : Colors.grey[50],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: yCtrl,
                  readOnly: true,
                  showCursor: true,
                  onTap: () => setState(() {
                    _activeController = yCtrl;
                    _activeFieldLabel = yLabel;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (yCtrl.text.isNotEmpty) {
                        yCtrl.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: yCtrl.text.length,
                        );
                      }
                    });
                  }),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: yLabel,
                    labelStyle: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: _activeController == yCtrl
                        ? Colors.red.shade50
                        : Colors.grey[50],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFixedKeyboard() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildKey('1'),
              _buildKey('2'),
              _buildKey('3'),
              _buildKey('4'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _buildKey('5'),
              _buildKey('6'),
              _buildKey('7'),
              _buildKey('8'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _buildKey('9'),
              _buildKey('0'),
              _buildDeleteKey(),
              Expanded(child: Container()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String value) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          elevation: 0.5,
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () => _onKeyPressed(value),
            child: Container(
              height: 40,
              alignment: Alignment.center,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteKey() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(4),
          elevation: 0.5,
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () => _onKeyPressed('⌫'),
            child: Container(
              height: 40,
              alignment: Alignment.center,
              child: Icon(
                Icons.backspace_outlined,
                color: Colors.red[400],
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
