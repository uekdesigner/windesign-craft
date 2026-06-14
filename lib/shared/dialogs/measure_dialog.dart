// lib/shared/dialogs/measure_dialog.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/shape_spec.dart';

class MeasureDialog extends StatefulWidget {
  final ShapeSpec initial;
  final String title;

  const MeasureDialog({super.key, required this.initial, required this.title});

  @override
  State<MeasureDialog> createState() => _MeasureDialogState();
}

class _MeasureDialogState extends State<MeasureDialog> {
  late TextEditingController baseWidthCtrl;
  late TextEditingController baseHeightCtrl;

  TextEditingController? _activeController;
  String _activeFieldLabel = '';
  double _keyboardHeight = 180;
  double _keyFontSize = 18;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    baseWidthCtrl = TextEditingController(
      text: widget.initial.baseWidth.toInt().toString(),
    );
    baseHeightCtrl = TextEditingController(
      text: widget.initial.baseHeight.toInt().toString(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateKeyboardDimensions();
      setState(() {
        _activeController = baseWidthCtrl;
        _activeFieldLabel = 'Genişlik';
      });
    });
  }

  @override
  void dispose() {
    baseWidthCtrl.dispose();
    baseHeightCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _calculateKeyboardDimensions() {
    final mq = MediaQuery.of(context);
    _keyboardHeight = (mq.padding.bottom + (mq.size.height * 0.22)).clamp(
      160.0,
      260.0,
    );
    _keyFontSize = (mq.size.width * 0.04).clamp(16.0, 24.0);
  }

  void _onKeyPressed(String key) {
    if (_activeController == null) return;

    if (key == '⌫') {
      final text = _activeController!.text;
      if (text.isNotEmpty) {
        _activeController!.text = text.substring(0, text.length - 1);
      }
    } else if (key == 'OK') {
      _submitAndClose();
    } else {
      final current = _activeController!.text;
      if (current.length < 4) {
        _activeController!.text = current + key;
      }
    }
    _onFieldChanged();
  }

  void _submitAndClose() {
    final result = ShapeSpec(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Yeni Şekil',
      baseWidth: _parseDouble(baseWidthCtrl, 1000),
      baseHeight: _parseDouble(baseHeightCtrl, 1000),
    );
    Navigator.pop(context, result);
  }

  void _onFieldChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() {});
    });
  }

  double _parseDouble(TextEditingController ctrl, double defaultVal) {
    return double.tryParse(ctrl.text) ?? defaultVal;
  }

  Widget _buildKey(String value) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(4),
      elevation: 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => _onKeyPressed(value),
        splashColor: Colors.transparent,
        highlightColor: Colors.grey[200],
        child: Container(
          alignment: Alignment.center,
          child: Text(
            value,
            style: TextStyle(
              fontSize: _keyFontSize,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteKey() {
    return Material(
      color: Colors.red[50],
      borderRadius: BorderRadius.circular(4),
      elevation: 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => _onKeyPressed('⌫'),
        splashColor: Colors.transparent,
        highlightColor: Colors.red[100],
        child: Container(
          alignment: Alignment.center,
          child: Icon(
            Icons.backspace_outlined,
            color: Colors.red[400],
            size: _keyFontSize,
          ),
        ),
      ),
    );
  }

  Widget _buildDoneKey() {
    return Material(
      color: Colors.blue[600],
      borderRadius: BorderRadius.circular(4),
      elevation: 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => _onKeyPressed('OK'),
        splashColor: Colors.transparent,
        highlightColor: Colors.blue[800],
        child: Container(
          alignment: Alignment.center,
          child: Text(
            'OK',
            style: TextStyle(
              fontSize: _keyFontSize * 0.7,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
  }) {
    final isActive = _activeController == controller;

    return Expanded(
      child: TextField(
        controller: controller,
        readOnly: true,
        showCursor: true,
        onTap: () => setState(() {
          _activeController = controller;
          _activeFieldLabel = label;
        }),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          floatingLabelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.blue.shade700,
          ),
          prefixIcon: icon != null
              ? Icon(icon, size: 20, color: Colors.grey.shade500)
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isActive ? Colors.blue.shade400 : Colors.grey.shade300,
              width: isActive ? 2 : 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
          ),
          filled: true,
          fillColor: isActive ? Colors.blue.shade50 : Colors.grey.shade50,
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width > 600
        ? 450.0
        : screenSize.width * 0.92;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        width: dialogWidth,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Başlık + X butonu
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.grey.shade600,
                    ),
                    onPressed: () => Navigator.pop(context),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),

            // Genişlik / Yükseklik alanları
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  _buildFloatingField(
                    controller: baseWidthCtrl,
                    label: 'Genişlik (mm)',
                  ),
                  const SizedBox(width: 12),
                  _buildFloatingField(
                    controller: baseHeightCtrl,
                    label: 'Yükseklik (mm)',
                  ),
                ],
              ),
            ),

            // Aktif alan etiketi
            if (_activeFieldLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _activeFieldLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Klavye (HER ZAMAN GÖRÜNÜR)
            Container(
              height: _keyboardHeight,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!, width: 0.5),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: GridView.count(
                  crossAxisCount: 4,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 2.0,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildKey('1'),
                    _buildKey('2'),
                    _buildKey('3'),
                    _buildKey('4'),
                    _buildKey('5'),
                    _buildKey('6'),
                    _buildKey('7'),
                    _buildKey('8'),
                    _buildKey('9'),
                    _buildKey('0'),
                    _buildDeleteKey(),
                    _buildDoneKey(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
