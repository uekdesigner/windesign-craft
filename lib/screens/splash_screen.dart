// lib/screens/splash_screen.dart
//
// WinDesign Craft Pro açılış animasyonu.
// Gerçek logo (4 gözlü kesik köşeli pencere + MM ölçü okları + cetvel/kalem)
// kendi kendine çizilir. SAHTE DURUM METNİ YOK, progress bar YOK.
//
// Kullanım — AuthGate yüklenme görseli olarak (önerilen):
//   loading: () => const SplashScreen(),
// Lisans kontrolü bitince AuthGate kendi ekranına geçer; splash o anın
// üstüne biner. Tek başına zamanlı splash isteniyorsa onComplete ver.
//
// NOT: Logo elle vektöre çevrildi (PNG'den). Birebir piksel değil ama
// logonun aynısı; gerçek SVG çıkarılırsa Path'ler birebir değiştirilebilir.

import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.onComplete,
    this.duration = const Duration(milliseconds: 7000),
  });

  /// Animasyon bitince çağrılır (AuthGate görseli olarak kullanılırken gerek yok).
  final VoidCallback? onComplete;
  final Duration duration;

  static const Color brandBlue = Color(0xFF1B4FA0);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _draw;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onComplete?.call();
      });
    _draw = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SplashScreen.brandBlue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 240,
              height: 240,
              child: AnimatedBuilder(
                animation: _draw,
                builder: (_, __) =>
                    CustomPaint(painter: _LogoPainter(progress: _draw.value)),
              ),
            ),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: _draw,
              builder: (_, __) => _buildAnimatedTitle(_draw.value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedTitle(double progress) {
    const text = 'WinDesign Craft Pro';
    // 0.75'ten sonra başla, 1.0'da bitir
    final t = ((progress - 0.75) / 0.25).clamp(0.0, 1.0);
    final visibleCount = (t * text.length).floor();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(text.length, (i) {
        double charOpacity;
        if (i < visibleCount) {
          charOpacity = 1.0;
        } else if (i == visibleCount) {
          // Şu an çizilen harf — kısmi opacity
          charOpacity = (t * text.length) - visibleCount.toDouble();
        } else {
          charOpacity = 0.0;
        }

        return Opacity(
          opacity: charOpacity.clamp(0.0, 1.0),
          child: Text(
            text[i],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        );
      }),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.progress});

  final double progress;

  static const Color _white = Colors.white;
  static const Color _yellow = Color(0xFFF5B301);
  static const Color _blue = SplashScreen.brandBlue;

  @override
  void paint(Canvas canvas, Size size) {
    // 220x220 tasarım uzayını mevcut boyuta ölçekle (240 SizedBox içinde ortala).
    final s = size.width / 220.0;
    canvas.translate((size.width - 220 * s) / 2, (size.height - 220 * s) / 2);
    canvas.scale(s);

    final frame = Paint()
      ..color = _white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final mull = Paint()
      ..color = _white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final yellow = Paint()
      ..color = _yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    final pencil = Paint()
      ..color = _white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final ruler = Paint()
      ..color = _white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;
    final tick = Paint()
      ..color = _blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    final p = progress;

    // 1) Kasa (kesik köşeli pencere çerçevesi) — 0.00..0.42
    final tFrame = (p / 0.42).clamp(0.0, 1.0);
    final framePath = Path()
      ..moveTo(58, 52)
      ..lineTo(132, 52)
      ..lineTo(150, 70)
      ..lineTo(150, 150)
      ..lineTo(58, 150)
      ..close();
    _drawPartial(canvas, framePath, frame, tFrame);

    // 2) Orta kayıtlar (artı) — 0.38..0.60
    if (p > 0.38) {
      final t = ((p - 0.38) / 0.22).clamp(0.0, 1.0);
      canvas.drawLine(
        const Offset(104, 52),
        _lerp(const Offset(104, 52), const Offset(104, 150), t),
        mull,
      );
      canvas.drawLine(
        const Offset(58, 101),
        _lerp(const Offset(58, 101), const Offset(150, 101), t),
        mull,
      );
    }

    // 3) Sarı MM ölçü okları + etiketler — 0.55..0.80
    if (p > 0.55) {
      final t = ((p - 0.55) / 0.25).clamp(0.0, 1.0);
      // üst yatay ok (ortada MM için boşluk)
      canvas.drawLine(
        const Offset(92, 40),
        _lerp(const Offset(92, 40), const Offset(58, 40), t),
        yellow,
      );
      canvas.drawLine(
        const Offset(116, 40),
        _lerp(const Offset(116, 40), const Offset(150, 40), t),
        yellow,
      );
      // sol dikey ok
      canvas.drawLine(
        const Offset(42, 92),
        _lerp(const Offset(42, 92), const Offset(42, 52), t),
        yellow,
      );
      canvas.drawLine(
        const Offset(42, 110),
        _lerp(const Offset(42, 110), const Offset(42, 150), t),
        yellow,
      );
      if (t > 0.8) {
        _chevron(canvas, const Offset(58, 40), const Offset(-1, 0), yellow);
        _chevron(canvas, const Offset(150, 40), const Offset(1, 0), yellow);
        _chevron(canvas, const Offset(42, 52), const Offset(0, -1), yellow);
        _chevron(canvas, const Offset(42, 150), const Offset(0, 1), yellow);
      }
      final op = ((t - 0.25) / 0.75).clamp(0.0, 1.0);
      _text(canvas, 'MM', const Offset(104, 40), op);
      _text(canvas, 'MM', const Offset(42, 101), op);
    }

    // 4) Cetvel + kalem (sağ-alt çapraz) — 0.75..1.00
    if (p > 0.75) {
      final t = ((p - 0.75) / 0.25).clamp(0.0, 1.0);
      final tBody = (t / 0.7).clamp(0.0, 1.0);

      const pB = Offset(182, 106), pA = Offset(122, 168); // kalem ekseni
      const rC = Offset(110, 116), rD = Offset(178, 182); // cetvel ekseni
      canvas.drawLine(pB, _lerp(pB, pA, tBody), pencil);
      canvas.drawLine(rC, _lerp(rC, rD, tBody), ruler);

      if (t > 0.7) {
        // kalem ucu (üçgen)
        final dir = _unit(pA - pB);
        final perp = Offset(-dir.dy, dir.dx);
        final tip = pA + dir * 9;
        canvas.drawPath(
          Path()
            ..moveTo(tip.dx, tip.dy)
            ..lineTo((pA + perp * 5).dx, (pA + perp * 5).dy)
            ..lineTo((pA - perp * 5).dx, (pA - perp * 5).dy)
            ..close(),
          Paint()..color = _white,
        );
        // cetvel çentikleri
        final rdir = _unit(rD - rC);
        final rperp = Offset(-rdir.dy, rdir.dx);
        for (final f in const [0.28, 0.46, 0.64, 0.82]) {
          final base = _lerp(rC, rD, f);
          canvas.drawLine(base + rperp * 2, base + rperp * 8, tick);
        }
      }
    }
  }

  void _drawPartial(Canvas c, Path path, Paint paint, double t) {
    if (t <= 0) return;
    if (t >= 1) {
      c.drawPath(path, paint);
      return;
    }
    for (final m in path.computeMetrics()) {
      c.drawPath(m.extractPath(0, m.length * t), paint);
    }
  }

  void _chevron(Canvas c, Offset tip, Offset dir, Paint paint) {
    const len = 7.0;
    final back = Offset(-dir.dx, -dir.dy);
    final perp = Offset(-dir.dy, dir.dx);
    c.drawLine(tip, tip + back * len + perp * (len * 0.6), paint);
    c.drawLine(tip, tip + back * len - perp * (len * 0.6), paint);
  }

  void _text(Canvas c, String s, Offset center, double opacity) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: _yellow.withOpacity(opacity),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  Offset _lerp(Offset a, Offset b, double t) => Offset.lerp(a, b, t)!;

  Offset _unit(Offset v) {
    final d = v.distance;
    return d == 0 ? Offset.zero : Offset(v.dx / d, v.dy / d);
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.progress != progress;
}
