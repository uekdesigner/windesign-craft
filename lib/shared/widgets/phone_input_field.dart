// phone_input_field.dart - BAŞTAN SONA YENİ KOD

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';

typedef PhoneChangedCallback = void Function(String phone);

class PhoneInputField extends StatefulWidget {
  final PhoneChangedCallback? onChanged;
  final String? initialPhone;

  const PhoneInputField({super.key, this.onChanged, this.initialPhone});

  @override
  State<PhoneInputField> createState() => _PhoneInputFieldState();
}

class _PhoneInputFieldState extends State<PhoneInputField> {
  final TextEditingController _controller = TextEditingController();
  MaskTextInputFormatter? _mask;

  String _countryCode = '+90';
  String _countryShort = 'TR';
  bool _isLoading = false; // 🚨 DEĞİŞTİ: true -> false (başta gösterme)
  String _phoneNumber = '';
  bool _isDetectingLocation = false; // 🚨 YENİ: Konum arka planda

  final List<Map<String, String>> _countries = [
    {'short': 'TR', 'code': '+90'},
    {'short': 'US', 'code': '+1'},
    {'short': 'UK', 'code': '+44'},
    {'short': 'DE', 'code': '+49'},
  ];

  @override
  void initState() {
    super.initState();
    _phoneNumber = widget.initialPhone ?? '';

    // 🚨 YENİ: Hemen başlat, konumu arka planda al
    _quickInit();

    // 🚨 YENİ: Konum 1 saniye sonra arka planda gelsin
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _detectLocationInBackground();
    });
  }

  // 🚨 YENİ: Anlık başlatma (konumsuz)
  Future<void> _quickInit() async {
    final prefs = await SharedPreferences.getInstance();

    // Önce kaydedilmiş ülke var mı?
    final savedShort = prefs.getString('selected_country_short');
    if (savedShort != null) {
      final country = _countries.firstWhere(
        (c) => c['short'] == savedShort,
        orElse: () => _countries[0],
      );
      _countryShort = country['short']!;
      _countryCode = country['code']!;
    } else {
      // Varsayılan TR
      _countryShort = 'TR';
      _countryCode = '+90';
    }

    _updateMask();

    // 🚨 Hemen telefonu yükle, bekleme
    if (widget.initialPhone != null && widget.initialPhone!.isNotEmpty) {
      _loadInitialPhoneFast(widget.initialPhone!);
    }

    setState(() {}); // UI güncelle
  }

  // 🚨 YENİ: Arka planda konum belirle (UI'ı bloklamaz)
  Future<void> _detectLocationInBackground() async {
    if (_isDetectingLocation) return;
    _isDetectingLocation = true;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low, // 🚨 DÜŞÜK doğruluk = hızlı
        timeLimit: const Duration(seconds: 3), // 🚨 3 saniye timeout
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 2), onTimeout: () => []); // 🚨 Timeout

      if (placemarks.isNotEmpty && mounted) {
        final countryCode = placemarks.first.isoCountryCode;
        if (countryCode != null && countryCode != _countryShort) {
          // Sadece farklı ülke ise güncelle
          final country = _countries.firstWhere(
            (c) => c['short'] == countryCode,
            orElse: () => _countries[0],
          );

          setState(() {
            _countryShort = country['short']!;
            _countryCode = country['code']!;
          });

          _updateMask();

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('selected_country_short', _countryShort);

          // Kullanıcıya bildir (opsiyonel)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ülke kodu ${_countryCode} olarak güncellendi'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('📍 Konum hatası (önemli değil): $e');
    } finally {
      _isDetectingLocation = false;
    }
  }

  // 🚨 YENİ: Hızlı telefon yükleme (mask kullanarak)
  void _loadInitialPhoneFast(String initialPhone) {
    try {
      String digitsOnly = initialPhone.replaceAll(RegExp(r'[^\d]'), '');

      // 90 prefix'ini at
      String numberPart = digitsOnly;
      if (numberPart.startsWith('90') && numberPart.length > 10) {
        numberPart = numberPart.substring(2);
      }

      // Son 10 hane
      if (numberPart.length > 10) {
        numberPart = numberPart.substring(numberPart.length - 10);
      }

      // Mask ile formatla
      if (numberPart.length == 10 && _mask != null) {
        final masked = _mask!.maskText(numberPart);
        _controller.text = masked;
        _phoneNumber = '$_countryCode$numberPart';
      } else {
        _controller.text = initialPhone;
        _phoneNumber = initialPhone;
      }
    } catch (e) {
      _controller.text = initialPhone;
      _phoneNumber = initialPhone;
    }
  }

  void _updateMask() {
    _mask = MaskTextInputFormatter(
      mask: '$_countryCode (###) ### ## ##',
      filter: {"#": RegExp(r'[0-9]')},
      type: MaskAutoCompletionType.lazy,
    );

    // Mevcut değeri koru
    String currentText = _controller.text;
    if (currentText.isNotEmpty) {
      String digitsOnly = currentText.replaceAll(RegExp(r'[^\d]'), '');
      String numberPart = digitsOnly.length >= 10
          ? digitsOnly.substring(digitsOnly.length - 10)
          : digitsOnly;

      if (numberPart.length == 10 && _mask != null) {
        _controller.text = _mask!.maskText(numberPart);
      }
    }
  }

  String _getCleanPhoneNumber(String formattedPhone) {
    try {
      String digitsOnly = formattedPhone.replaceAll(RegExp(r'[^\d]'), '');

      String numberPart = digitsOnly;
      if (numberPart.startsWith('90') && numberPart.length > 10) {
        numberPart = numberPart.substring(2);
      }

      if (numberPart.length > 10) {
        numberPart = numberPart.substring(numberPart.length - 10);
      }

      while (numberPart.length < 10) {
        numberPart = '0$numberPart';
      }

      return '$_countryCode$numberPart';
    } catch (e) {
      return '${_countryCode}0000000000';
    }
  }

  void _onCountryChanged(String short) async {
    final country = _countries.firstWhere(
      (c) => c['short'] == short,
      orElse: () => _countries[0],
    );
    setState(() {
      _countryShort = country['short']!;
      _countryCode = country['code']!;
    });
    _updateMask();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_country_short', _countryShort);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 🚨 YENİ: Konum aranıyorsa küçük indicator
        if (_isDetectingLocation)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),

        DropdownButton<String>(
          value: _countryShort,
          items: _countries
              .map(
                (c) => DropdownMenuItem<String>(
                  value: c['short'],
                  child: Text('${c['short']} ${c['code']}'),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) _onCountryChanged(value);
          },
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: _mask != null ? [_mask!] : [],
            onChanged: (value) {
              if (widget.onChanged != null) {
                String cleanPhone = _getCleanPhoneNumber(value);
                _phoneNumber = cleanPhone;
                widget.onChanged!(cleanPhone);
              }
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Telefon numarası giriniz';
              }
              String digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
              int digitCount = digitsOnly.length;
              if (digitCount < 10) {
                return '10 haneli telefon numarası giriniz';
              }
              return null;
            },
            decoration: InputDecoration(
              labelText: 'Telefon',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              // 🚨 YENİ: Konum durumu hint
              suffixIcon: _isDetectingLocation
                  ? Icon(Icons.location_searching, color: Colors.blue, size: 20)
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
