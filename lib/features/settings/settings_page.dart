// lib/features/settings/settings_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../providers/license_provider.dart';
import '../../screens/redeem_key_screen.dart';
import '../../screens/redeem_corporate_key_screen.dart';
import '../../screens/team_management_screen.dart';
import '../../services/license_service.dart';
import '../../services/backup_service.dart';
import '../../services/excel_export_service.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage>
    with SingleTickerProviderStateMixin {
  static const String _yazilimAdi = 'WinDesign Craft Pro';
  static const String _ureticiFirma = 'UEK DESIGNER';
  static const String _ureticiFirmaMail = 'info@uekdesigner.com';
  static const String _ureticiFirmaTel = '+90 543 872 39 26';
  static const int _copyrightYil = 2026;
  static const String _versiyon = 'v1.0.0';

  static const String _keyFirmaAdi = 'firma_adi';
  static const String _keyFirmaAdres = 'firma_adres';
  static const String _keyLogoPath = 'logo_path';
  static const String _keyFirmaTel = 'firma_tel';
  static const String _keyFirmaEmail = 'firma_email';

  final TextEditingController _firmaAdiCtrl = TextEditingController();
  final TextEditingController _firmaAdresCtrl = TextEditingController();
  final TextEditingController _firmaTelCtrl = TextEditingController();
  final TextEditingController _firmaEmailCtrl = TextEditingController();

  String? _logoPath;
  bool _isLoading = true;
  bool _isSaving = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _firmaAdiCtrl.dispose();
    _firmaAdresCtrl.dispose();
    _tabController.dispose();
    _firmaTelCtrl.dispose();
    _firmaEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _firmaAdiCtrl.text = prefs.getString(_keyFirmaAdi) ?? '';
      _firmaAdresCtrl.text = prefs.getString(_keyFirmaAdres) ?? '';
      final tel = prefs.getString(_keyFirmaTel) ?? '';
      _firmaTelCtrl.text = tel.startsWith('+90 ') ? tel.substring(4) : tel;
      _firmaEmailCtrl.text = prefs.getString(_keyFirmaEmail) ?? '';
      _logoPath = prefs.getString(_keyLogoPath);
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFirmaAdi, _firmaAdiCtrl.text.trim());
    await prefs.setString(_keyFirmaAdres, _firmaAdresCtrl.text.trim());
    await prefs.setString(_keyFirmaTel, '+90 ${_firmaTelCtrl.text.trim()}');
    await prefs.setString(_keyFirmaEmail, _firmaEmailCtrl.text.trim());
    if (_logoPath != null) {
      await prefs.setString(_keyLogoPath, _logoPath!);
    }
    setState(() => _isSaving = false);
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null) return;
    final appDir = await getApplicationDocumentsDirectory();
    final logoDir = Directory('${appDir.path}/logos');
    if (!await logoDir.exists()) await logoDir.create(recursive: true);
    final ext = path.extension(picked.path);
    final dest = '${logoDir.path}/firma_logo$ext';
    await File(picked.path).copy(dest);
    setState(() => _logoPath = dest);
  }

  Future<void> _removeLogo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLogoPath);
    setState(() => _logoPath = null);
  }

  Future<void> _exportBackup() async {
    try {
      await BackupService().exportBackup();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Yedekleme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importBackup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Geri Yükle'),
        content: const Text(
          'Mevcut veriler korunur, yedekteki veriler üzerine eklenir. Devam etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Devam Et'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final (success, message) = await BackupService().importBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Geri yükleme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportExcel() async {
    try {
      await ExcelExportService.exportAndShare();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel aktarım hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
        backgroundColor: const Color.fromARGB(255, 110, 178, 247),
        foregroundColor: Colors.white,
        actions: [
          ListenableBuilder(
            listenable: _tabController,
            builder: (_, __) {
              if (_tabController.index != 0) return const SizedBox.shrink();
              return TextButton.icon(
                onPressed: _isSaving ? null : _saveSettings,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save, color: Colors.white, size: 20),
                label: Text(
                  _isSaving ? 'Kaydediliyor...' : 'Kaydet',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Genel'),
            Tab(text: 'Lisans'),
            Tab(text: 'Hakkında'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildGenelTab(),
                _buildLisansTab(),
                _buildHakkindaTab(),
              ],
            ),
    );
  }

  // ── GENEL SEKMESİ ─────────────────────────────────────────────────────────

  Widget _buildGenelTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFirmaBilgileriSection(),
          const SizedBox(height: 16),
          _buildLogoSection(),
          const SizedBox(height: 16),
          _buildYedeklemeSection(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _exportExcel,
              icon: Icon(
                Icons.table_chart_outlined,
                size: 18,
                color: Colors.teal.shade600,
              ),
              label: Text(
                'Excel\'e Aktar',
                style: TextStyle(color: Colors.teal.shade600),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.teal.shade300),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── LİSANS SEKMESİ ────────────────────────────────────────────────────────

  Widget _buildLisansTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHesapBilgileriSection(),
          const SizedBox(height: 16),
          _buildLisansBilgileriSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── HAKKINDA SEKMESİ ──────────────────────────────────────────────────────

  Widget _buildHakkindaTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_buildHakkindaSection(), const SizedBox(height: 32)],
      ),
    );
  }

  // ── Hesap Bilgileri ───────────────────────────────────────────────────────

  Widget _buildHesapBilgileriSection() {
    final user = FirebaseAuth.instance.currentUser;
    final rawPhone = user?.phoneNumber ?? '';
    final phone = rawPhone.isEmpty
        ? 'Doğrulanmamış'
        : rawPhone.replaceFirstMapped(
            RegExp(r'^\+90(\d{3})(\d{3})(\d{2})(\d{2})$'),
            (m) => '+90 ${m[1]} ${m[2]} ${m[3]} ${m[4]}',
          );
    final email = user?.email ?? 'Bilinmiyor';

    return _buildCard(
      title: 'HESAP BİLGİLERİ',
      icon: Icons.person_outline,
      iconColor: Colors.indigo.shade600,
      child: Column(
        children: [
          _buildLockedField(
            icon: Icons.email_outlined,
            label: 'E-posta',
            value: email,
          ),
          const SizedBox(height: 12),
          _buildLockedField(
            icon: Icons.phone_outlined,
            label: 'Telefon',
            value: phone,
          ),
        ],
      ),
    );
  }

  // ── Firma Bilgileri ───────────────────────────────────────────────────────

  Widget _buildFirmaBilgileriSection() {
    return _buildCard(
      title: 'FİRMA BİLGİLERİ',
      icon: Icons.business,
      iconColor: const Color.fromARGB(255, 110, 178, 247),
      child: Column(
        children: [
          _buildTextField(
            controller: _firmaAdiCtrl,
            label: 'Firma Adı',
            hint: 'Örn: ABC Doğrama',
            icon: Icons.business_outlined,
          ),
          const SizedBox(height: 12),
          // Telefon alanı — +90 sabit prefix, formatter ile otomatik format
          TextField(
            controller: _firmaTelCtrl,
            keyboardType: TextInputType.phone,
            maxLength: 13,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d\s]')),
              _PhoneInputFormatter(),
            ],
            decoration: InputDecoration(
              labelText: 'Telefon',
              hintText: '555 000 00 00',
              prefixText: '+90 ',
              prefixStyle: const TextStyle(color: Colors.black87, fontSize: 14),
              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              isDense: true,
              counterText: '',
            ),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _firmaEmailCtrl,
            label: 'E-posta',
            hint: 'Örn: info@firma.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _firmaAdresCtrl,
            label: 'Adres',
            hint: 'Örn: İstanbul, Kadıköy',
            icon: Icons.location_on_outlined,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  // ── Logo ──────────────────────────────────────────────────────────────────

  Widget _buildLogoSection() {
    return _buildCard(
      title: 'FİRMA LOGOSU',
      icon: Icons.image_outlined,
      iconColor: Colors.orange.shade600,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PDF\'lerde firma antetinde görünür. Logo seçilmezse sadece firma adı yazılır.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                child: _logoPath != null && File(_logoPath!).existsSync()
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_logoPath!),
                          fit: BoxFit.contain,
                        ),
                      )
                    : Icon(
                        Icons.image_outlined,
                        size: 36,
                        color: Colors.grey.shade400,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickLogo,
                      icon: const Icon(Icons.upload, size: 18),
                      label: Text(
                        _logoPath != null ? 'Logoyu Değiştir' : 'Logo Seç',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(
                          255,
                          110,
                          178,
                          247,
                        ),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    if (_logoPath != null) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _removeLogo,
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.red.shade400,
                        ),
                        label: Text(
                          'Logoyu Kaldır',
                          style: TextStyle(color: Colors.red.shade400),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red.shade200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Yedekleme ─────────────────────────────────────────────────────────────

  Widget _buildYedeklemeSection() {
    return _buildCard(
      title: 'VERİ YÖNETİMİ',
      icon: Icons.backup_outlined,
      iconColor: Colors.teal.shade600,
      child: Column(
        children: [
          Text(
            'Projelerinizi ve çizimlerinizi yedekleyin. Uygulama silinmeden önce yedek alarak verilerinizi koruyun.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _exportBackup,
              icon: const Icon(Icons.upload, size: 18),
              label: const Text('Yedekle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _importBackup,
              icon: Icon(Icons.download, size: 18, color: Colors.teal.shade600),
              label: Text(
                'Geri Yükle',
                style: TextStyle(color: Colors.teal.shade600),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.teal.shade300),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Lisans Bilgileri ──────────────────────────────────────────────────────

  Widget _buildLisansBilgileriSection() {
    final licenseAsync = ref.watch(licenseProvider);

    return _buildCard(
      title: 'LİSANS BİLGİLERİ',
      icon: Icons.verified_user_outlined,
      iconColor: Colors.green.shade700,
      child: licenseAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (_, __) => const Text(
          'Lisans bilgisi yüklenemedi.',
          style: TextStyle(color: Colors.red),
        ),
        data: (lic) {
          final String planText;
          final Color planColor;
          final IconData planIcon;

          if (lic.isLicensed) {
            if (lic.tier == 'corporate') {
              planText = lic.isOrgOwner
                  ? 'Kurumsal Lisans (Sahip)'
                  : 'Kurumsal Lisans';
            } else {
              planText = lic.tier == 'yearly'
                  ? 'Yıllık Lisans'
                  : 'Aylık Lisans';
            }
            planColor = Colors.green.shade700;
            planIcon = Icons.check_circle;
          } else if (lic.isLocked) {
            planText = 'Süresi Dolmuş';
            planColor = Colors.red.shade700;
            planIcon = Icons.cancel;
          } else {
            planText = 'Deneme Sürümü';
            planColor = Colors.orange.shade700;
            planIcon = Icons.hourglass_bottom;
          }

          final daysLeft = lic.trialDaysLeft;
          final String? countdownText;

          if (lic.isLicensed && lic.licenseExpiresAt != null) {
            final d = lic.licenseExpiresAt!;
            countdownText =
                '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
          } else if (lic.isTrial && daysLeft != null) {
            countdownText = daysLeft > 0 ? '$daysLeft gün kaldı' : 'Süre doldu';
          } else {
            countdownText = null;
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: planColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: planColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(planIcon, color: planColor, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            planText,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: planColor,
                            ),
                          ),
                          if (countdownText != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              lic.isLicensed
                                  ? 'Son kullanım: $countdownText'
                                  : countdownText,
                              style: TextStyle(
                                fontSize: 13,
                                color: planColor.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildHakkindaRow(
                Icons.category_outlined,
                'Plan',
                lic.tier == 'yearly'
                    ? 'Yıllık'
                    : lic.tier == 'monthly'
                    ? 'Aylık'
                    : 'Deneme',
              ),
              const Divider(height: 16),
              _buildHakkindaRow(
                Icons.assignment_outlined,
                'Durum',
                lic.isLicensed
                    ? 'Aktif'
                    : lic.isLocked
                    ? 'Kilitli'
                    : 'Deneme',
              ),
              if (lic.isOrgOwner && lic.orgId != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              TeamManagementScreen(orgId: lic.orgId!),
                        ),
                      );
                    },
                    icon: const Icon(Icons.groups_outlined, size: 18),
                    label: const Text('Ekibim'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
              if (!lic.isLicensed) ...[
                const Divider(height: 16),
                _buildHakkindaRow(
                  Icons.folder_outlined,
                  'Proje',
                  '${lic.projectCount} / 2 kullanıldı',
                ),
                const Divider(height: 16),
                _buildHakkindaRow(
                  Icons.picture_as_pdf_outlined,
                  'PDF',
                  '${lic.pdfProjects.length} proje için üretildi',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => const RedeemKeyScreen(),
                        ),
                      );
                      if (result == true) ref.invalidate(licenseProvider);
                    },
                    icon: const Icon(Icons.vpn_key, size: 18),
                    label: const Text('Lisans Anahtarı Gir'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => const RedeemCorporateKeyScreen(),
                        ),
                      );
                      if (result == true) ref.invalidate(licenseProvider);
                    },
                    icon: const Icon(Icons.business_center, size: 18),
                    label: const Text('Kurumsal Lisansım Var'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.indigo.shade600,
                      side: BorderSide(color: Colors.indigo.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                _PendingInvitesSection(
                  onJoined: () => ref.invalidate(licenseProvider),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // ── Hakkında ──────────────────────────────────────────────────────────────

  Widget _buildHakkindaSection() {
    return _buildCard(
      title: 'HAKKINDA',
      icon: Icons.info_outline,
      iconColor: Colors.teal.shade600,
      child: Column(
        children: [
          _buildHakkindaRow(Icons.computer, 'Yazılım', _yazilimAdi),
          const Divider(height: 16),
          _buildHakkindaRow(
            Icons.business,
            'Geliştirici',
            '$_ureticiFirma © $_copyrightYil',
          ),
          const Divider(height: 16),
          _buildHakkindaRow(Icons.email_outlined, 'E-posta', _ureticiFirmaMail),
          const Divider(height: 16),
          _buildHakkindaRow(Icons.phone_outlined, 'Telefon', _ureticiFirmaTel),
          const Divider(height: 16),
          _buildHakkindaRow(Icons.tag, 'Versiyon', _versiyon),
        ],
      ),
    );
  }

  // ── Yardımcı widget'lar ───────────────────────────────────────────────────

  Widget _buildLockedField({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade500),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Spacer(),
          Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade400),
        ],
      ),
    );
  }

  Widget _buildHakkindaRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F1F1F),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        isDense: true,
      ),
      style: const TextStyle(fontSize: 14),
    );
  }
}

// ── Telefon formatter ─────────────────────────────────────────────────────────

class _PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length > 10) return oldValue;

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 3 || i == 6 || i == 8) buffer.write(' ');
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ── Ayarları okumak için yardımcı sınıf ──────────────────────────────────────

class SettingsService {
  static const String _keyFirmaAdi = 'firma_adi';
  static const String _keyFirmaTel = 'firma_tel';
  static const String _keyFirmaAdres = 'firma_adres';
  static const String _keyFirmaEmail = 'firma_email';
  static const String _keyLogoPath = 'logo_path';

  static Future<FirmaSettings> loadFirmaSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return FirmaSettings(
      firmaAdi: prefs.getString(_keyFirmaAdi) ?? '',
      telefon: prefs.getString(_keyFirmaTel) ?? '',
      adres: prefs.getString(_keyFirmaAdres) ?? '',
      email: prefs.getString(_keyFirmaEmail) ?? '',
      logoPath: prefs.getString(_keyLogoPath),
    );
  }
}

class FirmaSettings {
  final String firmaAdi;
  final String telefon;
  final String adres;
  final String email;
  final String? logoPath;

  const FirmaSettings({
    required this.firmaAdi,
    required this.telefon,
    required this.adres,
    required this.email,
    this.logoPath,
  });
}

// ── Bekleyen kurumsal davetler ─────────────────────────────────────────────

class _PendingInvitesSection extends StatefulWidget {
  final VoidCallback onJoined;

  const _PendingInvitesSection({required this.onJoined});

  @override
  State<_PendingInvitesSection> createState() => _PendingInvitesSectionState();
}

class _PendingInvitesSectionState extends State<_PendingInvitesSection> {
  late Future<List<Map<String, dynamic>>> _invitesFuture;
  String? _joiningOrgId;

  @override
  void initState() {
    super.initState();
    _invitesFuture = LicenseService().findMyInvites();
  }

  Future<void> _join(String orgId) async {
    setState(() => _joiningOrgId = orgId);
    try {
      await LicenseService().acceptInvite(orgId: orgId);
      if (!mounted) return;
      widget.onJoined();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ekibe katıldınız! 🎉')));
    } on LicenseDeniedException catch (e) {
      if (!mounted) return;
      final message = switch (e.reason) {
        'seats_full' => 'Koltuk sınırına ulaşıldı, firma sahibine ulaşın.',
        'no_pending_invite' => 'Bu davet artık geçerli değil.',
        _ => 'Katılınamadı: ${e.reason}',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _joiningOrgId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _invitesFuture,
      builder: (context, snapshot) {
        final invites = snapshot.data;
        if (invites == null || invites.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: invites.map((invite) {
              final orgId = invite['orgId'] as String;
              final orgName = invite['orgName'] as String? ?? 'Bir firma';
              final isJoining = _joiningOrgId == orgId;

              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.indigo.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.mail_outline, color: Colors.indigo.shade600),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$orgName sizi kurumsal lisansa davet etti.',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: isJoining ? null : () => _join(orgId),
                      child: isJoining
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Katıl'),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
