import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/shape_spec.dart';
import '../../../models/window_system.dart';
import '../../../services/database.dart';
import '../../../services/database_provider.dart';
import '../../../services/window_system_service.dart';
import '../providers/drawing_controller_provider.dart';
import '../../../services/metretul_calculator.dart';

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return '${word[0].toUpperCase()}${word.substring(1)}';
        })
        .join(' ');
  }
}

class SystemBottomPanel extends ConsumerStatefulWidget {
  final String projectId;
  final String drawingId;
  final bool isVisible;
  final bool hasDrawingTableHandle;
  final bool isDrawingOpen;
  final double drawingHandleBottom;
  final VoidCallback onToggle;
  final void Function(bool)? onOpenChanged;
  final void Function(double)? onHeightChanged;

  const SystemBottomPanel({
    super.key,
    required this.projectId,
    required this.drawingId,
    required this.isVisible,
    this.hasDrawingTableHandle = false,
    this.isDrawingOpen = false,
    this.drawingHandleBottom = 0,
    required this.onToggle,
    this.onOpenChanged,
    this.onHeightChanged,
  });

  @override
  ConsumerState<SystemBottomPanel> createState() => _SystemBottomPanelState();
}

class _SystemBottomPanelState extends ConsumerState<SystemBottomPanel> {
  bool _isOpen = false;
  bool _isAccessoryDropdownOpen = false;

  List<WindowSystem> _systems = [];
  WindowSystem? _selectedSystem;
  WindowSeries? _selectedSeries;
  String? _selectedColor;

  List<Map<String, dynamic>> _glassSystems = [];
  List<Map<String, dynamic>> _glassTones = [];
  List<Map<String, dynamic>> _accessories = [];
  int? _selectedGlassSystemId;
  int? _selectedGlassToneId;
  List<int> _selectedAccessoryIds = [];

  bool _isSaved = false;
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  final GlobalKey _panelKey = GlobalKey();
  double _panelHeight = 0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void didUpdateWidget(covariant SystemBottomPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Çizim paneli açılınca sistem panelini kapat
    if (widget.isDrawingOpen && !oldWidget.isDrawingOpen && _isOpen) {
      setState(() => _isOpen = false);
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await _loadSystems();
    await _loadGlassData();
    await _loadAccessories();
    if (mounted) await _loadDrawingSpecs();
    if (mounted) {
      final controllerState = ref.read(
        drawingControllerProvider((
          projectId: widget.projectId,
          drawingId: widget.drawingId,
        )),
      );
      _loadShapeSpecs(controllerState.currentShape);
    }
  }

  Future<void> _loadSystems() async {
    final db = await ref.read(databaseProvider.future);
    final repo = WindowSystemRepository(db);
    final systems = await repo.getAll();

    if (mounted) {
      setState(() {
        _systems = systems;

        if (_selectedSystem != null) {
          final foundSystem = systems.cast<WindowSystem?>().firstWhere(
            (s) => s?.id == _selectedSystem!.id,
            orElse: () => null,
          );

          if (foundSystem != null) {
            _selectedSystem = foundSystem;

            if (_selectedSeries != null) {
              final foundSeries = _selectedSystem!.series
                  .cast<WindowSeries?>()
                  .firstWhere(
                    (ser) => ser?.id == _selectedSeries!.id,
                    orElse: () => null,
                  );

              if (foundSeries != null) {
                _selectedSeries = foundSeries;
                final colorExists = _selectedSeries!.colors.any(
                  (c) => c.name == _selectedColor,
                );
                if (!colorExists) _selectedColor = null;
              } else {
                _selectedSeries = null;
                _selectedColor = null;
              }
            }
          } else {
            _selectedSystem = null;
            _selectedSeries = null;
            _selectedColor = null;
          }
        }
      });
    }
  }

  Future<void> _loadGlassData() async {
    final db = await LocalDatabase().database;
    final repo = WindowSystemRepository(db);
    final systems = await repo.getAllGlassSystems();
    final tones = await repo.getAllGlassTones();

    if (mounted) {
      setState(() {
        _glassSystems = systems;
        _glassTones = tones;
      });
    }
  }

  Future<void> _loadAccessories() async {
    final db = await LocalDatabase().database;
    final repo = WindowSystemRepository(db);
    final accessories = await repo.getAllAccessories();

    if (mounted) {
      setState(() {
        _accessories = accessories;
      });
    }
  }

  Future<void> _loadDrawingSpecs() async {
    final db = await LocalDatabase().database;
    final drawing = await db.query(
      'drawings',
      where: 'id = ?',
      whereArgs: [widget.drawingId],
      limit: 1,
    );

    if (drawing.isNotEmpty && mounted) {
      final data = drawing.first;
      setState(() {
        final sysName = data['system_name'] as String?;
        if (sysName != null) {
          _selectedSystem = _systems.cast<WindowSystem?>().firstWhere(
            (s) => s?.name == sysName,
            orElse: () => null,
          );
        } else {
          _selectedSystem = null;
        }

        final serName = data['series_name'] as String?;
        if (serName != null && _selectedSystem != null) {
          _selectedSeries = _selectedSystem!.series
              .cast<WindowSeries?>()
              .firstWhere((s) => s?.name == serName, orElse: () => null);
        } else {
          _selectedSeries = null;
        }

        final colorName = data['profile_color'] as String?;
        if (colorName != null &&
            _selectedSeries != null &&
            _selectedSeries!.colors.any((c) => c.name == colorName)) {
          _selectedColor = colorName;
        } else {
          _selectedColor = null;
        }

        final gsName = data['glass_system'] as String?;
        if (gsName != null && _selectedColor != null) {
          _selectedGlassSystemId =
              _glassSystems.cast<Map<String, dynamic>?>().firstWhere(
                    (s) => s?['name'] == gsName,
                    orElse: () => null,
                  )?['id']
                  as int?;
        } else {
          _selectedGlassSystemId = null;
        }

        final gtName = data['glass_tone'] as String?;
        if (gtName != null && _selectedGlassSystemId != null) {
          _selectedGlassToneId =
              _glassTones.cast<Map<String, dynamic>?>().firstWhere(
                    (t) => t?['name'] == gtName,
                    orElse: () => null,
                  )?['id']
                  as int?;
        } else {
          _selectedGlassToneId = null;
        }

        _descriptionController.text = data['description'] as String? ?? '';
      });
    }
  }

  void _loadShapeSpecs(ShapeSpec? shape) {
    if (shape == null) {
      setState(() {
        _selectedSystem = null;
        _selectedSeries = null;
        _selectedColor = null;
        _selectedGlassSystemId = null;
        _selectedGlassToneId = null;
        _selectedAccessoryIds = [];
        _descriptionController.clear();
      });
      return;
    }

    setState(() {
      if (shape.systemName != null) {
        _selectedSystem = _systems.cast<WindowSystem?>().firstWhere(
          (s) => s?.name == shape.systemName,
          orElse: () => null,
        );
      } else {
        _selectedSystem = null;
      }

      if (shape.seriesName != null && _selectedSystem != null) {
        _selectedSeries = _selectedSystem!.series
            .cast<WindowSeries?>()
            .firstWhere((s) => s?.name == shape.seriesName, orElse: () => null);
      } else {
        _selectedSeries = null;
      }

      final colorName = shape.profileColor;
      if (colorName != null &&
          _selectedSeries != null &&
          _selectedSeries!.colors.any((c) => c.name == colorName)) {
        _selectedColor = colorName;
      } else {
        _selectedColor = null;
      }

      final gsName = shape.glassSystem;
      if (gsName != null && _selectedColor != null) {
        _selectedGlassSystemId =
            _glassSystems.cast<Map<String, dynamic>?>().firstWhere(
                  (s) => s?['name'] == gsName,
                  orElse: () => null,
                )?['id']
                as int?;
      } else {
        _selectedGlassSystemId = null;
      }

      final gtName = shape.glassTone;
      if (gtName != null && _selectedGlassSystemId != null) {
        _selectedGlassToneId =
            _glassTones.cast<Map<String, dynamic>?>().firstWhere(
                  (t) => t?['name'] == gtName,
                  orElse: () => null,
                )?['id']
                as int?;
      } else {
        _selectedGlassToneId = null;
      }

      _selectedAccessoryIds = shape.accessories.isNotEmpty
          ? _accessories
                .where((a) => shape.accessories.contains(a['name'] as String))
                .map((a) => a['id'] as int)
                .toList()
          : [];
      _descriptionController.text = shape.description ?? '';
      _priceController.text = shape.price != null
          ? shape.price!.toStringAsFixed(2)
          : '';
      _locationController.text = shape.location ?? '';
      _isSaved =
          shape.systemName != null ||
          (shape.description?.isNotEmpty ?? false) ||
          (shape.location?.isNotEmpty ?? false);
    });
  }

  Future<void> _saveShapeSpecs() async {
    final controllerState = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )),
    );
    final controller = ref.read(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )).notifier,
    );
    final shape = controllerState.currentShape;
    if (shape == null) return;

    final gsName = _selectedGlassSystemId != null
        ? (_glassSystems.firstWhere(
                (s) => s['id'] == _selectedGlassSystemId,
                orElse: () => {'name': ''},
              )['name']
              as String)
        : null;
    final gtName = _selectedGlassToneId != null
        ? (_glassTones.firstWhere(
                (t) => t['id'] == _selectedGlassToneId,
                orElse: () => {'name': ''},
              )['name']
              as String)
        : null;

    final aksesaurAdlari = _selectedAccessoryIds
        .map((id) {
          final acc = _accessories.firstWhere(
            (a) => a['id'] == id,
            orElse: () => {'name': ''},
          );
          return acc['name'] as String;
        })
        .where((n) => n.isNotEmpty)
        .toList();

    final updated = shape.copyWith(
      systemName: _selectedSystem?.name,
      seriesName: _selectedSeries?.name,
      profileColor: _selectedColor,
      glassSystem: gsName,
      glassTone: gtName,
      location: _locationController.text.trim(),
      description: _descriptionController.text.trim(),
      price: double.tryParse(_priceController.text.trim().replaceAll(',', '.')),
      accessories: aksesaurAdlari,
    );

    controller.updateShape(controllerState.selectedIndex, updated);
    setState(() => _isSaved = true);
  }

  // ==================== DİYALOGLAR ====================

  void _showAddSystemDialog() {
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Sistem Ekle', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                hintText: 'Sistem Türü Ekle',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim().capitalize();
              if (name.isEmpty) return;

              final exists = _systems.any(
                (s) => s.name.toLowerCase() == name.toLowerCase(),
              );
              if (exists) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Bu sistem zaten mevcut')),
                );
                return;
              }

              final db = await LocalDatabase().database;
              final repo = WindowSystemRepository(db);
              await repo.addSystem(name);

              await _loadSystems();
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSystem(WindowSystem system) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sistem Sil'),
        content: Text(
          '"${system.name}" silinsin mi?\nAltındaki tüm seri ve renkler de silinecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final db = await LocalDatabase().database;
              final repo = WindowSystemRepository(db);
              await repo.deleteSystem(system.id!);
              if (_selectedSystem?.id == system.id) {
                setState(() {
                  _selectedSystem = null;
                  _selectedSeries = null;
                  _selectedColor = null;
                });
              }
              await _loadSystems();
              if (mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetretulInfo(ShapeSpec shape) {
    final result = MetretulCalculator.calculateForShape(shape);
    if (result.toplamMm <= 0) return const SizedBox.shrink();

    final fireM = result.toplamM * 0.10;
    final genelToplamM = result.toplamM + fireM;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ortalama Metretül',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Kasa: ${result.sabitIskeletM.toStringAsFixed(2)} m',
              style: const TextStyle(fontSize: 12, color: Color(0xFF1F1F1F)),
            ),
            if (result.kanatMm > 0) ...[
              const SizedBox(height: 2),
              Text(
                'Kanat: ${result.kanatM.toStringAsFixed(2)} m'
                ' (${result.kanatSayisi} adet)',
                style: const TextStyle(fontSize: 12, color: Color(0xFF1F1F1F)),
              ),
            ],
            const SizedBox(height: 2),
            Text(
              'Toplam: ${result.toplamM.toStringAsFixed(2)} m',
              style: const TextStyle(fontSize: 12, color: Color(0xFF1F1F1F)),
            ),
            const SizedBox(height: 2),
            Text(
              'Fire (%10): ${fireM.toStringAsFixed(2)} m',
              style: const TextStyle(fontSize: 12, color: Color(0xFF1F1F1F)),
            ),
            const SizedBox(height: 3),
            Text(
              'Genel Toplam: ${genelToplamM.toStringAsFixed(2)} m',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F1F1F),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedView() {
    final gsName = _selectedGlassSystemId != null
        ? (_glassSystems.firstWhere(
                    (s) => s['id'] == _selectedGlassSystemId,
                    orElse: () => {'name': ''},
                  )['name']
                  as String)
              .capitalize()
        : null;
    final gtName = _selectedGlassToneId != null
        ? (_glassTones.firstWhere(
                    (t) => t['id'] == _selectedGlassToneId,
                    orElse: () => {'name': ''},
                  )['name']
                  as String)
              .capitalize()
        : null;

    final accessoryNames = _selectedAccessoryIds
        .map((id) {
          final acc = _accessories.firstWhere(
            (a) => a['id'] == id,
            orElse: () => {'name': '?'},
          );
          return (acc['name'] as String).capitalize();
        })
        .join(', ');

    final rows = <MapEntry<String, String?>>[
      MapEntry('Sistem Türü', _selectedSystem?.name),
      MapEntry('Seri', _selectedSeries?.name.capitalize()),
      MapEntry('Profil Rengi', _selectedColor?.capitalize()),
      MapEntry('Cam Sistemi', gsName),
      MapEntry('Cam Tonu', gtName),
      if (accessoryNames.isNotEmpty) MapEntry('Aksesuar', accessoryNames),
    ].where((e) => e.value != null && e.value!.isNotEmpty).toList();

    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Seçim yapılmadı',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 232, 245, 253),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color.fromARGB(255, 110, 178, 247)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows
            .map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        '${e.key}:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.value!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F1F1F),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  void _showAddSeriesDialog() {
    if (_selectedSystem == null) return;
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Seri Ekle', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                hintText: "Örn: 90'lık Seri",
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
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
              final name = nameCtrl.text.trim().capitalize();
              if (name.isEmpty) return;

              final exists = _selectedSystem!.series.any(
                (s) => s.name.toLowerCase() == name.toLowerCase(),
              );
              if (exists) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Bu seri zaten mevcut')),
                );
                return;
              }

              final db = await LocalDatabase().database;
              final repo = WindowSystemRepository(db);
              await repo.addSeries(_selectedSystem!.id!, name);
              await _loadSystems();
              setState(() {
                _selectedSeries = null;
                _selectedColor = null;
              });
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSeries(WindowSeries series) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seri Sil', style: TextStyle(fontSize: 16)),
        content: Text(
          '"${series.name}" serisini ve altındaki tüm renkleri silmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final db = await LocalDatabase().database;
              final repo = WindowSystemRepository(db);
              await repo.deleteSeries(series.id!);
              await _loadSystems();
              setState(() {
                _selectedSeries = null;
                _selectedColor = null;
              });
              if (mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _showAddColorDialog() {
    if (_selectedSeries == null) return;
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Renk Ekle', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                hintText: 'Örn: Füme',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
            const SizedBox(height: 12),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim().toLowerCase();
              if (name.isEmpty) return;

              final exists = _selectedSeries!.colors.any(
                (c) => c.name.toLowerCase() == name,
              );
              if (exists) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Bu renk zaten mevcut')),
                );
                return;
              }

              final db = await LocalDatabase().database;
              final repo = WindowSystemRepository(db);
              await repo.addColor(_selectedSeries!.id!, name);

              await _loadSystems();
              setState(() {
                _selectedColor = null;
              });

              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteColor() {
    if (_selectedSeries == null || _selectedColor == null) return;

    final colorToDelete = _selectedSeries!.colors.firstWhere(
      (c) => c.name == _selectedColor,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renk Sil', style: TextStyle(fontSize: 16)),
        content: Text(
          '"${colorToDelete.name.capitalize()}" rengini silmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final db = await LocalDatabase().database;
              final repo = WindowSystemRepository(db);
              await repo.deleteColor(colorToDelete.id!);
              await _loadSystems();
              setState(() {
                _selectedColor = null;
              });
              if (mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _showAddGlassSystemDialog() {
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Yeni Cam Sistemi Ekle',
          style: TextStyle(fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                hintText: 'Örn: Isıcam',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
            const SizedBox(height: 12),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim().capitalize();
              if (name.isEmpty) return;

              final exists = _glassSystems.any(
                (s) =>
                    (s['name'] as String).toLowerCase() == name.toLowerCase(),
              );
              if (exists) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Bu cam sistemi zaten mevcut')),
                );
                return;
              }
              final db = await LocalDatabase().database;
              final repo = WindowSystemRepository(db);
              await repo.addGlassSystem(name);

              await _loadGlassData();
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGlassSystem(Map<String, dynamic> system) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cam Sistemi Sil', style: TextStyle(fontSize: 16)),
        content: Text('"${system['name']}" silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final db = await LocalDatabase().database;
              final repo = WindowSystemRepository(db);
              await repo.deleteGlassSystem(system['id'] as int);
              await _loadGlassData();
              setState(() => _selectedGlassSystemId = null);
              if (mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _showAddGlassToneDialog() {
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Cam Tonu Ekle', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                hintText: 'Örn: Füme',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
            const SizedBox(height: 12),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim().capitalize();
              if (name.isEmpty) return;

              final exists = _glassTones.any(
                (t) =>
                    (t['name'] as String).toLowerCase() == name.toLowerCase(),
              );
              if (exists) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Bu cam tonu zaten mevcut')),
                );
                return;
              }
              final db = await LocalDatabase().database;
              final repo = WindowSystemRepository(db);
              await repo.addGlassTone(name);

              await _loadGlassData();
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGlassTone(Map<String, dynamic> tone) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cam Tonu Sil', style: TextStyle(fontSize: 16)),
        content: Text('"${tone['name']}" silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final db = await LocalDatabase().database;
              final repo = WindowSystemRepository(db);
              await repo.deleteGlassTone(tone['id'] as int);
              await _loadGlassData();
              setState(() => _selectedGlassToneId = null);
              if (mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _showAddAccessoryDialog() {
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Aksesuar Ekle', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                hintText: 'Örn: Sineklik',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
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
              final name = nameCtrl.text.trim().capitalize();
              if (name.isEmpty) return;

              final exists = _accessories.any(
                (a) =>
                    (a['name'] as String).toLowerCase() == name.toLowerCase(),
              );
              if (exists) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Bu aksesuar zaten mevcut')),
                );
                return;
              }

              final db = await LocalDatabase().database;
              final repo = WindowSystemRepository(db);
              await repo.addAccessory(name);

              await _loadAccessories();
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSelectedAccessories() {
    if (_selectedAccessoryIds.isEmpty) return;

    final names = _selectedAccessoryIds
        .map((id) {
          final acc = _accessories.firstWhere(
            (a) => a['id'] == id,
            orElse: () => {'name': '?'},
          );
          return acc['name'] as String;
        })
        .join(', ');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aksesuarları Sil', style: TextStyle(fontSize: 16)),
        content: Text('Seçili aksesuarları silmek istiyor musunuz?\n\n$names'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final db = await LocalDatabase().database;
              final repo = WindowSystemRepository(db);
              for (final id in _selectedAccessoryIds) {
                await repo.deleteAccessory(id);
              }
              await _loadAccessories();
              setState(() => _selectedAccessoryIds.clear());
              if (mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  // ==================== UI BİLEŞENLERİ ====================

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _panelKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && mounted) {
        final h = box.size.height;
        if (h != _panelHeight) {
          setState(() => _panelHeight = h);
          widget.onHeightChanged?.call(h);
        }
      }
    });

    ref.listen(
      drawingControllerProvider((
        projectId: widget.projectId,
        drawingId: widget.drawingId,
      )),
      (previous, next) {
        if (previous?.selectedIndex != next.selectedIndex) {
          _loadShapeSpecs(next.currentShape);
        }
      },
    );
    final screenHeight = MediaQuery.of(context).size.height;
    final openHeight = screenHeight * 0.80;
    const double systemHandleWidth = 140;
    const double handleHeight = 36;

    return Visibility(
      visible: widget.isVisible,
      child: Stack(
        children: [
          if (_isOpen)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom,
              child: ConstrainedBox(
                key: _panelKey,
                constraints: BoxConstraints(
                  maxHeight:
                      openHeight - MediaQuery.of(context).viewInsets.bottom,
                ),
                child: IntrinsicHeight(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade400),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Kayıtlı görünüm veya düzenleme görünümü ──
                            if (!_isSaved) ...[
                              _buildMiniDropdownRow(
                                dropdown: DropdownButtonFormField<WindowSystem>(
                                  initialValue: _selectedSystem,
                                  isExpanded: true,
                                  decoration: _miniInputDecoration(
                                    'Sistem Türü',
                                  ),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 22,
                                    color: Color.fromARGB(255, 110, 178, 247),
                                  ),
                                  dropdownColor: Colors.white,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF333333),
                                  ),
                                  items: _systems.map((system) {
                                    return DropdownMenuItem<WindowSystem>(
                                      value: system,
                                      child: Text(
                                        system.name,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) => setState(() {
                                    _selectedSystem = val;
                                    _selectedSeries = null;
                                    _selectedColor = null;
                                  }),
                                ),
                                onAdd: _showAddSystemDialog,
                                onDelete: () =>
                                    _confirmDeleteSystem(_selectedSystem!),
                                isDeleteActive: _selectedSystem != null,
                              ),
                              const SizedBox(height: 8),
                              _buildMiniDropdownRow(
                                dropdown: DropdownButtonFormField<WindowSeries>(
                                  initialValue: _selectedSeries,
                                  isExpanded: true,
                                  decoration: _miniInputDecoration('Seri'),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 22,
                                    color: Color.fromARGB(255, 110, 178, 247),
                                  ),
                                  dropdownColor: Colors.white,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF333333),
                                  ),
                                  items: (_selectedSystem?.series ?? []).map((
                                    series,
                                  ) {
                                    return DropdownMenuItem<WindowSeries>(
                                      value: series,
                                      child: Text(
                                        series.name.capitalize(),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) => setState(() {
                                    _selectedSeries = val;
                                    _selectedColor = null;
                                  }),
                                ),
                                onAdd: _showAddSeriesDialog,
                                onDelete: () =>
                                    _confirmDeleteSeries(_selectedSeries!),
                                isDeleteActive: _selectedSeries != null,
                              ),
                              const SizedBox(height: 8),
                              _buildMiniDropdownRow(
                                dropdown: DropdownButtonFormField<String>(
                                  initialValue: _selectedColor,
                                  isExpanded: true,
                                  decoration: _miniInputDecoration(
                                    'Profil Rengi',
                                  ),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 22,
                                    color: Color.fromARGB(255, 110, 178, 247),
                                  ),
                                  dropdownColor: Colors.white,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF333333),
                                  ),
                                  items: (_selectedSeries?.colors ?? []).map((
                                    color,
                                  ) {
                                    return DropdownMenuItem<String>(
                                      value: color.name,
                                      child: Text(
                                        color.name.capitalize(),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) =>
                                      setState(() => _selectedColor = val),
                                ),
                                onAdd: _showAddColorDialog,
                                onDelete: _selectedColor != null
                                    ? _confirmDeleteColor
                                    : null,
                                isDeleteActive: _selectedColor != null,
                              ),
                              const SizedBox(height: 8),
                              _buildMiniDropdownRow(
                                dropdown: DropdownButtonFormField<int>(
                                  initialValue: _selectedGlassSystemId,
                                  isExpanded: true,
                                  decoration: _miniInputDecoration(
                                    'Cam Sistemi',
                                  ),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 22,
                                    color: Color.fromARGB(255, 110, 178, 247),
                                  ),
                                  dropdownColor: Colors.white,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF333333),
                                  ),
                                  items: _glassSystems.map((system) {
                                    return DropdownMenuItem<int>(
                                      value: system['id'] as int,
                                      child: Text(
                                        (system['name'] as String).capitalize(),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) => setState(() {
                                    _selectedGlassSystemId = val;
                                    _selectedGlassToneId = null;
                                  }),
                                ),
                                onAdd: _showAddGlassSystemDialog,
                                onDelete: _selectedGlassSystemId != null
                                    ? () {
                                        final system = _glassSystems.firstWhere(
                                          (s) =>
                                              s['id'] == _selectedGlassSystemId,
                                        );
                                        _confirmDeleteGlassSystem(system);
                                      }
                                    : null,
                                isDeleteActive: _selectedGlassSystemId != null,
                              ),
                              const SizedBox(height: 8),
                              _buildMiniDropdownRow(
                                dropdown: DropdownButtonFormField<int>(
                                  initialValue: _selectedGlassToneId,
                                  isExpanded: true,
                                  decoration: _miniInputDecoration('Cam Tonu'),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 22,
                                    color: Color.fromARGB(255, 110, 178, 247),
                                  ),
                                  dropdownColor: Colors.white,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF333333),
                                  ),
                                  items: _glassTones.map((tone) {
                                    return DropdownMenuItem<int>(
                                      value: tone['id'] as int,
                                      child: Text(
                                        (tone['name'] as String).capitalize(),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) => setState(
                                    () => _selectedGlassToneId = val,
                                  ),
                                ),
                                onAdd: _showAddGlassToneDialog,
                                onDelete: _selectedGlassToneId != null
                                    ? () {
                                        final tone = _glassTones.firstWhere(
                                          (t) =>
                                              t['id'] == _selectedGlassToneId,
                                        );
                                        _confirmDeleteGlassTone(tone);
                                      }
                                    : null,
                                isDeleteActive: _selectedGlassToneId != null,
                              ),
                              const SizedBox(height: 8),
                              _buildAccessoryComboSection(),
                            ] else ...[
                              // ── Kayıtlı görünüm ──
                              _buildSavedView(),
                            ],

                            const SizedBox(height: 12),
                            // Açıklama — her zaman görünür
                            TextField(
                              controller: _descriptionController,
                              maxLines: 4,
                              readOnly: _isSaved,
                              decoration: _miniInputDecoration(
                                'Açıklama / Notlar',
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                color: _isSaved
                                    ? Colors.grey.shade500
                                    : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Metretül bilgisi — fiyatın üstünde
                            Builder(
                              builder: (context) {
                                final controllerState = ref.read(
                                  drawingControllerProvider((
                                    projectId: widget.projectId,
                                    drawingId: widget.drawingId,
                                  )),
                                );
                                final shape = controllerState.currentShape;
                                if (shape == null) {
                                  return const SizedBox.shrink();
                                }
                                return _buildMetretulInfo(shape);
                              },
                            ),
                            TextField(
                              controller: _priceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              readOnly: _isSaved,
                              decoration: _miniInputDecoration('Tutar (₺)'),
                              style: TextStyle(
                                fontSize: 13,
                                color: _isSaved
                                    ? Colors.grey.shade500
                                    : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Kaydet / Düzenle butonu
                            SizedBox(
                              width: double.infinity,
                              height: 38,
                              child: _isSaved
                                  ? ElevatedButton.icon(
                                      onPressed: () =>
                                          setState(() => _isSaved = false),
                                      icon: const Icon(Icons.edit, size: 16),
                                      label: const Text(
                                        'Düzenle',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange.shade600,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        padding: EdgeInsets.zero,
                                      ),
                                    )
                                  : ElevatedButton.icon(
                                      onPressed: _saveShapeSpecs,
                                      icon: const Icon(Icons.save, size: 16),
                                      label: const Text(
                                        'Kaydet',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color.fromARGB(
                                          255,
                                          110,
                                          178,
                                          247,
                                        ),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: widget.hasDrawingTableHandle ? 132 : 8,
            bottom: _isOpen
                ? _panelHeight + MediaQuery.of(context).padding.bottom
                : widget.drawingHandleBottom,
            child: GestureDetector(
              onTap: () {
                final newValue = !_isOpen;
                setState(() => _isOpen = newValue);
                widget.onOpenChanged?.call(newValue);
              },
              child: Container(
                width: systemHandleWidth,
                height: handleHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.isDrawingOpen && !_isOpen
                        ? [Colors.grey.shade400, Colors.grey.shade300]
                        : [Colors.teal.shade700, Colors.teal.shade300],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Sistem Türü',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isOpen
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_up,
                      color: Colors.white,
                      size: 26,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessoryComboSection() {
    final selectedNames = _selectedAccessoryIds
        .map((id) {
          final acc = _accessories.firstWhere(
            (a) => a['id'] == id,
            orElse: () => {'name': ''},
          );
          return (acc['name'] as String?)?.capitalize() ?? '';
        })
        .where((n) => n.isNotEmpty)
        .join(', ');

    final displayText = selectedNames.isEmpty ? '' : selectedNames;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMiniDropdownRow(
          dropdown: GestureDetector(
            onTap: () => setState(
              () => _isAccessoryDropdownOpen = !_isAccessoryDropdownOpen,
            ),
            child: InputDecorator(
              decoration: _miniInputDecoration('Aksesuar'),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      displayText.isEmpty ? 'Aksesuar seçin' : displayText,
                      style: TextStyle(
                        fontSize: 13,
                        color: displayText.isEmpty
                            ? Colors.grey.shade600
                            : const Color(0xFF333333),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    _isAccessoryDropdownOpen
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 22,
                    color: const Color.fromARGB(255, 110, 178, 247),
                  ),
                ],
              ),
            ),
          ),
          onAdd: _showAddAccessoryDialog,
          onDelete: _selectedAccessoryIds.isNotEmpty
              ? _confirmDeleteSelectedAccessories
              : null,
          isDeleteActive: _selectedAccessoryIds.isNotEmpty,
        ),
        if (_isAccessoryDropdownOpen)
          Container(
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
              color: Colors.white,
            ),
            constraints: const BoxConstraints(maxHeight: 150),
            child: _accessories.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Henüz aksesuar yok',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _accessories.map((acc) {
                      final id = acc['id'] as int;
                      final name = (acc['name'] as String).capitalize();
                      final isSelected = _selectedAccessoryIds.contains(id);

                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedAccessoryIds.remove(id);
                            } else {
                              _selectedAccessoryIds.add(id);
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: Checkbox(
                                  value: isSelected,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedAccessoryIds.add(id);
                                      } else {
                                        _selectedAccessoryIds.remove(id);
                                      }
                                    });
                                  },
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
      ],
    );
  }

  Widget _buildMiniDropdownRow({
    required Widget dropdown,
    required VoidCallback? onAdd,
    required VoidCallback? onDelete,
    required bool isDeleteActive,
  }) {
    Widget buildActionButton({
      required IconData icon,
      required Color bgColor,
      required Color iconColor,
      required VoidCallback? onTap,
      required String tooltip,
    }) {
      return Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Center(child: Icon(icon, size: 22, color: iconColor)),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: dropdown),
        const SizedBox(width: 4),
        buildActionButton(
          icon: Icons.add,
          bgColor: const Color.fromARGB(255, 232, 245, 253),
          iconColor: const Color.fromARGB(255, 39, 153, 247),
          onTap: onAdd,
          tooltip: 'Ekle',
        ),
        const SizedBox(width: 2),
        buildActionButton(
          icon: Icons.delete_outline,
          bgColor: isDeleteActive ? Colors.red.shade50 : Colors.grey.shade100,
          iconColor: isDeleteActive
              ? Colors.red.shade400
              : Colors.grey.shade400,
          onTap: isDeleteActive ? onDelete : null,
          tooltip: 'Sil',
        ),
      ],
    );
  }

  InputDecoration _miniInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
      floatingLabelStyle: TextStyle(
        color: const Color.fromARGB(255, 110, 178, 247),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      filled: true,
      fillColor: Colors.grey.shade50,
      isDense: true,
    );
  }
}
