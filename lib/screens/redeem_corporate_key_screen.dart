import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/license_service.dart';
import '../providers/license_provider.dart';

class RedeemCorporateKeyScreen extends ConsumerStatefulWidget {
  const RedeemCorporateKeyScreen({super.key});

  @override
  ConsumerState<RedeemCorporateKeyScreen> createState() =>
      _RedeemCorporateKeyScreenState();
}

class _RedeemCorporateKeyScreenState
    extends ConsumerState<RedeemCorporateKeyScreen> {
  final _keyController = TextEditingController();
  final _orgNameController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _keyController.dispose();
    _orgNameController.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final key = _keyController.text.trim();
    final orgName = _orgNameController.text.trim();

    if (orgName.isEmpty) {
      setState(() => _error = 'Firma adını girin.');
      return;
    }
    if (key.isEmpty) {
      setState(() => _error = 'Kurumsal lisans anahtarını girin.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await LicenseService().redeemCorporateKey(
        key: key,
        orgName: orgName,
      );
      final seats = result['seats'] ?? 0;

      if (!mounted) return;

      ref.invalidate(licenseProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kurumsal lisans aktifleştirildi! $seats koltuk 🎉'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.of(context).pop(true);
    } on LicenseDeniedException catch (e) {
      setState(() {
        _isLoading = false;
        switch (e.reason) {
          case 'invalid_key':
            _error = 'Geçersiz lisans anahtarı. Anahtarınızı kontrol edin.';
            break;
          case 'key_already_used':
            _error = 'Bu anahtar daha önce kullanılmış.';
            break;
          case 'not_corporate_key':
            _error =
                'Bu anahtar kurumsal değil. Bireysel anahtarlar için "Lisans Anahtarı Gir" ekranını kullanın.';
            break;
          default:
            _error = 'Anahtar kullanılamadı: ${e.reason}';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Bir hata oluştu. İnternet bağlantınızı kontrol edin.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kurumsal Lisans')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.business_center,
                size: 64,
                color: Colors.indigo.shade600,
              ),
              const SizedBox(height: 20),
              const Text(
                'Kurumsal Lisans Aktifleştir',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Firma adınızı ve size verilen kurumsal lisans anahtarını girin.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _orgNameController,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'Firma Adı',
                  prefixIcon: const Icon(Icons.apartment),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _keyController,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
                decoration: InputDecoration(
                  hintText: 'WDC-XXXX-XXXX-XXXX',
                  prefixIcon: const Icon(Icons.key),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _redeem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Kurumsal Lisansı Aktifleştir',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
