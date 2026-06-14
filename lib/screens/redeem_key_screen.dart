import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/license_service.dart';
import '../providers/license_provider.dart';

class RedeemKeyScreen extends ConsumerStatefulWidget {
  const RedeemKeyScreen({super.key});

  @override
  ConsumerState<RedeemKeyScreen> createState() => _RedeemKeyScreenState();
}

class _RedeemKeyScreenState extends ConsumerState<RedeemKeyScreen> {
  final _keyController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Lisans anahtarını girin.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await LicenseService().redeemKey(key);
      final tier = result['tier'] ?? 'monthly';

      if (!mounted) return;

      // Lisansı yeniden yükle (provider'ı invalidate et)
      ref.invalidate(licenseProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tier == 'yearly'
                ? 'Yıllık lisans aktifleştirildi! 🎉'
                : 'Aylık lisans aktifleştirildi! 🎉',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.of(context).pop(true); // true = başarılı
    } on LicenseDeniedException catch (e) {
      setState(() {
        _isLoading = false;
        if (e.reason == 'invalid_key') {
          _error = 'Geçersiz lisans anahtarı. Anahtarınızı kontrol edin.';
        } else if (e.reason == 'key_already_used') {
          _error = 'Bu anahtar daha önce kullanılmış.';
        } else {
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
      appBar: AppBar(title: const Text('Lisans Anahtarı')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.vpn_key, size: 64, color: Colors.green.shade700),
              const SizedBox(height: 20),
              const Text(
                'Lisans Anahtarı Girin',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Size verilen lisans anahtarını aşağıya girin.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
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
                    backgroundColor: Colors.green.shade700,
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
                          'Anahtarı Kullan',
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
