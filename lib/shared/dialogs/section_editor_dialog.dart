// lib/shared/dialogs/section_editor_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/shape_spec.dart';

enum SectionAxis { horizontal, vertical }

class SectionEditorDialog extends StatefulWidget {
  final SectionAxis axis;
  final ShapeSpec shapeSpec;
  final double totalSize;
  final List<double> initialGaps; // n+1 item
  final List<InternalElement> shortLines;
  final int selectedLineIndex;
  final void Function(String elementId, double newPosition)? onShortLineChanged;
  final bool showHandle;
  final ScrollController? scrollController;

  const SectionEditorDialog({
    super.key,
    required this.axis,
    required this.shapeSpec,
    required this.totalSize,
    required this.initialGaps,
    this.shortLines = const [],
    required this.selectedLineIndex,
    this.onShortLineChanged,
    this.showHandle = false,
    this.scrollController,
  });

  static Future<List<double>?> showSliding(
    BuildContext context, {
    required SectionAxis axis,
    required ShapeSpec shapeSpec,
    required double totalSize,
    required List<double> initialGaps,
    List<InternalElement> shortLines = const [],
    required int selectedLineIndex,
    void Function(String, double)? onShortLineChanged,
  }) {
    return showModalBottomSheet<List<double>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black26,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.28,
        maxChildSize: 0.92,
        snap: true,
        snapSizes: const [0.42, 0.65, 0.92],
        builder: (ctx, scrollCtrl) => SectionEditorDialog(
          axis: axis,
          shapeSpec: shapeSpec,
          totalSize: totalSize,
          initialGaps: initialGaps,
          shortLines: shortLines,
          selectedLineIndex: selectedLineIndex,
          onShortLineChanged: onShortLineChanged,
          showHandle: true,
          scrollController: scrollCtrl,
        ),
      ),
    );
  }

  @override
  State<SectionEditorDialog> createState() => _SectionEditorDialogState();
}

class _SectionEditorDialogState extends State<SectionEditorDialog> {
  // Tüm gap'ler (n+1 item) — _lockedIndex olan gap otomatik hesaplanır
  late List<double> _allGaps;
  late List<TextEditingController> _gapControllers;

  // Hangi gap kilitli (varsayılan: son gap)
  late int _lockedIndex;

  // Kısa çizgi state
  late Map<String, double> _shortFromFirst;
  late Map<String, TextEditingController> _shortControllers;

  // Hangi panel kartları açık
  final Set<int> _expandedSections = {};

  // ─── Temel özellikler ───────────────────────────────────────────────────────

  bool get _isH => widget.axis == SectionAxis.horizontal;
  int get _nLines => widget.initialGaps.length - 1;

  // Kilitli gap'in hesaplanan değeri
  double get _lockedGapValue {
    double sum = 0;
    for (int i = 0; i < _allGaps.length; i++) {
      if (i != _lockedIndex) sum += _allGaps[i];
    }
    return widget.totalSize - sum;
  }

  bool get _isValid => _lockedGapValue >= 50;

  // ─── Uzun çizgi pozisyonları ─────────────────────────────────────────────────
  List<double> get _linePositions {
    final out = <double>[];
    if (_isH) {
      double cur = widget.totalSize;
      for (int i = 0; i < _nLines; i++) {
        cur -= (i == _lockedIndex) ? _lockedGapValue : _allGaps[i];
        out.add(cur);
      }
    } else {
      double cur = 0.0;
      for (int i = 0; i < _nLines; i++) {
        cur += (i == _lockedIndex) ? _lockedGapValue : _allGaps[i];
        out.add(cur);
      }
    }
    return out;
  }

  double _gapAt(int idx) =>
      idx == _lockedIndex ? _lockedGapValue : _allGaps[idx];

  (double first, double last) _sectionBounds(int idx) {
    final pos = _linePositions;
    if (_isH) {
      final top = idx == 0 ? widget.totalSize : pos[idx - 1];
      final bot = idx == _nLines ? 0.0 : pos[idx];
      return (top, bot);
    } else {
      final left = idx == 0 ? 0.0 : pos[idx - 1];
      final right = idx == _nLines ? widget.totalSize : pos[idx];
      return (left, right);
    }
  }

  int _sectionOf(InternalElement line) {
    final p = _isH ? line.position.dy : line.position.dx;
    for (int i = 0; i <= _nLines; i++) {
      final (f, l) = _sectionBounds(i);
      if (_isH && p <= f && p >= l) return i;
      if (!_isH && p >= f && p <= l) return i;
    }
    return 0;
  }

  double _fromFirstOf(InternalElement line) {
    final sIdx = _sectionOf(line);
    final (f, l) = _sectionBounds(sIdx);
    return _isH
        ? (f - line.position.dy).clamp(0.0, (f - l).abs())
        : (line.position.dx - f).clamp(0.0, (l - f).abs());
  }

  double _absolutePos(int sectionIdx, double fromFirst) {
    final (f, l) = _sectionBounds(sectionIdx);
    return _isH ? f - fromFirst : f + fromFirst;
  }

  // ─── Init / Dispose ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _allGaps = List<double>.from(widget.initialGaps);
    _lockedIndex = _allGaps.length - 1; // varsayılan: son gap kilitli

    _gapControllers = _allGaps
        .map((g) => TextEditingController(text: g.toInt().toString()))
        .toList();

    _shortFromFirst = {};
    _shortControllers = {};

    for (final line in widget.shortLines) {
      final ff = _fromFirstOf(line);
      _shortFromFirst[line.id] = ff;
      _shortControllers[line.id] = TextEditingController(
        text: ff.toInt().toString(),
      );
    }

    if (widget.selectedLineIndex >= 0 && widget.selectedLineIndex < _nLines) {
      final dialogIdx = _nLines - 1 - widget.selectedLineIndex;
      _expandedSections.add(dialogIdx);
      _expandedSections.add(dialogIdx + 1);
    }

    for (final line in widget.shortLines) {
      _expandedSections.add(_sectionOf(line));
    }
  }

  @override
  void dispose() {
    for (final c in _gapControllers) c.dispose();
    for (final c in _shortControllers.values) c.dispose();
    super.dispose();
  }

  // ─── Gap güncelleme ───────────────────────────────────────────────────────────

  void _onGapChanged(int idx, String raw) {
    if (idx == _lockedIndex) return;
    final v = double.tryParse(raw);
    if (v == null || v < 50) return;

    setState(() {
      _allGaps[idx] = v;
      // Kilitli gap controller'ını güncelle
      final lockedVal = _lockedGapValue;
      _gapControllers[_lockedIndex].text = lockedVal < 0
          ? '!'
          : lockedVal.toInt().toString();
      // Kısa çizgi display güncelle
      for (final line in widget.shortLines) {
        final ff = _fromFirstOf(line);
        _shortFromFirst[line.id] = ff;
        final ctrl = _shortControllers[line.id]!;
        ctrl.text = ff.toInt().toString();
      }
    });
  }

  // Kilit değiştir
  void _onLockTap(int newLockedIdx) {
    if (newLockedIdx == _lockedIndex) return;
    setState(() {
      // Mevcut kilitli gap'in hesaplanan değerini dondur
      final frozenVal = _lockedGapValue.clamp(50.0, double.infinity);
      _allGaps[_lockedIndex] = frozenVal;
      _gapControllers[_lockedIndex].text = frozenVal.toInt().toString();

      _lockedIndex = newLockedIdx;

      // Yeni kilitli gap controller'ını güncelle
      final newLockedVal = _lockedGapValue;
      _gapControllers[_lockedIndex].text = newLockedVal < 0
          ? '!'
          : newLockedVal.toInt().toString();
    });
  }

  // ─── Kısa çizgi güncelleme ────────────────────────────────────────────────────

  void _onShortChanged(InternalElement line, String raw) {
    final newFromFirst = double.tryParse(raw);
    if (newFromFirst == null || newFromFirst < 0) return;

    final sIdx = _sectionOf(line);
    final (f, l) = _sectionBounds(sIdx);
    final panelSize = (f - l).abs();
    if (newFromFirst >= panelSize) return;

    setState(() {
      _shortFromFirst[line.id] = newFromFirst;
    });

    final newPos = _absolutePos(sIdx, newFromFirst);
    widget.onShortLineChanged?.call(line.id, newPos);
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final title = _isH ? 'Yatay Bölümler' : 'Dikey Bölümler';
    final accent = _isH ? const Color(0xFF185FA5) : const Color(0xFFB45309);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showHandle) _buildDragHandle(),
        _buildHeader(title, accent),
        Flexible(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: (_nLines == 0 && widget.shortLines.isEmpty)
                ? _buildEmptyState()
                : _buildSectionList(accent),
          ),
        ),
        _buildFooter(accent),
      ],
    );

    if (widget.showHandle) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: Container(
          color: Theme.of(context).colorScheme.surface,
          child: content,
        ),
      );
    }

    final w = (MediaQuery.of(context).size.width * 0.92).clamp(280.0, 420.0);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: w,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: content,
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(String title, Color accent) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${widget.totalSize.toInt()} mm',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Empty state ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.horizontal_rule, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'Henüz çizgi eklenmemiş',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            'Tuval üzerinde çizgi ekleyip tekrar açın.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  // ─── Bölüm listesi ────────────────────────────────────────────────────────────

  Widget _buildSectionList(Color accent) {
    final items = <Widget>[];

    for (int sIdx = 0; sIdx <= _nLines; sIdx++) {
      final shortHere = widget.shortLines
          .where((l) => _sectionOf(l) == sIdx)
          .toList();

      final String icon;
      final String label;
      if (sIdx == 0) {
        icon = _isH ? '↑' : '←';
        label = _isH ? 'Üst boşluk' : 'Sol boşluk';
      } else if (sIdx == _nLines) {
        icon = _isH ? '↓' : '→';
        label = _isH ? 'Alt boşluk' : 'Sağ boşluk';
      } else {
        icon = '▣';
        label = 'Panel $sIdx';
      }

      items.add(_buildSection(sIdx, icon, label, shortHere, accent));

      if (sIdx < _nLines) {
        items.add(_buildLineDivider(sIdx, accent));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items,
    );
  }

  // ─── Tekleştirilmiş bölüm widget'ı ──────────────────────────────────────────

  Widget _buildSection(
    int sIdx,
    String icon,
    String label,
    List<InternalElement> shortHere,
    Color accent,
  ) {
    final isLocked = sIdx == _lockedIndex;
    final selectedDialogLine = _nLines > 0
        ? _nLines - 1 - widget.selectedLineIndex
        : -1;
    final isSelected =
        sIdx == selectedDialogLine || sIdx == selectedDialogLine + 1;
    final isExpanded = _expandedSections.contains(sIdx);
    final hasShort = shortHere.isNotEmpty;

    final bgColor = isLocked
        ? Colors.grey.shade50
        : isSelected
        ? Color.alphaBlend(accent.withOpacity(0.08), Colors.white)
        : Colors.grey.shade50;
    final borderColor = isLocked
        ? Colors.grey.shade200
        : isSelected
        ? accent.withOpacity(0.35)
        : Colors.grey.shade200;

    final (f, l) = _sectionBounds(sIdx);
    final panelSize = (f - l).abs();

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: hasShort
                  ? () => setState(
                      () => isExpanded
                          ? _expandedSections.remove(sIdx)
                          : _expandedSections.add(sIdx),
                    )
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Text(
                      icon,
                      style: TextStyle(
                        fontSize: 13,
                        color: isLocked
                            ? Colors.grey.shade500
                            : isSelected
                            ? accent
                            : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected && !isLocked
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isLocked
                              ? Colors.grey.shade700
                              : isSelected
                              ? accent
                              : Colors.grey.shade800,
                        ),
                      ),
                    ),
                    if (hasShort) ...[
                      _shortBadge(shortHere.length),
                      const SizedBox(width: 4),
                    ],
                    // Gap input veya kilitli değer
                    _buildGapField(sIdx, isLocked, isSelected, accent),
                    const SizedBox(width: 4),
                    // Kilit butonu
                    GestureDetector(
                      onTap: () => _onLockTap(sIdx),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          isLocked ? Icons.lock : Icons.lock_open,
                          size: 16,
                          color: isLocked
                              ? Colors.grey.shade500
                              : Colors.grey.shade300,
                        ),
                      ),
                    ),
                    if (hasShort) ...[
                      const SizedBox(width: 2),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 17,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (hasShort && isExpanded)
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200, width: 0.5),
                  ),
                ),
                child: Column(
                  children: shortHere
                      .map((l) => _buildShortRow(l, sIdx))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Gap input alanı (kilitli veya düzenlenebilir) ───────────────────────────

  Widget _buildGapField(int idx, bool isLocked, bool isSelected, Color accent) {
    final currentVal = _gapAt(idx);
    final isError = isLocked && currentVal < 50;

    if (isLocked) {
      // Kilitli: salt-okunur, otomatik hesaplanan değer
      return Container(
        width: 78,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isError ? Colors.red.shade300 : Colors.grey.shade200,
            width: 0.5,
          ),
        ),
        alignment: Alignment.centerRight,
        child: Text(
          '${currentVal < 0 ? '!' : currentVal.toInt()} mm',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isError ? Colors.red.shade600 : Colors.grey.shade600,
          ),
        ),
      );
    }

    // Düzenlenebilir
    return SizedBox(
      width: 78,
      child: TextField(
        controller: _gapControllers[idx],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isSelected ? accent : Colors.grey.shade900,
        ),
        onTap: () {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final c = _gapControllers[idx];
            if (c.text.isNotEmpty) {
              c.selection = TextSelection(
                baseOffset: 0,
                extentOffset: c.text.length,
              );
            }
          });
        },
        onChanged: (v) => _onGapChanged(idx, v),
        decoration: InputDecoration(
          suffixText: 'mm',
          suffixStyle: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 5,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: accent, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Colors.red.shade300),
          ),
          isDense: true,
          filled: true,
          fillColor: isSelected
              ? Color.alphaBlend(accent.withOpacity(0.06), Colors.white)
              : Colors.white,
          errorText: _allGaps[idx] < 50 ? 'Min 50' : null,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(5),
        ],
      ),
    );
  }

  // ─── Kısa çizgi satırı ───────────────────────────────────────────────────────

  Widget _buildShortRow(InternalElement line, int sectionIdx) {
    final fromFirst = _shortFromFirst[line.id] ?? 0.0;
    final (f, l) = _sectionBounds(sectionIdx);
    final panelSize = (f - l).abs();
    final fromLast = panelSize - fromFirst;
    final ctrl = _shortControllers[line.id]!;

    final firstLabel = _isH ? '↑ Üstten' : '← Soldan';
    final lastLabel = _isH ? '↓ Alttan' : '→ Sağdan';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isH ? 'Kısa yatay çizgi' : 'Kısa dikey çizgi',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.teal.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      firstLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal.shade800,
                      ),
                      onTap: () {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          ctrl.selection = TextSelection(
                            baseOffset: 0,
                            extentOffset: ctrl.text.length,
                          );
                        });
                      },
                      onChanged: (v) => _onShortChanged(line, v),
                      decoration: InputDecoration(
                        suffixText: 'mm',
                        suffixStyle: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 5,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.teal.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.teal.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: Colors.teal.shade500,
                            width: 1.5,
                          ),
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.teal.shade50,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(5),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16, left: 8, right: 8),
                child: Icon(
                  Icons.compare_arrows,
                  size: 14,
                  color: Colors.grey.shade300,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lastLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 0.5,
                        ),
                      ),
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${fromLast < 0 ? '!' : fromLast.toInt()} mm',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: fromLast < 0
                                  ? Colors.red.shade600
                                  : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.lock_outline,
                            size: 11,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Uzun çizgi ayracı ────────────────────────────────────────────────────────

  Widget _buildLineDivider(int lineIdx, Color accent) {
    final dialogLine = _nLines > 0
        ? _nLines - 1 - widget.selectedLineIndex
        : -1;
    final isSelected = lineIdx == dialogLine;
    final lineColor = isSelected
        ? accent.withOpacity(0.55)
        : Colors.grey.shade300;
    final labelColor = isSelected ? accent : Colors.grey.shade500;
    final labelBg = isSelected
        ? Color.alphaBlend(accent.withOpacity(0.1), Colors.white)
        : Colors.grey.shade100;
    final labelBorder = isSelected
        ? accent.withOpacity(0.35)
        : Colors.grey.shade200;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Container(height: 1.5, color: lineColor)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: labelBg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: labelBorder, width: 0.5),
            ),
            child: Text(
              'Uzun Çizgi ${lineIdx + 1}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: labelColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1.5, color: lineColor)),
        ],
      ),
    );
  }

  // ─── Kısa çizgi badge ────────────────────────────────────────────────────────

  Widget _shortBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$count kısa',
        style: TextStyle(fontSize: 11, color: Colors.teal.shade700),
      ),
    );
  }

  // ─── Footer ──────────────────────────────────────────────────────────────────

  Widget _buildFooter(Color accent) {
    final ok = _isValid;
    final lockedVal = _lockedGapValue;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('İptal'),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: ok ? const Color(0xFFEAF3DE) : const Color(0xFFFCEBEB),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              ok
                  ? '✓ ${widget.totalSize.toInt()} mm'
                  : '⚠ ${lockedVal.toInt()} mm fazla',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: ok ? const Color(0xFF3B6D11) : const Color(0xFFA32D2D),
              ),
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: ok
                ? () {
                    // Kilitli gap değerini uygula
                    final result = List<double>.from(_allGaps);
                    result[_lockedIndex] = _lockedGapValue;
                    Navigator.pop(context, result);
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text(
              'Uygula',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
