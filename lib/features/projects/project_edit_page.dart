import '../../models/project.dart' show Project;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'project_provider.dart';
import '../../models/project.dart';
import '../../shared/widgets/phone_input_field.dart';

class ProjectEditPage extends ConsumerStatefulWidget {
  final Project project;

  const ProjectEditPage({super.key, required this.project});

  @override
  ConsumerState<ProjectEditPage> createState() => _ProjectEditPageState();
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class CapitalizeEachWordTextFormatter extends TextInputFormatter {
  String _capitalizeEachWord(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? ''
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newText = _capitalizeEachWord(newValue.text);
    return newValue.copyWith(text: newText, selection: newValue.selection);
  }
}

class _ProjectEditPageState extends ConsumerState<ProjectEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _phoneNumber = '';

  @override
  void initState() {
    super.initState();
    // Mevcut proje bilgilerini controller'lara yükle
    _nameController.text = widget.project.name;
    _addressController.text = widget.project.address;
    _descriptionController.text = widget.project.description;
    _phoneNumber = widget.project.phone;

    print('📱 Düzenleme sayfasına yüklenen telefon: ${widget.project.phone}');
  }

  @override
  void dispose() {
    // 🚨 DÜZELTME: Tüm controller'ları temizle
    _nameController.dispose();
    _phoneController.dispose(); // ✅ Eğer yoksa ekle
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _updateProject() async {
    if (_formKey.currentState!.validate()) {
      // Telefon numarası değişmemişse eski değeri kullan, değişmişse yeni değeri
      final String finalPhoneNumber = _phoneNumber.isNotEmpty
          ? _phoneNumber
          : widget.project.phone;

      print('📱 Güncellenecek telefon: $finalPhoneNumber');

      final updatedProject = widget.project.copyWith(
        name: _nameController.text,
        phone: finalPhoneNumber,
        address: _addressController.text,
        description: _descriptionController.text,
      );

      await ref.read(projectProvider.notifier).updateProject(updatedProject);

      if (mounted) {
        // 🚨 BURASI DEĞİŞİYOR: Boş pop yerine güncellenmiş projeyi geri gönder
        Navigator.pop(context, updatedProject);
      }
    }
  }

  // Sol sütun içeriği (yatay mod için)
  Widget _buildLeftContent() {
    return Column(
      children: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Ad Soyad',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
          inputFormatters: [UpperCaseTextFormatter()],
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          validator: (value) {
            if (value == null || value.isEmpty)
              return 'Lütfen ad soyad giriniz';
            if (value.split(' ').length < 2)
              return 'Lütfen ad ve soyad giriniz';
            return null;
          },
        ),
        const SizedBox(height: 16),
        PhoneInputField(
          initialPhone: widget.project.phone,
          onChanged: (value) {
            _phoneNumber = value;
            print('📞 Telefon güncellendi: $value');
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _addressController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Adres',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_on),
          ),
          inputFormatters: [CapitalizeEachWordTextFormatter()],
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Lütfen adres giriniz';
            if (value.length < 10) return 'Lütfen daha detaylı adres giriniz';
            return null;
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final padding = const EdgeInsets.all(20.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projeyi Düzenle'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _updateProject,
            tooltip: 'Değişiklikleri Kaydet',
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            tooltip: 'İptal',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: padding,
          child: isLandscape
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sol sütun - Ad Soyad, Telefon, Adres
                    Expanded(
                      flex: 1,
                      child: SingleChildScrollView(child: _buildLeftContent()),
                    ),
                    const SizedBox(width: 20),
                    // Sağ sütun - Açıklama
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _descriptionController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          labelText: 'Açıklama',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                )
              // DİKEY MOD: TÜM ALANLAR TEK KAYDIRMA İÇİNDE - AÇIKLAMA ADRESİN ALTINDA
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Üst kısım form alanları
                      _buildLeftContent(),
                      const SizedBox(height: 16),
                      // Açıklama alanı - ADRESİN ALTINDA
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Açıklama',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
