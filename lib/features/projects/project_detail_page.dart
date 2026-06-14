import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/project.dart';
import '../../../services/database.dart';

import '../../models/drawing.dart';
import '../drawing/providers/drawing_provider.dart';
import 'project_provider.dart';
import '../drawing/drawing_management_page.dart';
import 'project_edit_page.dart';
import '../../services/license_service.dart';
import '../../providers/license_provider.dart';

class ProjectDetailPage extends ConsumerStatefulWidget {
  final Project project;

  const ProjectDetailPage({super.key, required this.project});

  @override
  ConsumerState<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends ConsumerState<ProjectDetailPage> {
  Project? _currentProject;
  List<Map<String, dynamic>> _payments = [];
  double _discount = 0;
  bool _isDiscountEditing = false;

  final TextEditingController _discountController = TextEditingController();
  final FocusNode _discountFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentProject = widget.project;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshProjectData();
    });
  }

  @override
  void dispose() {
    _discountController.dispose();
    _discountFocusNode.dispose();
    super.dispose();
  }

  Future<void> _refreshProjectData() async {
    final updatedProject = await ref
        .read(projectProvider.notifier)
        .getProjectById(_currentProject!.id);
    if (updatedProject != null && mounted) {
      setState(() {
        _currentProject = updatedProject;
      });
    }
    await _loadPayments();
    await _loadDiscount();
  }

  Future<void> _loadDiscount() async {
    final result = await LocalDatabase().getProjectById(_currentProject!.id);
    if (result != null && mounted) {
      final discount = (result['discount'] as num?)?.toDouble() ?? 0;
      setState(() {
        _discount = discount;
        _discountController.text = discount > 0
            ? discount.toStringAsFixed(0)
            : '';
      });
    }
  }

  Future<void> _saveDiscount(double value) async {
    await LocalDatabase().updateProject({
      'id': _currentProject!.id,
      'name': _currentProject!.name,
      'phone': _currentProject!.phone,
      'address': _currentProject!.address,
      'description': _currentProject!.description,
      'created_at': _currentProject!.createdAt,
      'discount': value,
    });
  }

  Future<void> _loadPayments() async {
    final payments = await LocalDatabase().getPaymentsByProject(
      _currentProject!.id,
    );
    if (mounted) {
      setState(() => _payments = payments);
    }
  }

  Future<void> _deleteProject() async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Projeyi Sil'),
        content: Text(
          '${_currentProject!.name} projesini ve tüm çizimlerini silmek istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref
            .read(projectProvider.notifier)
            .deleteProject(_currentProject!.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_currentProject!.name} projesi silindi!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Silme hatası: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _goToDrawingManagement() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DrawingManagementPage(
          projectId: _currentProject!.id,
          customerName: _currentProject!.name,
          customerPhone: _currentProject!.phone, // ← ekle
          customerAddress: _currentProject!.address, // ← ekle
        ),
      ),
    );
  }

  void _goToEditPage() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProjectEditPage(project: _currentProject!),
      ),
    );

    if (result != null && result is Project && mounted) {
      setState(() {
        _currentProject = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentProject == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final drawings = ref.watch(drawingProvider(_currentProject!.id));
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentProject!.name),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshProjectData,
            tooltip: 'Projeyi Yenile',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _goToEditPage,
            tooltip: 'Proje Bilgilerini Düzenle',
          ),
          Consumer(
            builder: (context, ref, _) {
              final licenseAsync = ref.watch(licenseProvider);
              final isLicensed =
                  licenseAsync.whenOrNull(data: (lic) => lic.isLicensed) ??
                  false;

              return IconButton(
                icon: Icon(
                  Icons.delete,
                  color: isLicensed ? null : Colors.grey.shade400,
                ),
                onPressed: isLicensed
                    ? _deleteProject
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Proje silme yalnızca lisanslı kullanıcılara açıktır.',
                            ),
                            backgroundColor: Colors.orange.shade800,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                tooltip: 'Projeyi Sil',
              );
            },
          ),
        ],
      ),
      body: isLandscape
          ? _buildLandscapeLayout(drawings)
          : _buildPortraitLayout(drawings),
    );
  }

  // 📱 DİKEY MOD - Kompakt düzen
  Widget _buildPortraitLayout(List<Drawing> drawings) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Proje Bilgileri Kartı
          _buildCompactProjectInfoCard(),

          const SizedBox(height: 20),

          // 🎨 YENİ: Çizim Butonları (Yan Yana)
          _buildDrawingButtons(drawings),
          const SizedBox(height: 20),
          _buildPaymentSection(drawings),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPaymentSection(List<Drawing> drawings) {
    // Toplam hesapla
    double grandTotal = 0;
    for (final drawing in drawings) {
      for (final shape in drawing.shapes) {
        if (shape.price != null) grandTotal += shape.price!;
      }
    }

    // Ödenen
    double totalPaid = _payments.fold(
      0,
      (sum, p) => sum + (p['amount'] as double),
    );

    final netTotal = grandTotal - _discount;
    final remaining = netTotal - totalPaid;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  color: Colors.blue.shade700,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'Ödeme Takibi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Genel toplam
            _buildPaymentRow('Genel Toplam', grandTotal, Colors.black87),

            // İskonto
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'İskonto',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() => _isDiscountEditing = true);
                    _discountFocusNode.requestFocus();
                  },
                  child: _isDiscountEditing
                      ? SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _discountController,
                            focusNode: _discountFocusNode,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textAlign: TextAlign.right,
                            autofocus: true,
                            decoration: InputDecoration(
                              prefixText: '₺',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              hintText: '0',
                            ),
                            style: const TextStyle(fontSize: 14),
                            onChanged: (val) {
                              setState(() {
                                _discount =
                                    double.tryParse(val.replaceAll(',', '.')) ??
                                    0;
                              });
                            },
                            onSubmitted: (val) async {
                              final value =
                                  double.tryParse(val.replaceAll(',', '.')) ??
                                  0;
                              setState(() {
                                _discount = value;
                                _isDiscountEditing = false;
                              });
                              await _saveDiscount(value);
                            },
                            onTapOutside: (_) async {
                              setState(() => _isDiscountEditing = false);
                              await _saveDiscount(_discount);
                            },
                          ),
                        )
                      : Container(
                          width: 120,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                _discount > 0
                                    ? '₺${_discount.toStringAsFixed(0)}'
                                    : '₺0',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _discount > 0
                                      ? Colors.red.shade600
                                      : Colors.grey.shade400,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.edit,
                                size: 12,
                                color: Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            _buildPaymentRow(
              'Net Toplam',
              netTotal,
              Colors.blue.shade700,
              bold: true,
            ),

            const Divider(height: 16),

            // Ödeme listesi
            if (_payments.isNotEmpty) ...[
              Text(
                'Ödemeler',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 6),
              ..._payments.map((p) {
                final date = DateTime.parse(p['paid_at'] as String);
                final dateStr =
                    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
                final note = p['note'] as String?;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Colors.green.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (note != null && note.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            note,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else
                        const Spacer(),
                      Text(
                        '₺${(p['amount'] as double).toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: Colors.red.shade300,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _deletePayment(p['id'] as int),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 12),
            ],

            // Ödenen / Kalan
            _buildPaymentRow('Ödenen', totalPaid, Colors.green.shade700),
            const SizedBox(height: 4),
            _buildPaymentRow(
              'Kalan',
              remaining,
              remaining > 0 ? Colors.red.shade600 : Colors.green.shade600,
              bold: true,
            ),

            const SizedBox(height: 12),

            // Ödeme ekle butonu
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showAddPaymentDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ödeme Ekle'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                  side: BorderSide(color: Colors.blue.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentRow(
    String label,
    double amount,
    Color color, {
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          '₺${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showAddPaymentDialog() {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Ödeme Ekle', style: TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Tutar (₺)',
                  prefixText: '₺',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setDialogState(() => selectedDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tarih',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today, size: 18),
                  ),
                  child: Text(
                    '${selectedDate.day.toString().padLeft(2, '0')}.${selectedDate.month.toString().padLeft(2, '0')}.${selectedDate.year}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Not (opsiyonel)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(
                  amountCtrl.text.trim().replaceAll(',', '.'),
                );
                if (amount == null || amount <= 0) return;

                await LocalDatabase().insertPayment({
                  'project_id': _currentProject!.id,
                  'amount': amount,
                  'paid_at': selectedDate.toIso8601String(),
                  'note': noteCtrl.text.trim().isEmpty
                      ? null
                      : noteCtrl.text.trim(),
                });

                await _loadPayments();
                if (mounted) Navigator.pop(ctx);
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePayment(int id) async {
    await LocalDatabase().deletePayment(id);
    await _loadPayments();
  }

  // 🌅 YATAY MOD - Yan yana düzen
  Widget _buildLandscapeLayout(List<Drawing> drawings) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SOL: Proje Bilgileri
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildCompactProjectInfoCard(),
                  const SizedBox(height: 16),
                  _buildDrawingButtons(drawings),
                  const SizedBox(height: 16),
                  _buildPaymentSection(drawings),
                ],
              ),
            ),
          ),

          const SizedBox(width: 16),
        ],
      ),
    );
  }

  // 🎨 YENİ: Kompakt Proje Bilgileri Kartı
  // 🎨 Kompakt Proje Bilgileri Kartı (Başlıksız)
  Widget _buildCompactProjectInfoCard() {
    final date = DateTime.parse(_currentProject!.createdAt);
    final formattedDate = '${date.day}/${date.month}/${date.year}';

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          // crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🎨 SADECE İKON (Başlık AppBar'da zaten var)
            // Row(
            //   children: [
            //     Container(
            //       padding: const EdgeInsets.all(8),
            //       decoration: BoxDecoration(
            //         color: Colors.amber[50],
            //         borderRadius: BorderRadius.circular(8),
            //       ),
            //       child: Icon(Icons.folder, color: Colors.amber[700], size: 28),
            //     ),
            //     const SizedBox(width: 12),
            //     // Text(
            //     //   'ID: ${_currentProject!.id}',
            //     //   style: TextStyle(
            //     //     fontSize: 14,
            //     //     fontWeight: FontWeight.w600,
            //     //     color: Colors.grey[600],
            //     //   ),
            //     // ),
            //   ],
            // ),
            // const Divider(height: 16),

            // Telefon (Tıklanabilir)
            _buildInfoRow(
              icon: Icons.phone,
              iconColor: Colors.green,
              label: 'Telefon',
              value: _formatPhoneNumber(_currentProject!.phone),
              onTap: () => _launchPhone(_currentProject!.phone),
              trailing: const Icon(Icons.call, size: 18, color: Colors.green),
            ),

            const SizedBox(height: 12),

            // Adres
            _buildInfoRow(
              icon: Icons.location_on,
              iconColor: Colors.red,
              label: 'Adres',
              value: _currentProject!.address,
            ),

            // Açıklama (varsa)
            if (_currentProject!.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.description,
                iconColor: Colors.blue,
                label: 'Açıklama',
                value: _currentProject!.description,
                maxLines: 3,
              ),
            ],

            const SizedBox(height: 12),

            // Tarih
            _buildInfoRow(
              icon: Icons.calendar_today,
              iconColor: Colors.grey,
              label: 'Kayıt Tarihi',
              value: formattedDate,
            ),
          ],
        ),
      ),
    );
  }

  // 🎨 YENİ: Çizim Butonları (Yan Yana)
  // 🎨 Çizim Butonları (Yan Yana)
  Widget _buildDrawingButtons(List<Drawing> drawings) {
    final drawingCount = drawings.length;
    final hasDrawings = drawingCount > 0; // 🚨 YENİ: Kontrol

    return Row(
      children: [
        // Çizimler Butonu (Sol) - Çizim yoksa pasif
        Expanded(
          child: ElevatedButton.icon(
            onPressed: hasDrawings
                ? _goToDrawingManagement
                : null, // 🚨 DEĞİŞTİ: null = pasif
            icon: const Icon(Icons.architecture),
            label: Text(
              drawingCount == 0 ? 'Çizimler' : '$drawingCount Çizim',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasDrawings
                  ? Colors.amber[50]
                  : Colors.grey[200], // 🚨 DEĞİŞTİ: Gri arka plan
              foregroundColor: hasDrawings
                  ? Colors.amber[800]
                  : Colors.grey[500], // 🚨 DEĞİŞTİ: Soluk renk
              elevation: hasDrawings ? 2 : 0, // 🚨 DEĞİŞTİ: Gölge yok
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: hasDrawings
                      ? Colors.amber[200]!
                      : Colors.grey[300]!, // 🚨 DEĞİŞTİ: Gri border
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Yeni Çizim Butonu (Sağ) - Her zaman aktif
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _goToDrawingManagement,
            icon: const Icon(Icons.add),
            label: const Text(
              'Yeni Çizim',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 🎨 YENİ: Ekstra Bilgiler Bölümü (Boş alan değerlendirmesi)

  // Yardımcı: Bilgi Satırı
  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    int maxLines = 2,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  String _formatPhoneNumber(String phone) {
    if (phone.isEmpty) return '';

    String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');

    if (cleanPhone.startsWith('+90') && cleanPhone.length == 13) {
      String number = cleanPhone.substring(3);
      return '+90 (${number.substring(0, 3)}) ${number.substring(3, 6)} ${number.substring(6, 8)} ${number.substring(8)}';
    } else if (cleanPhone.startsWith('90') && cleanPhone.length == 12) {
      String number = cleanPhone.substring(2);
      return '+90 (${number.substring(0, 3)}) ${number.substring(3, 6)} ${number.substring(6, 8)} ${number.substring(8)}';
    } else if (cleanPhone.startsWith('0') && cleanPhone.length == 11) {
      String number = cleanPhone.substring(1);
      return '+90 (${number.substring(0, 3)}) ${number.substring(3, 6)} ${number.substring(6, 8)} ${number.substring(8)}';
    }

    return phone;
  }

  Future<void> _launchPhone(String phone) async {
    try {
      String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');

      if (!cleanPhone.startsWith('+')) {
        if (cleanPhone.startsWith('90') && cleanPhone.length > 2) {
          cleanPhone = '+$cleanPhone';
        } else if (!cleanPhone.startsWith('90')) {
          cleanPhone = '+90$cleanPhone';
        } else {
          cleanPhone = '+$cleanPhone';
        }
      }

      cleanPhone = cleanPhone.replaceAll(RegExp(r'[^\d+]'), '');
      final String url = 'tel:$cleanPhone';

      if (await canLaunch(url)) {
        await launch(url);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Arama yapılamıyor'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Arama hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
