// lib/presentation/pages/project_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/project.dart';
import '../../models/drawing.dart';
import '../../presentation/providers/drawing_provider.dart';
import '../../presentation/providers/project_provider.dart';
import '../drawing/drawing_management_page.dart';
import 'project_edit_page.dart';

class ProjectDetailPage extends ConsumerStatefulWidget {
  final Project project;

  const ProjectDetailPage({super.key, required this.project});

  @override
  ConsumerState<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends ConsumerState<ProjectDetailPage> {
  Project? _currentProject;

  @override
  void initState() {
    super.initState();
    _currentProject = widget.project;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshProjectData();
    });
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
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteProject,
            tooltip: 'Projeyi Sil',
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
        ],
      ),
    );
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
