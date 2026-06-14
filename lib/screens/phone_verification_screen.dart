import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PhoneVerificationScreen extends StatefulWidget {
  const PhoneVerificationScreen({super.key});

  @override
  State<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _auth = FirebaseAuth.instance;

  String? _verificationId;
  bool _codeSent = false;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// 1. Adım: SMS gönder
  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Telefon numaranızı girin.');
      return;
    }

    // Başında + yoksa Türkiye kodu ekle
    final fullPhone = phone.startsWith('+') ? phone : '+90$phone';

    setState(() {
      _isLoading = true;
      _error = null;
    });

    await _auth.verifyPhoneNumber(
      phoneNumber: fullPhone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Android'de otomatik doğrulama (SMS auto-retrieve)
        await _linkPhone(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() {
          _isLoading = false;
          if (e.code == 'too-many-requests') {
            _error = 'Çok fazla deneme. Lütfen biraz bekleyin.';
          } else if (e.code == 'invalid-phone-number') {
            _error = 'Geçersiz telefon numarası. Örn: 5XX XXX XX XX';
          } else {
            _error = 'SMS gönderilemedi: ${e.message}';
          }
        });
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _codeSent = true;
          _isLoading = false;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  /// 2. Adım: Kullanıcının girdiği kodu doğrula
  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || _verificationId == null) {
      setState(() => _error = 'Doğrulama kodunu girin.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      await _linkPhone(credential);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        if (e.code == 'invalid-verification-code') {
          _error = 'Yanlış kod. Tekrar deneyin.';
        } else if (e.code == 'credential-already-in-use') {
          _error = 'Bu telefon numarası başka bir hesapla kullanılıyor.';
        } else {
          _error = 'Doğrulama hatası: ${e.message}';
        }
      });
    }
  }

  /// Telefonu mevcut Google hesabına bağla
  Future<void> _linkPhone(PhoneAuthCredential credential) async {
    try {
      await _auth.currentUser?.linkWithCredential(credential);
      // Başarılı — AuthGate otomatik olarak yeniden kontrol edecek
      // (user.phoneNumber artık dolu, sayfa değişecek)
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        if (e.code == 'credential-already-in-use') {
          _error =
              'Bu telefon numarası başka bir hesapla kullanılıyor. Her numara yalnızca bir hesapta kullanılabilir.';
        } else if (e.code == 'provider-already-linked') {
          // Zaten bağlı — sorun yok, devam
        } else {
          _error = 'Bağlama hatası: ${e.message}';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.phone_android,
                  size: 64,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Telefon Doğrulama',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Devam etmek için telefon numaranızı doğrulayın.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                if (!_codeSent) ...[
                  // TELEFON NUMARASI GİRİŞİ
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Telefon Numarası',
                      hintText: '5XX XXX XX XX',
                      prefixText: '+90 ',
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _sendCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
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
                              'SMS Gönder',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                ] else ...[
                  // DOĞRULAMA KODU GİRİŞİ
                  Text(
                    '${_phoneController.text} numarasına kod gönderildi.',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, letterSpacing: 8),
                    decoration: InputDecoration(
                      labelText: 'Doğrulama Kodu',
                      hintText: '------',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyCode,
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
                              'Doğrula',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _codeSent = false;
                        _codeController.clear();
                        _error = null;
                      });
                    },
                    child: const Text('Numarayı Değiştir'),
                  ),
                ],

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
      ),
    );
  }
}
