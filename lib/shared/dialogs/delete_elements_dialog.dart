// lib/shared/dialogs/delete_elements_dialog.dart

import 'package:flutter/material.dart';
import '../../features/drawing/drawing_canvas_page.dart';
import '../../models/shape_spec.dart';

// Yan panel silme için özel ID prefix
const String _kSidePrefix = 'SIDE:';
String sideId(String side) => '$_kSidePrefix$side';
bool isSideId(String id) => id.startsWith(_kSidePrefix);
String sideFromId(String id) => id.substring(_kSidePrefix.length);

class DeleteElementsDialog extends StatefulWidget {
  final ShapeSpec shapeSpec;
  final int totalShapesCount;
  final int currentShapeIndex;
  final VoidCallback? onDeleteMainShape;

  const DeleteElementsDialog({
    super.key,
    required this.shapeSpec,
    this.totalShapesCount = 1,
    this.currentShapeIndex = 0,
    this.onDeleteMainShape,
  });

  @override
  State<DeleteElementsDialog> createState() => _DeleteElementsDialogState();
}

class _DeleteElementsDialogState extends State<DeleteElementsDialog> {
  final Set<String> _selectedIds = {};

  // ─── Gruplar ─────────────────────────────────────────────────────────────────

  List<InternalElement> get _horizontalLines => widget
      .shapeSpec
      .internalElements
      .where((e) => e.type == InternalElementType.horizontalLine)
      .toList();

  List<InternalElement> get _verticalLines => widget.shapeSpec.internalElements
      .where((e) => e.type == InternalElementType.verticalLine)
      .toList();

  List<InternalElement> get _symbols => widget.shapeSpec.internalElements
      .where(
        (e) =>
            e.type == InternalElementType.triangle ||
            e.type == InternalElementType.slideArrow ||
            e.type == InternalElementType.dotGrid ||
            e.type == InternalElementType.lineGrid,
      )
      .toList();

  List<SideAttachment> get _sideAttachments => widget.shapeSpec.sideAttachments;

  int get _totalSelected => _selectedIds.length;

  bool get _hasAnything =>
      _horizontalLines.isNotEmpty ||
      _verticalLines.isNotEmpty ||
      _symbols.isNotEmpty ||
      _sideAttachments.isNotEmpty;

  // ─── Seçim yönetimi ──────────────────────────────────────────────────────────

  void _toggle(String id) => setState(
    () => _selectedIds.contains(id)
        ? _selectedIds.remove(id)
        : _selectedIds.add(id),
  );

  void _selectGroup(List<String> ids) =>
      setState(() => _selectedIds.addAll(ids));

  void _deselectGroup(List<String> ids) =>
      setState(() => ids.forEach(_selectedIds.remove));

  bool _groupAllSelected(List<String> ids) =>
      ids.isNotEmpty && ids.every(_selectedIds.contains);

  // ─── Etiketler ───────────────────────────────────────────────────────────────

  String _lineLabel(InternalElement e) {
    final isShort = e.properties['isShort'] == true;
    if (e.type == InternalElementType.horizontalLine) {
      final y = e.position.dy.toInt();
      if (isShort) {
        final x1 = e.position.dx.toInt();
        final x2 = (e.position.dx + e.size.width).toInt();
        return 'Y: ${y}mm · X: $x1→${x2}mm';
      }
      return 'Y: ${y}mm · Genişlik: ${e.size.width.toInt()}mm';
    } else {
      final x = e.position.dx.toInt();
      if (isShort) {
        final y1 = (e.position.dy - e.size.height).toInt();
        final y2 = e.position.dy.toInt();
        return 'X: ${x}mm · Y: $y1→${y2}mm';
      }
      return 'X: ${x}mm · Yükseklik: ${e.size.height.toInt()}mm';
    }
  }

  String _symbolLabel(InternalElement e) {
    switch (e.type) {
      case InternalElementType.triangle:
        final dir = e.properties['direction'] ?? 'up';
        return 'Üçgen (${_dir(dir)})';
      case InternalElementType.slideArrow:
        final isRight =
            (e.properties['direction'] as String? ?? 'right') == 'right';
        return isRight ? 'Sağa Sürme' : 'Sola Sürme';
      case InternalElementType.dotGrid:
        return 'Desenli Cam';
      case InternalElementType.lineGrid:
        return 'Profil Camsız';
      default:
        return 'Sembol';
    }
  }

  String _dir(dynamic d) {
    switch (d.toString()) {
      case 'up':
        return 'Yukarı';
      case 'down':
        return 'Aşağı';
      case 'left':
        return 'Sol';
      case 'right':
        return 'Sağ';
      default:
        return d.toString();
    }
  }

  String _attachLabel(SideAttachment a) {
    final sideStr = a.side == 'left' ? 'Sol Panel' : 'Sağ Panel';
    final count = a.internalElements.length;
    final countStr = count == 0 ? 'boş' : '$count element';
    return '$sideStr · ${a.width.toInt()}×${a.height.toInt()}mm · $countStr';
  }

  // ─── Önizleme widget'ları ─────────────────────────────────────────────────────

  Widget _linePreview(InternalElement e) {
    final isShort = e.properties['isShort'] == true;
    final isH = e.type == InternalElementType.horizontalLine;
    final color = isH ? Colors.blue.shade600 : Colors.orange.shade600;
    if (isH) {
      return Container(width: isShort ? 22 : 36, height: 2, color: color);
    } else {
      return Container(width: 2, height: isShort ? 18 : 28, color: color);
    }
  }

  Widget _symbolPreview(InternalElement e) {
    switch (e.type) {
      case InternalElementType.triangle:
        final dir = TriangleDirection.values.byName(
          e.properties['direction'] as String? ?? 'up',
        );
        return CustomPaint(
          size: const Size(26, 26),
          painter: TriangleOutlinePainter(
            color: Colors.grey.shade700,
            direction: dir,
          ),
        );
      case InternalElementType.slideArrow:
        final isRight =
            (e.properties['direction'] as String? ?? 'right') == 'right';
        return Icon(
          isRight ? Icons.arrow_forward : Icons.arrow_back,
          size: 20,
          color: const Color(0xFF37474F),
        );
      case InternalElementType.dotGrid:
        return _dotGridPreview();
      case InternalElementType.lineGrid:
        return _lineGridPreview();
      default:
        return const SizedBox(width: 26, height: 26);
    }
  }

  Widget _dotGridPreview() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (r) => Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (c) => Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade600),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _lineGridPreview() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        4,
        (_) => Container(
          width: 24,
          height: 1,
          margin: const EdgeInsets.symmetric(vertical: 1.5),
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _attachPreview(SideAttachment a) {
    final isLeft = a.side == 'left';
    return Icon(
      isLeft ? Icons.first_page : Icons.last_page,
      size: 22,
      color: isLeft ? Colors.teal.shade600 : Colors.orange.shade700,
    );
  }

  // ─── Onay dialog ─────────────────────────────────────────────────────────────

  void _confirmDeleteMainShape() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade400),
            const SizedBox(width: 8),
            const Text('Ana Çizimi Sil'),
          ],
        ),
        content: Text(
          widget.totalShapesCount <= 1
              ? 'Bu çizimi sildiğinizde çizim ekranı kapanacak. Emin misiniz?'
              : '${widget.currentShapeIndex + 1}. çizimi silmek istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              widget.onDeleteMainShape?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 360,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(child: _hasAnything ? _buildBody() : _buildEmptyState()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Icon(Icons.delete_outline, color: Colors.red.shade400, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Şekilleri Sil',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close, size: 20, color: Colors.grey.shade500),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'Silinecek şekil yok',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 4),
      children: [
        if (_horizontalLines.isNotEmpty)
          _buildCategory(
            title: 'YATAY ÇİZGİLER',
            count: _horizontalLines.length,
            ids: _horizontalLines.map((e) => e.id).toList(),
            color: Colors.blue.shade700,
            items: _horizontalLines.map((e) => _buildLineItem(e)).toList(),
          ),
        if (_verticalLines.isNotEmpty)
          _buildCategory(
            title: 'DİKEY ÇİZGİLER',
            count: _verticalLines.length,
            ids: _verticalLines.map((e) => e.id).toList(),
            color: Colors.orange.shade700,
            items: _verticalLines.map((e) => _buildLineItem(e)).toList(),
          ),
        if (_symbols.isNotEmpty)
          _buildCategory(
            title: 'SEMBOLLER',
            count: _symbols.length,
            ids: _symbols.map((e) => e.id).toList(),
            color: Colors.grey.shade700,
            items: _symbols.map((e) => _buildSymbolItem(e)).toList(),
          ),
        if (_sideAttachments.isNotEmpty)
          _buildCategory(
            title: 'YAN PANELLER',
            count: _sideAttachments.length,
            ids: _sideAttachments.map((a) => sideId(a.side)).toList(),
            color: Colors.teal.shade700,
            items: _sideAttachments.map((a) => _buildAttachItem(a)).toList(),
            warning: 'Panel silinince içindeki tüm elementler de silinir',
          ),
      ],
    );
  }

  // ─── Kategori bölümü ─────────────────────────────────────────────────────────

  Widget _buildCategory({
    required String title,
    required int count,
    required List<String> ids,
    required Color color,
    required List<Widget> items,
    String? warning,
  }) {
    final allSelected = _groupAllSelected(ids);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kategori başlığı
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () =>
                    allSelected ? _deselectGroup(ids) : _selectGroup(ids),
                child: Text(
                  allSelected ? 'Hiçbiri' : 'Tümü',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (warning != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 12,
                  color: Colors.orange.shade600,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    warning,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        // Elemanlar
        ...items,
        Divider(height: 1, color: Colors.grey.shade100),
      ],
    );
  }

  // ─── Eleman satırları ─────────────────────────────────────────────────────────

  Widget _buildLineItem(InternalElement e) {
    final isShort = e.properties['isShort'] == true;
    final isSelected = _selectedIds.contains(e.id);
    final isH = e.type == InternalElementType.horizontalLine;
    final accentColor = isH ? Colors.blue.shade600 : Colors.orange.shade600;

    return _buildRow(
      id: e.id,
      isSelected: isSelected,
      preview: _linePreview(e),
      title: isShort ? 'Kısa' : 'Uzun',
      titleColor: isShort ? Colors.grey.shade600 : accentColor,
      subtitle: _lineLabel(e),
      badge: isShort ? 'KISA' : null,
      badgeColor: Colors.grey.shade500,
    );
  }

  Widget _buildSymbolItem(InternalElement e) {
    final isSelected = _selectedIds.contains(e.id);
    return _buildRow(
      id: e.id,
      isSelected: isSelected,
      preview: _symbolPreview(e),
      title: _symbolLabel(e),
      subtitle: null,
    );
  }

  Widget _buildAttachItem(SideAttachment a) {
    final id = sideId(a.side);
    final isSelected = _selectedIds.contains(id);
    final isLeft = a.side == 'left';
    return _buildRow(
      id: id,
      isSelected: isSelected,
      preview: _attachPreview(a),
      title: isLeft ? 'Sol Panel' : 'Sağ Panel',
      titleColor: isLeft ? Colors.teal.shade700 : Colors.orange.shade700,
      subtitle:
          '${a.width.toInt()}×${a.height.toInt()}mm · '
          '${a.internalElements.isEmpty ? "boş" : "${a.internalElements.length} element"}',
    );
  }

  Widget _buildRow({
    required String id,
    required bool isSelected,
    required Widget preview,
    required String title,
    Color? titleColor,
    String? subtitle,
    String? badge,
    Color? badgeColor,
  }) {
    return InkWell(
      onTap: () => _toggle(id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        color: isSelected ? Colors.red.shade50 : null,
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (_) => _toggle(id),
              activeColor: Colors.red.shade400,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 10),
            // Önizleme kutusu
            Container(
              width: 40,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? Colors.red.shade200
                      : Colors.grey.shade200,
                ),
              ),
              alignment: Alignment.center,
              child: preview,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: titleColor ?? Colors.grey.shade800,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? Colors.grey.shade500)
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: badgeColor ?? Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
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

  // ─── Footer ──────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seçim satırı
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                ),
                child: const Text('İptal'),
              ),
              const Spacer(),
              if (_totalSelected > 0) ...[
                Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_totalSelected seçili',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade600,
                    ),
                  ),
                ),
              ],
              ElevatedButton(
                onPressed: _totalSelected > 0
                    ? () => Navigator.pop(context, _selectedIds.toList())
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade500,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                ),
                child: const Text(
                  'Seçilenleri Sil',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          // Ana çizimi sil bölümü
          if (widget.onDeleteMainShape != null) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: _confirmDeleteMainShape,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_forever,
                      color: Colors.red.shade400,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ana Çizimi Sil',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade700,
                            ),
                          ),
                          Text(
                            widget.totalShapesCount <= 1
                                ? 'Son çizim — silince ekran kapanır'
                                : '${widget.totalShapesCount} çizimden bu silinecek',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.red.shade300,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
