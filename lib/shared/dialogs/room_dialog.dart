import 'package:flutter/material.dart';
import '../../models/drawing.dart';

class RoomDialog extends StatefulWidget {
  final Drawing drawing;

  const RoomDialog({super.key, required this.drawing});

  @override
  State<RoomDialog> createState() => _RoomDialogState();
}

class _RoomDialogState extends State<RoomDialog> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedDirection = 'Doğu';

  final List<String> _directions = [
    'Doğu',
    'Batı',
    'Kuzey',
    'Güney',
    'KuzeyDoğu',
    'KuzeyBatı',
    'GüneyDoğu',
    'GüneyBatı',
  ];

  static const double _defaultHeight = 500.0;
  static const double _defaultWidth = 500.0;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    if (widget.drawing.location != null) {
      _locationController.text = widget.drawing.location!;
      _selectedDirection = widget.drawing.direction ?? 'Doğu';
      _descriptionController.text = widget.drawing.roomDescription ?? '';
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onSave() {
    if (_formKey.currentState!.validate()) {
      final locationName = _locationController.text.trim();

      // 🚨 KESİN ATAMA - locationName boşsa varsayılan kullan
      final finalName = locationName.isNotEmpty
          ? locationName
          : 'İsimsiz Çizim';

      final updatedDrawing = Drawing(
        id: widget.drawing.id,
        projectId: widget.drawing.projectId,
        name: finalName, // 🚨 KESİN ATAMA
        createdAt: widget.drawing.createdAt,
        updatedAt: DateTime.now().toIso8601String(),
        location: locationName,
        direction: _selectedDirection,
        height: _defaultHeight,
        width: _defaultWidth,
        roomDescription: _descriptionController.text.trim(),
      );

      Navigator.of(context).pop(updatedDrawing);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🚨 YENİ: Ekran boyutu kontrolü
    final size = MediaQuery.of(context).size;
    final isSmallScreen =
        size.width < 600 || size.height < 400; // Yetersiz ekran
    final isLandscape = size.width > size.height;

    // Küçük ekranda yatay mod uyarısı
    if (isSmallScreen && isLandscape) {
      return _buildOrientationWarning(context); // Uyarı dialog'u
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 320,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior
                  .manual, // 🚨 onDrag → manual
              physics:
                  const ClampingScrollPhysics(), // 🚨 YENİ: Daha stabil kaydırma
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 🎨 YENİ: Üst satır - İkon butonlar (sağda)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _onSave,
                        icon: Icon(
                          Icons.save,
                          color: const Color.fromARGB(255, 18, 18, 18),
                          size: 24,
                        ),
                        splashRadius: 20,
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close,
                          color: Colors.grey[600],
                          size: 24,
                        ),
                        splashRadius: 20,
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Konum
                  TextFormField(
                    controller: _locationController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Konum *',
                      hintText: 'Örn: Salon, Yatak Odası, Mutfak',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Lütfen konum giriniz';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Yön Seçimi
                  DropdownButtonFormField<String>(
                    value: _selectedDirection,
                    decoration: InputDecoration(
                      labelText: 'Yön *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    items: _directions.map((String direction) {
                      return DropdownMenuItem<String>(
                        value: direction,
                        child: Text(direction),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedDirection = newValue!;
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // Sabit ölçü bilgisi
                  Container(),
                  const SizedBox(height: 12),

                  // Açıklama
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Açıklama',
                      hintText: 'Ek bilgiler...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),

                      alignLabelWithHint: true,
                    ),
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🚨 YENİ: Uyarı dialog'u
  Widget _buildOrientationWarning(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.screen_rotation, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'Dikey Mod Gerekli',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bu işlem için telefonunuzu dikey konuma çeviriniz.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tamam'),
            ),
          ],
        ),
      ),
    );
  }
}
