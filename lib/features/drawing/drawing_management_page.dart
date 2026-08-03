import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/drawing_provider.dart';
import '../../models/drawing.dart';
import 'drawing_canvas_page.dart';
import '../../shared/dialogs/room_dialog.dart';
import '../../services/pdf_service.dart';
import '../../features/settings/settings_page.dart';
import '../../models/project.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/license_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DrawingManagementPage extends ConsumerStatefulWidget {
  final String projectId;
  final String customerName;
  final String customerPhone; // ← ekle
  final String customerAddress; // ← ekle

  const DrawingManagementPage({
    super.key,
    required this.projectId,
    required this.customerName,
    this.customerPhone = '', // ← ekle
    this.customerAddress = '', // ← ekle
  });

  @override
  ConsumerState<DrawingManagementPage> createState() =>
      _DrawingManagementPageState();
}

class _DrawingManagementPageState extends ConsumerState<DrawingManagementPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isDataLoaded = false;
  // YENİ
  final Set<String> _selectedDrawingIds = {};
  bool _isPdfGenerating = false;
  String? _lastPdfPath;
  List<FileSystemEntity> _savedPdfs = [];

  @override
  void initState() {
    super.initState();

    // 🚨 YENİ: Sayfa açılışında cache temizle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(drawingProvider(widget.projectId).notifier).clearCache();
      _preloadDrawingData();
      _loadSavedPdfs();
    });
  }

  void _initializeData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadDrawingData();
    });
  }

  Future<void> _loadSavedPdfs() async {
    final prefs = await SharedPreferences.getInstance();
    final paths = prefs.getStringList('saved_pdfs') ?? [];
    final existing = paths.where((p) => File(p).existsSync()).toList();
    await prefs.setStringList('saved_pdfs', existing);
    setState(
      () => _savedPdfs = existing
          .map((p) => File(p) as FileSystemEntity)
          .toList(),
    );
  }

  Future<void> _showSavedPdfs() async {
    await _loadSavedPdfs();
    if (!mounted) return;

    // Listeyi bottom sheet açılmadan ÖNCE kopyala
    final pdfs = _savedPdfs.map((e) => File((e as File).path)).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(
                      Icons.picture_as_pdf,
                      color: Colors.red.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Kaydedilen PDF\'ler',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (pdfs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'Henüz PDF oluşturulmadı',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: pdfs.length,
                      itemBuilder: (ctx, index) {
                        final file = pdfs[index];
                        final fileName = file.path.split('/').last;
                        final modified = file.existsSync()
                            ? file.statSync().modified
                            : DateTime.now();
                        final dateStr =
                            '${modified.day.toString().padLeft(2, '0')}.${modified.month.toString().padLeft(2, '0')}.${modified.year}';

                        return Column(
                          children: [
                            if (index > 0)
                              Divider(height: 1, color: Colors.grey.shade200),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.picture_as_pdf,
                                    color: Colors.red.shade400,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          fileName,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          dateStr,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.share,
                                      size: 20,
                                      color: Colors.blue.shade600,
                                    ),
                                    onPressed: () => _sharePdf(file.path),
                                    tooltip: 'Paylaş',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      size: 20,
                                      color: Colors.red.shade400,
                                    ),
                                    onPressed: () async {
                                      final filePath = file.path;

                                      // 1. Diskten sil
                                      if (file.existsSync()) {
                                        await file.delete();
                                      }

                                      // 2. SharedPreferences'tan bu TEK yolu sil
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      final paths =
                                          prefs.getStringList('saved_pdfs') ??
                                          [];
                                      // Sadece ilk eşleşeni kaldır (aynı isim varsa)
                                      final idx = paths.indexOf(filePath);
                                      if (idx != -1) {
                                        paths.removeAt(idx);
                                      }
                                      await prefs.setStringList(
                                        'saved_pdfs',
                                        paths,
                                      );

                                      // 3. Bottom sheet listesini güncelle
                                      setSheetState(() {
                                        pdfs.removeAt(index);
                                      });

                                      // 4. Ana sayfa badge'ini güncelle
                                      _loadSavedPdfs();
                                    },
                                    tooltip: 'Sil',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _preloadDrawingData() {
    try {
      ref.read(drawingProvider(widget.projectId).notifier).loadDrawings();
      _isDataLoaded = true;
    } catch (e) {
      // Hata sessizce yakalandı
    }
  }

  Future<void> _startNewDrawing() async {
    final newDrawing = Drawing(
      id: 'DRAW_${DateTime.now().millisecondsSinceEpoch}',
      projectId: widget.projectId,
      name:
          'Çizim ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
      createdAt: DateTime.now().toString(),
      location: null,
      direction: null,
      height: null,
      width: null,
      roomDescription: null,
    );

    showDialog(
      context: context,
      builder: (context) => RoomDialog(drawing: newDrawing),
    ).then((updatedDrawing) async {
      if (updatedDrawing != null && updatedDrawing is Drawing) {
        ref.read(drawingProvider(widget.projectId).notifier).clearCache();
        await ref
            .read(drawingProvider(widget.projectId).notifier)
            .addDrawing(updatedDrawing);
        await Future.delayed(Duration(milliseconds: 300));
        setState(() {});
      }
    });
  }

  void _navigateToDrawingCanvas(Drawing drawing) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DrawingCanvasPage(
          projectId: widget.projectId,
          drawingId: drawing.id,
          customerName: widget.customerName,
        ),
      ),
    );
  }

  void _deleteDrawing(String drawingId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çizimi Sil'),
        content: const Text('Bu çizimi silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(drawingProvider(widget.projectId).notifier)
                  .deleteDrawing(drawingId);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _refreshDrawings() {
    ref.read(drawingProvider(widget.projectId).notifier).loadDrawings();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.architecture_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(
            'Henüz Çizim Yok',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Text(
            'Yeni bir çizim başlatmak için + butonuna tıklayın',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _startNewDrawing,
            icon: const Icon(Icons.add),
            label: const Text('İlk Çizimi Oluştur'),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawingItem(Drawing drawing, int index) {
    final date = DateTime.parse(drawing.createdAt);
    final formattedDate =
        '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    final displayTitle = drawing.name;

    return Card(
      margin: EdgeInsets.fromLTRB(16, index == 0 ? 16 : 8, 16, 8),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: _selectedDrawingIds.contains(drawing.id),
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedDrawingIds.add(drawing.id);
                  } else {
                    _selectedDrawingIds.remove(drawing.id);
                  }
                });
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.architecture, color: Colors.amber[700]),
            ),
          ],
        ),
        // 🚨 YENİ: Konum başlık olarak
        title: Tooltip(
          message: drawing.name, // 🚨 Tam metin
          child: Text(
            drawing.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Yön (üstte)
            if (drawing.direction != null) ...[
              Text(drawing.direction!, style: TextStyle(fontSize: 13)),
              const SizedBox(height: 2),
            ],
            // Tarih (altta) - saatli
            Text(
              formattedDate,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (drawing.shapes.isNotEmpty) ...[
              const SizedBox(height: 4),
              _buildPriceRow(drawing),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'delete') {
              _deleteDrawing(drawing.id);
            } else if (value == 'open') {
              _navigateToDrawingCanvas(drawing);
            } else if (value == 'description') {
              _showDescription(drawing); // Yeni fonksiyon
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'open',
              child: Row(
                children: [
                  Icon(Icons.open_in_new, size: 20),
                  SizedBox(width: 8),
                  Text('Aç'),
                ],
              ),
            ),
            // Açıklama varsa göster
            if (drawing.roomDescription?.isNotEmpty == true)
              const PopupMenuItem(
                value: 'description',
                child: Row(
                  children: [
                    Icon(Icons.description, size: 20, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Açıklama', style: TextStyle(color: Colors.blue)),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Sil', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _navigateToDrawingCanvas(drawing),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildPriceRow(Drawing drawing) {
    double total = 0;
    final chips = <String>[];

    for (int i = 0; i < drawing.shapes.length; i++) {
      final price = drawing.shapes[i].price;
      if (price != null && price > 0) {
        total += price;
        chips.add('P${i + 1}: ₺${price.toStringAsFixed(0)}');
      }
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: Text(
            chips.join('  '),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '₺${total.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.green.shade700,
          ),
        ),
      ],
    );
  }

  void _showDescription(Drawing drawing) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Açıklama'),
        content: Text(drawing.roomDescription ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  // 🎨 YENİ: Minimal Üst Bilgi Satırı (Başlıksız)
  Widget _buildInfoHeader(int drawingCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(bottom: BorderSide(color: Colors.blue[100]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Sol: Çizim sayısı
          Row(
            children: [
              Icon(Icons.architecture, size: 16, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                '$drawingCount çizim',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),

          // // Sağ: Yenile butonu
          // IconButton(
          //   icon: Icon(Icons.refresh, size: 20, color: Colors.blue[700]),
          //   onPressed: _refreshDrawings,
          //   tooltip: 'Yenile',
          //   padding: EdgeInsets.zero,
          //   constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          // ),
        ],
      ),
    );
  }

  Widget _buildTotalBar(List<Drawing> drawings) {
    double total = 0;
    for (final drawing in drawings) {
      for (final shape in drawing.shapes) {
        if (shape.price != null) total += shape.price!;
      }
    }

    final allSelected =
        drawings.isNotEmpty &&
        drawings.every((d) => _selectedDrawingIds.contains(d.id));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // PDF butonu
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                // Tümünü seç
                Row(
                  children: [
                    Checkbox(
                      value: allSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedDrawingIds.addAll(
                              drawings.map((d) => d.id),
                            );
                          } else {
                            _selectedDrawingIds.clear();
                          }
                        });
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    Text(
                      'Tümü',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                // PDF butonu
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectedDrawingIds.isEmpty || _isPdfGenerating
                        ? null
                        : () => _generatePdf(drawings),
                    icon: _isPdfGenerating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.picture_as_pdf, size: 16),
                    label: Text(
                      _isPdfGenerating
                          ? 'Oluşturuluyor...'
                          : _selectedDrawingIds.isEmpty
                          ? 'PDF Oluştur'
                          : '${_selectedDrawingIds.length} çizim PDF',
                      style: const TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Toplam satırı
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${drawings.length} çizim',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                Row(
                  children: [
                    Text(
                      'Toplam: ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      '₺${total.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePdf(List<Drawing> drawings) async {
    final selectedDrawings = drawings
        .where((d) => _selectedDrawingIds.contains(d.id))
        .toList();
    if (selectedDrawings.isEmpty) return;

    setState(() => _isPdfGenerating = true);

    try {
      final firmaSettings = await SettingsService.loadFirmaSettings();
      final authUser = FirebaseAuth.instance.currentUser;
      final firma = FirmaInfo(
        firmaAdi: firmaSettings.firmaAdi.isEmpty
            ? 'Firma Adı'
            : firmaSettings.firmaAdi,
        telefon: firmaSettings.telefon,
        adres: firmaSettings.adres,
        logoPath: firmaSettings.logoPath,
        email: firmaSettings.email,
      );

      // Geçici proje nesnesi — sadece PDF için
      final tempProject = Project(
        id: '',
        name: widget.customerName,
        phone: widget.customerPhone, // ← düzelt
        address: widget.customerAddress, // ← düzelt
        description: '',
        createdAt: DateTime.now().toIso8601String(),
      );
      await LicenseService().requestGeneratePdf(widget.projectId);
      final path = await PdfService.generateProjectPdf(
        project: tempProject,
        drawings: selectedDrawings,
        firma: firma,
      );

      setState(() {
        _isPdfGenerating = false;
        _lastPdfPath = path;
      });
      await _loadSavedPdfs();
    } catch (e) {
      setState(() => _isPdfGenerating = false);
      if (!mounted) return;

      if (e is LicenseDeniedException) {
        final mesaj = e.reason == 'pdf_already_used'
            ? 'Bu proje için PDF hakkınızı kullandınız. Sınırsız PDF için lisans alın. (Mevcut PDF\'i paylaşmaya devam edebilirsiniz.)'
            : e.reason == 'trial_expired'
            ? 'Deneme süreniz doldu. Devam etmek için lisans alın.'
            : 'Bu işlem için lisans gerekiyor.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mesaj),
            backgroundColor: Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      if (e is LicenseOfflineException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'PDF oluşturmak için internet bağlantısı gerekiyor.',
            ),
            backgroundColor: Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      // Lisans dışı gerçek hatalar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF hatası: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _sharePdf(String path) async {
    final file = XFile(path);
    await Share.shareXFiles([
      file,
    ], subject: '${widget.customerName} - Pencere Teknik Ölçü Formu');
  }

  Widget _buildDrawingList(List<Drawing> drawings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🎨 YENİ: Minimal üst bilgi (Başlık yok!)
        _buildInfoHeader(drawings.length),

        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              _refreshDrawings();
            },
            child: ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: drawings.length,
              itemBuilder: (context, index) {
                return _buildDrawingItem(drawings[index], index);
              },
            ),
          ),
        ),
        SafeArea(top: false, child: _buildTotalBar(drawings)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final drawingsState = ref.watch(drawingProvider(widget.projectId));

    return Scaffold(
      appBar: AppBar(
        // 🎨 Sadece AppBar başlığı, zaten proje adı burada
        title: Text(widget.customerName), // Proje adını başlık yapıyoruz
        centerTitle: false,
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _savedPdfs.isNotEmpty,
              label: Text('${_savedPdfs.length}'),
              child: const Icon(Icons.picture_as_pdf),
            ),
            onPressed: _showSavedPdfs,
            tooltip: 'Kaydedilen PDF\'ler',
          ),
          if (_lastPdfPath != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _sharePdf(_lastPdfPath!),
              tooltip: 'Son PDF\'i Paylaş',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshDrawings,
            tooltip: 'Çizimleri Yenile',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _startNewDrawing,
            tooltip: 'Yeni Çizim',
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildBodyContent(drawingsState),
      ),
    );
  }

  Widget _buildBodyContent(List<Drawing> drawings) {
    if (drawings.isEmpty) {
      return _buildEmptyState();
    }

    return _buildDrawingList(drawings);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
