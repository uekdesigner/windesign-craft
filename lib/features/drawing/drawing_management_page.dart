// lib/presentation/pages/drawing_management_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/drawing_provider.dart';
import '../../models/drawing.dart';
import 'drawing_canvas_page.dart';
import '../../shared/dialogs/room_dialog.dart';

class DrawingManagementPage extends ConsumerStatefulWidget {
  final String projectId;
  final String customerName;

  const DrawingManagementPage({
    super.key,
    required this.projectId,
    required this.customerName,
  });

  @override
  ConsumerState<DrawingManagementPage> createState() =>
      _DrawingManagementPageState();
}

class _DrawingManagementPageState extends ConsumerState<DrawingManagementPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isDataLoaded = false;

  @override
  void initState() {
    super.initState();

    // 🚨 YENİ: Sayfa açılışında cache temizle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(drawingProvider(widget.projectId).notifier).clearCache();
      _preloadDrawingData();
    });
  }

  void _initializeData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadDrawingData();
    });
  }

  void _preloadDrawingData() {
    try {
      ref.read(drawingProvider(widget.projectId).notifier).loadDrawings();
      _isDataLoaded = true;
    } catch (e) {
      // Hata sessizce yakalandı
    }
  }

  void _startNewDrawing() {
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
        // 🚨 YENİ: Manuel yenileme
        // 🚨 YENİ: Sayfayı yenile
        await Future.delayed(Duration(milliseconds: 300));
        setState(() {}); // Force rebuild

        // _navigateToDrawingCanvas(updatedDrawing);
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

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Çizim silindi'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Çizimler yenilendi'),
        duration: Duration(seconds: 1),
      ),
    );
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
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.amber[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.architecture, color: Colors.amber[700]),
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
            icon: const Icon(Icons.refresh),
            onPressed: _refreshDrawings,
            tooltip: 'Çizimleri Yenile',
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildBodyContent(drawingsState),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startNewDrawing,
        child: const Icon(Icons.add),
        tooltip: 'Yeni Çizim',
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
