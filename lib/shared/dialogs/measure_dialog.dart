// lib/presentation/dialogs/measure_dialog.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../features/drawing/painters/quadrilateral_painter.dart';
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
  late TextEditingController cropTopLeftCtrl;
  late TextEditingController cropTopRightCtrl;
  late TextEditingController cropBottomLeftCtrl;
  late TextEditingController cropBottomRightCtrl;

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
    cropTopLeftCtrl = TextEditingController(
      text: widget.initial.cropTopLeft.toInt().toString(),
    );
    cropTopRightCtrl = TextEditingController(
      text: widget.initial.cropTopRight.toInt().toString(),
    );
    cropBottomLeftCtrl = TextEditingController(
      text: widget.initial.cropBottomLeft.toInt().toString(),
    );
    cropBottomRightCtrl = TextEditingController(
      text: widget.initial.cropBottomRight.toInt().toString(),
    );
  }

  @override
  void dispose() {
    baseWidthCtrl.dispose();
    baseHeightCtrl.dispose();
    cropTopLeftCtrl.dispose();
    cropTopRightCtrl.dispose();
    cropBottomLeftCtrl.dispose();
    cropBottomRightCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onFieldChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {});
    });
  }

  double _parseDouble(TextEditingController ctrl, double defaultVal) {
    final val = double.tryParse(ctrl.text);
    return val ?? defaultVal;
  }

  // YENİ: Floating Label (Yuvarlanan Etiket) ile Kompakt Input
  Widget _buildFloatingField({
    required TextEditingController controller,
    required String label, // "Sol Üst", "Genişlik" vb.
    IconData? icon,
  }) {
    return Expanded(
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
        ],
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          // 🎯 Floating Label: Boşken içeride, focus'ta border üzerinde
          labelText: label,
          labelStyle: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          // Focus'ta yukarıda küçük görünmesi için:
          floatingLabelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.blue.shade700,
          ),

          // İkon (opsiyonel)
          prefixIcon: icon != null
              ? Icon(icon, size: 20, color: Colors.grey.shade500)
              : null,

          // mm birimi sağda
          suffixText: 'mm',
          suffixStyle: TextStyle(fontSize: 12, color: Colors.grey.shade600),

          // 🎯 OutlineBorder: Label bu çizginin üzerine "yuvarlanacak"
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
          ),

          // Kompakt ama floating label için yeterli alan
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 16,
          ),
          isDense: true,
          filled: true,
          fillColor: Colors.grey.shade50,

          // 🎯 Floating Label davranışı (auto = focus'ta yukarı çıkar)
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
        onChanged: (_) => _onFieldChanged(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = ShapeSpec(
      id: 'preview_${DateTime.now().millisecondsSinceEpoch}', // ✅ Ekle
      name: 'Preview', // ✅ Ekle
      baseWidth: _parseDouble(baseWidthCtrl, 1000),
      baseHeight: _parseDouble(baseHeightCtrl, 1000),
      topLeftX: _parseDouble(cropTopLeftCtrl, 0), // ✅ cropTopLeft -> topLeftX
      topLeftY: 0, // ✅ Yeni (Y değeri)
      topRightX: _parseDouble(
        cropTopRightCtrl,
        0,
      ), // ✅ cropTopRight -> topRightX
      topRightY: 0, // ✅ Yeni
      bottomLeftX: _parseDouble(
        cropBottomLeftCtrl,
        0,
      ), // ✅ cropBottomLeft -> bottomLeftX
      bottomLeftY: 0, // ✅ Yeni
      bottomRightX: _parseDouble(
        cropBottomRightCtrl,
        0,
      ), // ✅ cropBottomRight -> bottomRightX
      bottomRightY: 0, // ✅ Yeni
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Başlık
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // Base Ölçüler
              Row(
                children: [
                  _buildFloatingField(
                    controller: baseWidthCtrl,
                    label:
                        'Genişlik', // İçeride başlar, tıklayınca border üzerine çıkar
                  ),
                  const SizedBox(width: 10),
                  _buildFloatingField(
                    controller: baseHeightCtrl,
                    label: 'Yükseklik',
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // 🎯 AYIRICI ÇİZGİ (Divider)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                ), // Üstten ve alttan boşluk
                child: Divider(
                  height: 1, // Çizgi kalınlığı
                  thickness: 1, // Gerçek kalınlık
                  color: Colors
                      .grey
                      .shade300, // Renk (istersen 200 daha açık olur)
                  // indent: 16,                // Soldan boşluk (isteğe bağlı)
                  // endIndent: 16,             // Sağdan boşluk (isteğe bağlı)
                ),
              ),

              Row(
                children: [
                  _buildFloatingField(
                    controller: cropTopLeftCtrl,
                    label: 'Sol Üst', // Boşken içeride görünür
                  ),
                  const SizedBox(width: 10),
                  _buildFloatingField(
                    controller: cropTopRightCtrl,
                    label: 'Sağ Üst',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildFloatingField(
                    controller: cropBottomLeftCtrl,
                    label: 'Sol Alt',
                  ),
                  const SizedBox(width: 10),
                  _buildFloatingField(
                    controller: cropBottomRightCtrl,
                    label: 'Sağ Alt',
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Preview
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CustomPaint(
                    painter: ShapePainter(preview),
                    size: const Size(double.infinity, 200),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // İptal - Floating Action Button (Küçük)
                    FloatingActionButton.small(
                      onPressed: () => Navigator.pop(context),
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red.shade700,
                      elevation: 2,
                      heroTag: 'cancel',
                      child: const Icon(Icons.close_rounded),
                    ),

                    // Uygula - Floating Action Button (Büyük, Vurgulu)
                    FloatingActionButton.small(
                      onPressed: () => Navigator.pop(context, preview),
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      heroTag: 'apply',
                      child: const Icon(Icons.check_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
