import 'package:flutter/material.dart';

/// Minimal hesap makinesi diyaloğu.
/// Kullanımı:
///   showDialog(
///     context: context,
///     builder: (_) => const CalculatorDialog(),
///   );
class CalculatorDialog extends StatefulWidget {
  const CalculatorDialog({super.key});

  @override
  State<CalculatorDialog> createState() => _CalculatorDialogState();
}

class _CalculatorDialogState extends State<CalculatorDialog> {
  String _display = '0';
  double? _firstOperand;
  String? _pendingOperator;
  bool _shouldResetDisplay = false;

  static const _accent = Color(0xFF4A90E2);

  void _onNumberPressed(String number) {
    setState(() {
      if (_display == '0' || _shouldResetDisplay) {
        _display = number;
        _shouldResetDisplay = false;
      } else {
        _display += number;
      }
    });
  }

  void _onDecimalPressed() {
    setState(() {
      if (_shouldResetDisplay) {
        _display = '0.';
        _shouldResetDisplay = false;
        return;
      }
      if (!_display.contains('.')) {
        _display += '.';
      }
    });
  }

  void _onOperatorPressed(String operator) {
    setState(() {
      if (_firstOperand != null &&
          _pendingOperator != null &&
          !_shouldResetDisplay) {
        _calculate();
      }
      _firstOperand = double.tryParse(_display);
      _pendingOperator = operator;
      _shouldResetDisplay = true;
    });
  }

  void _calculate() {
    if (_firstOperand == null || _pendingOperator == null) return;
    final secondOperand = double.tryParse(_display) ?? 0;
    double result;

    switch (_pendingOperator) {
      case '+':
        result = _firstOperand! + secondOperand;
        break;
      case '-':
        result = _firstOperand! - secondOperand;
        break;
      case '×':
        result = _firstOperand! * secondOperand;
        break;
      case '÷':
        result = secondOperand == 0 ? 0 : _firstOperand! / secondOperand;
        break;
      default:
        result = secondOperand;
    }

    _display = (result == result.roundToDouble())
        ? result.toInt().toString()
        : result.toStringAsFixed(2);

    _firstOperand = null;
    _pendingOperator = null;
  }

  void _onEqualsPressed() {
    setState(() {
      _calculate();
      _shouldResetDisplay = true;
    });
  }

  void _onClearPressed() {
    setState(() {
      _display = '0';
      _firstOperand = null;
      _pendingOperator = null;
      _shouldResetDisplay = false;
    });
  }

  // Sayısal tuşlar — köşeli, kenarlıklı, operatör tuşlarıyla aynı üslupta
  Widget _key(
    String label, {
    VoidCallback? onTap,
    Color? bg,
    Color? fg,
    bool bold = false,
  }) {
    final hasCustomBg = bg != null;
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Material(
            color: bg ?? Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: hasCustomBg
                      ? null
                      : Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                      color: fg ?? const Color(0xFF2B2B2B),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Operatör tuşları — dar sütunda, verilen yüksekliği eşit paylaşır
  Widget _opKey(
    String label, {
    VoidCallback? onTap,
    Color? bg,
    Color? fg,
    bool bold = false,
  }) {
    final hasCustomBg = bg != null;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: bg ?? Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: hasCustomBg
                    ? null
                    : Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                    color: fg ?? const Color(0xFF2B2B2B),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 260,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Üst çubuk
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 18, color: Colors.grey),
                  ),
                ),
              ],
            ),
            // Ekran
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _display,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w300,
                      color: Color(0xFF1F1F1F),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Tuşlar — sol: dar operatör sütunu (C,÷,×,-,+), sağ: 4 satırlık sayı gridi
            // IntrinsicHeight, operatör sütununu sayı gridiyle aynı toplam
            // yüksekliğe sıkıştırır (5 tuş, 4 satırlık alana eşit paylaştırılır).
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            _key('7', onTap: () => _onNumberPressed('7')),
                            _key('8', onTap: () => _onNumberPressed('8')),
                            _key('9', onTap: () => _onNumberPressed('9')),
                          ],
                        ),
                        Row(
                          children: [
                            _key('4', onTap: () => _onNumberPressed('4')),
                            _key('5', onTap: () => _onNumberPressed('5')),
                            _key('6', onTap: () => _onNumberPressed('6')),
                          ],
                        ),
                        Row(
                          children: [
                            _key('1', onTap: () => _onNumberPressed('1')),
                            _key('2', onTap: () => _onNumberPressed('2')),
                            _key('3', onTap: () => _onNumberPressed('3')),
                          ],
                        ),
                        Row(
                          children: [
                            _key('0', onTap: () => _onNumberPressed('0')),
                            _key('.', onTap: _onDecimalPressed),
                            _key(
                              'C',
                              onTap: _onClearPressed,
                              fg: Colors.redAccent,
                              bold: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 52,
                    child: Column(
                      children: [
                        _opKey(
                          '÷',
                          onTap: () => _onOperatorPressed('÷'),
                          fg: _accent,
                          bold: true,
                        ),
                        _opKey(
                          '×',
                          onTap: () => _onOperatorPressed('×'),
                          fg: _accent,
                          bold: true,
                        ),
                        _opKey(
                          '-',
                          onTap: () => _onOperatorPressed('-'),
                          fg: _accent,
                          bold: true,
                        ),
                        _opKey(
                          '+',
                          onTap: () => _onOperatorPressed('+'),
                          fg: _accent,
                          bold: true,
                        ),
                        _opKey(
                          '=',
                          onTap: _onEqualsPressed,
                          bg: _accent,
                          fg: Colors.white,
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
