import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/shape_spec.dart';

class CornerEditDialog extends StatefulWidget {
  final ShapeSpec shape;
  final int cornerIndex; // 0:SolÜst, 1:SağÜst, 2:SağAlt, 3:SolAlt

  const CornerEditDialog({
    super.key,
    required this.shape,
    required this.cornerIndex,
  });

  @override
  State<CornerEditDialog> createState() => _CornerEditDialogState();
}

class _CornerEditDialogState extends State<CornerEditDialog> {
  late TextEditingController _xController;
  late TextEditingController _yController;

  final List<String> _titles = [
    'Sol Üst Köşe',
    'Sağ Üst Köşe',
    'Sağ Alt Köşe',
    'Sol Alt Köşe',
  ];

  final List<String> _xLabels = ['X₁ →', 'X₂ ←', 'X₃ ←', 'X₄ →'];
  final List<String> _yLabels = ['Y₁ ↓', 'Y₂ ↓', 'Y₃ ↑', 'Y₄ ↑'];

  @override
  void initState() {
    super.initState();
    final shape = widget.shape;
    final index = widget.cornerIndex;

    // Mevcut değerleri al
    double initialX, initialY;
    switch (index) {
      case 0: // Sol Üst
        initialX = shape.topLeftX;
        initialY = shape.topLeftY;
        break;
      case 1: // Sağ Üst
        initialX = shape.topRightX;
        initialY = shape.topRightY;
        break;
      case 2: // Sağ Alt
        initialX = shape.bottomRightX;
        initialY = shape.bottomRightY;
        break;
      case 3: // Sol Alt
        initialX = shape.bottomLeftX;
        initialY = shape.bottomLeftY;
        break;
      default:
        initialX = 0;
        initialY = 0;
    }

    _xController = TextEditingController(text: initialX.toInt().toString());
    _yController = TextEditingController(text: initialY.toInt().toString());
  }

  @override
  void dispose() {
    _xController.dispose();
    _yController.dispose();
    super.dispose();
  }

  ShapeSpec _getUpdatedShape() {
    final x = double.tryParse(_xController.text) ?? 0;
    final y = double.tryParse(_yController.text) ?? 0;
    final shape = widget.shape;

    switch (widget.cornerIndex) {
      case 0: // Sol Üst
        return shape.copyWith(topLeftX: x, topLeftY: y);
      case 1: // Sağ Üst
        return shape.copyWith(topRightX: x, topRightY: y);
      case 2: // Sağ Alt
        return shape.copyWith(bottomRightX: x, bottomRightY: y);
      case 3: // Sol Alt
        return shape.copyWith(bottomLeftX: x, bottomLeftY: y);
      default:
        return shape;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Başlık
            Text(
              _titles[widget.cornerIndex],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // X Değeri (Yatay)
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _xLabels[widget.cornerIndex],
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _xController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Yatay Değer (mm)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixText: '',
                    ),
                    autofocus: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Y Değeri (Dikey)
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _yLabels[widget.cornerIndex],
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _yController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Dikey Değer (mm)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixText: '',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Butonlar
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('İptal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, _getUpdatedShape());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                    ),
                    child: const Text('Uygula'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
