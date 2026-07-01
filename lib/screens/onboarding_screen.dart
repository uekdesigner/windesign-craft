// lib/screens/onboarding_screen.dart
//
// 9 slaytlık tanıtım / onboarding akışı.
// İllüstrasyonlar SVG olarak gömülüdür (flutter_svg -> SvgPicture.string).
// Son slayttaki "Başla" (veya "Atla") -> onboarding_completed flag'i yazar
// ve AuthGate'e geçer.
//
// pubspec.yaml:
//   dependencies:
//     flutter_svg: ^2.0.10
//     shared_preferences: ^2.2.2   (zaten projede mevcut)

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../shared/widgets/auth_gate.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  static const Color _bg = Color(0xFFF5F7FA);
  static const Color _blue = Color(0xFF2F73E8);
  static const Color _ink = Color(0xFF1F2A37);
  static const Color _muted = Color(0xFF6B7686);
  static const Color _dotIdle = Color(0xFFCFD8E3);

  bool get _isLast => _index == _slides.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthGate()));
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // Üst bar: Atla (son slaytta gizli)
            SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerRight,
                child: AnimatedOpacity(
                  opacity: _isLast ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(
                    onPressed: _isLast ? null : _finish,
                    child: const Text(
                      'Atla',
                      style: TextStyle(color: _muted, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ),

            // Slaytlar
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _SlideView(slide: _slides[i]),
              ),
            ),

            // Nokta göstergesi
            Padding(
              padding: const EdgeInsets.only(bottom: 18, top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3.5),
                    height: 7,
                    width: active ? 22 : 7,
                    decoration: BoxDecoration(
                      color: active ? _blue : _dotIdle,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // Buton
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 0, 26, 26),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _isLast ? 'Başla' : 'İleri',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Column(
        children: [
          const Spacer(flex: 2),
          SvgPicture.string(slide.svg, height: 210),
          const SizedBox(height: 18),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: _OnboardingScreenState._ink,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: _OnboardingScreenState._muted,
            ),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

class _Slide {
  final String svg;
  final String title;
  final String body;
  const _Slide({required this.svg, required this.title, required this.body});
}

const List<_Slide> _slides = [
  _Slide(
    title: 'WinDesign Craft Pro',
    body: 'Profesyonel PVC pencere tasarımı artık cebinizde.',
    svg: '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 170">
<ellipse cx="100" cy="156" rx="62" ry="7" fill="#E3E8EF"/>
<path d="M52 74 A48 48 0 0 1 148 74 L148 144 A6 6 0 0 1 142 150 L58 150 A6 6 0 0 1 52 144 Z" fill="#EAF2FD" stroke="#2F73E8" stroke-width="4"/>
<line x1="100" y1="28" x2="100" y2="150" stroke="#2F73E8" stroke-width="3"/>
<line x1="52" y1="96" x2="148" y2="96" stroke="#2F73E8" stroke-width="3"/>
<line x1="100" y1="96" x2="62" y2="64" stroke="#9CC3F2" stroke-width="2"/>
<line x1="100" y1="96" x2="138" y2="64" stroke="#9CC3F2" stroke-width="2"/>
<rect x="91" y="114" width="6" height="18" rx="3" fill="#2F73E8"/>
</svg>''',
  ),
  _Slide(
    title: 'Firma bilgileriniz',
    body:
        'Firma adı, iletişim ve logonuzu girin. Tüm PDF çıktılarında firma antetiniz görünür.',
    svg: '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 170">
<rect x="34" y="34" width="132" height="106" rx="10" fill="#FFFFFF" stroke="#E3E8EF" stroke-width="3"/>
<rect x="50" y="52" width="34" height="34" rx="6" fill="#FFF1DC" stroke="#F39200" stroke-width="3"/>
<path d="M57 78 l8-9 6 6 5-6 7 9z" fill="#F39200"/>
<circle cx="78" cy="62" r="4" fill="#F39200"/>
<rect x="94" y="56" width="54" height="8" rx="4" fill="#2F73E8"/>
<rect x="94" y="70" width="38" height="6" rx="3" fill="#C7D6EA"/>
<rect x="50" y="100" width="100" height="9" rx="4" fill="#EAF2FD"/>
<rect x="50" y="116" width="74" height="9" rx="4" fill="#EAF2FD"/>
</svg>''',
  ),
  _Slide(
    title: 'Lisansınız',
    body:
        'Hesabınızı ve lisans durumunuzu görün; deneme sürenizi ve planınızı takip edin.',
    svg: '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 170">
<path d="M100 30 L150 48 V90 C150 120 128 138 100 146 C72 138 50 120 50 90 V48 Z" fill="#E3F6EC" stroke="#2BB673" stroke-width="4"/>
<path d="M79 88 l13 13 27-29" fill="none" stroke="#2BB673" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>
<rect x="118" y="104" width="46" height="20" rx="10" fill="#2F73E8"/>
<circle cx="129" cy="114" r="3.5" fill="#FFFFFF"/>
<rect x="137" y="111" width="20" height="6" rx="3" fill="#FFFFFF"/>
</svg>''',
  ),
  _Slide(
    title: 'Proje oluşturun',
    body:
        'Her müşteri için ayrı proje açın. Ad, telefon ve adresle düzenli kalın.',
    svg: '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 170">
<path d="M38 54 h36 l10 12 h78 a8 8 0 0 1 8 8 v56 a8 8 0 0 1-8 8 H38 a8 8 0 0 1-8-8 V62 a8 8 0 0 1 8-8 Z" fill="#FDE7C9" stroke="#F39200" stroke-width="3"/>
<rect x="54" y="78" width="92" height="54" rx="8" fill="#FFFFFF" stroke="#2F73E8" stroke-width="3"/>
<circle cx="75" cy="97" r="9" fill="#EAF2FD" stroke="#2F73E8" stroke-width="3"/>
<path d="M67 114 a8 8 0 0 1 16 0" fill="none" stroke="#2F73E8" stroke-width="3"/>
<rect x="94" y="89" width="42" height="7" rx="3" fill="#2F73E8"/>
<rect x="94" y="101" width="32" height="6" rx="3" fill="#C7D6EA"/>
<rect x="94" y="113" width="36" height="6" rx="3" fill="#C7D6EA"/>
</svg>''',
  ),
  _Slide(
    title: 'Ödeme takibi & dekont',
    body:
        "Toplam, iskonto, ödenen ve kalanı izleyin. Tek dokunuşla QR'lı PDF dekont oluşturun.",
    svg: '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 170">
<rect x="46" y="28" width="80" height="118" rx="8" fill="#FFFFFF" stroke="#2F73E8" stroke-width="3"/>
<rect x="60" y="46" width="36" height="8" rx="4" fill="#2F73E8"/>
<rect x="60" y="64" width="52" height="6" rx="3" fill="#DCE6F4"/>
<rect x="60" y="78" width="52" height="6" rx="3" fill="#DCE6F4"/>
<rect x="60" y="96" width="34" height="6" rx="3" fill="#DCE6F4"/>
<rect x="60" y="116" width="44" height="10" rx="5" fill="#2BB673"/>
<rect x="116" y="92" width="44" height="44" rx="6" fill="#FFFFFF" stroke="#1F2A37" stroke-width="2.5"/>
<rect x="123" y="99" width="9" height="9" fill="#1F2A37"/>
<rect x="144" y="99" width="9" height="9" fill="#1F2A37"/>
<rect x="123" y="120" width="9" height="9" fill="#1F2A37"/>
<rect x="137" y="113" width="5" height="5" fill="#1F2A37"/>
<rect x="146" y="118" width="7" height="11" fill="#1F2A37"/>
</svg>''',
  ),
  _Slide(
    title: 'Pencereyi çizin',
    body:
        'Şekil araçlarıyla çizin, sol/sağ panelleri ve sistem türünü ekleyin. Ölçüler otomatik hesaplanır.',
    svg: '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 170">
<rect x="36" y="32" width="22" height="16" rx="4" fill="#EAF2FD" stroke="#2F73E8" stroke-width="2"/>
<rect x="62" y="32" width="22" height="16" rx="4" fill="#FFF1DC" stroke="#F39200" stroke-width="2"/>
<path d="M70 60 L150 60 L150 146 L40 146 L40 84 Z" fill="#EAF2FD" stroke="#1F2A37" stroke-width="3"/>
<line x1="104" y1="72" x2="104" y2="146" stroke="#1F2A37" stroke-width="2.5"/>
<path d="M150 84 L120 146 M150 146 L120 84" stroke="#9CA8B8" stroke-width="1.5" stroke-dasharray="4 3"/>
<line x1="26" y1="60" x2="26" y2="146" stroke="#2F73E8" stroke-width="1.5"/>
<line x1="22" y1="60" x2="30" y2="60" stroke="#2F73E8" stroke-width="1.5"/>
<line x1="22" y1="146" x2="30" y2="146" stroke="#2F73E8" stroke-width="1.5"/>
<line x1="40" y1="158" x2="150" y2="158" stroke="#2F73E8" stroke-width="1.5"/>
<line x1="40" y1="154" x2="40" y2="162" stroke="#2F73E8" stroke-width="1.5"/>
<line x1="150" y1="154" x2="150" y2="162" stroke="#2F73E8" stroke-width="1.5"/>
</svg>''',
  ),
  _Slide(
    title: 'PDF olarak paylaşın',
    body:
        'Çizimleri seçin, firma antetli profesyonel PDF oluşturup anında paylaşın.',
    svg: '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 170">
<path d="M50 30 h46 l22 22 v76 a6 6 0 0 1-6 6 H50 a6 6 0 0 1-6-6 V36 a6 6 0 0 1 6-6Z" fill="#FFFFFF" stroke="#2F73E8" stroke-width="3"/>
<path d="M96 30 v22 h22" fill="none" stroke="#2F73E8" stroke-width="3"/>
<rect x="52" y="78" width="40" height="20" rx="4" fill="#E24B4A"/>
<rect x="58" y="85" width="5" height="6" fill="#FFFFFF"/>
<rect x="67" y="85" width="5" height="6" fill="#FFFFFF"/>
<rect x="76" y="85" width="5" height="6" fill="#FFFFFF"/>
<rect x="52" y="108" width="56" height="6" rx="3" fill="#DCE6F4"/>
<rect x="52" y="120" width="42" height="6" rx="3" fill="#DCE6F4"/>
<circle cx="156" cy="58" r="9" fill="#2F73E8"/>
<circle cx="156" cy="112" r="9" fill="#2F73E8"/>
<circle cx="130" cy="86" r="9" fill="#2F73E8"/>
<line x1="137" y1="81" x2="149" y2="64" stroke="#2F73E8" stroke-width="3"/>
<line x1="137" y1="92" x2="149" y2="106" stroke="#2F73E8" stroke-width="3"/>
</svg>''',
  ),
  _Slide(
    title: 'Projeleriniz bir arada',
    body: 'Tüm müşterileriniz alfabetik ve aranabilir tek listede.',
    svg: '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 170">
<rect x="34" y="32" width="108" height="22" rx="7" fill="#EAF2FD"/>
<circle cx="50" cy="43" r="5" fill="none" stroke="#2F73E8" stroke-width="2"/>
<line x1="54" y1="47" x2="58" y2="51" stroke="#2F73E8" stroke-width="2"/>
<rect x="34" y="64" width="108" height="24" rx="6" fill="#FFFFFF" stroke="#E3E8EF" stroke-width="2"/>
<rect x="44" y="71" width="16" height="11" rx="3" fill="#FDE7C9" stroke="#F39200" stroke-width="2"/>
<rect x="68" y="72" width="44" height="5" rx="2.5" fill="#1F2A37"/>
<rect x="68" y="81" width="30" height="4" rx="2" fill="#C7D6EA"/>
<rect x="34" y="94" width="108" height="24" rx="6" fill="#FFFFFF" stroke="#E3E8EF" stroke-width="2"/>
<rect x="44" y="101" width="16" height="11" rx="3" fill="#FDE7C9" stroke="#F39200" stroke-width="2"/>
<rect x="68" y="102" width="40" height="5" rx="2.5" fill="#1F2A37"/>
<rect x="68" y="111" width="26" height="4" rx="2" fill="#C7D6EA"/>
<rect x="34" y="124" width="108" height="24" rx="6" fill="#FFFFFF" stroke="#E3E8EF" stroke-width="2"/>
<rect x="44" y="131" width="16" height="11" rx="3" fill="#FDE7C9" stroke="#F39200" stroke-width="2"/>
<rect x="68" y="132" width="48" height="5" rx="2.5" fill="#1F2A37"/>
<rect x="68" y="141" width="28" height="4" rx="2" fill="#C7D6EA"/>
<rect x="150" y="64" width="16" height="84" rx="8" fill="#EAF2FD"/>
<circle cx="158" cy="74" r="2" fill="#2F73E8"/>
<circle cx="158" cy="86" r="2" fill="#2F73E8"/>
<circle cx="158" cy="98" r="2" fill="#8FA8C9"/>
<circle cx="158" cy="110" r="2" fill="#8FA8C9"/>
<circle cx="158" cy="122" r="2" fill="#8FA8C9"/>
<circle cx="158" cy="134" r="2" fill="#8FA8C9"/>
</svg>''',
  ),
  _Slide(
    title: 'Hazırsınız!',
    body: 'Hadi ilk projenizi oluşturalım.',
    svg: '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 170">
<circle cx="100" cy="88" r="46" fill="#E3F6EC" stroke="#2BB673" stroke-width="4"/>
<path d="M79 88 l15 15 29-31" stroke="#2BB673" stroke-width="8" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M46 44 l3 9 9 3-9 3-3 9-3-9-9-3 9-3z" fill="#F39200"/>
<path d="M152 116 l2.5 7 7 2.5-7 2.5-2.5 7-2.5-7-7-2.5 7-2.5z" fill="#2F73E8"/>
<path d="M150 50 l2 6 6 2-6 2-2 6-2-6-6-2 6-2z" fill="#2BB673"/>
</svg>''',
  ),
];
