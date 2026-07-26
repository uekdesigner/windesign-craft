import 'package:flutter/material.dart' show Offset;
import '../models/shape_spec.dart';

/// Tek bir ShapeSpec (veya bir çizimdeki tüm shape'ler) için
/// metretül (profil metrajı) sonucu.
class MetretulResult {
  final double
  sabitIskeletMm; // Kasa çevresi + iç kayıtlar + lineGrid + side attachment'lar
  final double
  kanatMm; // Tüm açılır kanatların (triangle) kendi çerçeve çevresi
  final int kanatSayisi; // Aksesuar (ispanyolet/menteşe) seti sayısı

  const MetretulResult({
    required this.sabitIskeletMm,
    required this.kanatMm,
    required this.kanatSayisi,
  });

  double get toplamMm => sabitIskeletMm + kanatMm;

  double get sabitIskeletM => sabitIskeletMm / 1000;
  double get kanatM => kanatMm / 1000;
  double get toplamM => toplamMm / 1000;

  MetretulResult operator +(MetretulResult other) => MetretulResult(
    sabitIskeletMm: sabitIskeletMm + other.sabitIskeletMm,
    kanatMm: kanatMm + other.kanatMm,
    kanatSayisi: kanatSayisi + other.kanatSayisi,
  );

  static const zero = MetretulResult(
    sabitIskeletMm: 0,
    kanatMm: 0,
    kanatSayisi: 0,
  );

  /// Fire payı uygulanmış toplam (mm).
  double toplamFireliMm(double fireOrani) => toplamMm * (1 + fireOrani);
}

class MetretulCalculator {
  /// Tek bir shape için sabit iskelet + kanat metrajını hesaplar.
  static MetretulResult calculateForShape(ShapeSpec spec) {
    double sabit = 0;
    double kanat = 0;
    int kanatSayisi = 0;

    // 1) Ana panel çevresi — köşe kırpmaları varsa gerçek poligon
    //    mesafesi üzerinden (diagonal kesimler dahil), yoksa düz dikdörtgen.
    sabit += _polygonPerimeter(spec.getPolygonPoints());

    // 2) Ana paneldeki iç elemanlar (kayıtlar, lineGrid, triangle/kanat)
    final mainResult = _sumInternalElements(spec.internalElements);
    sabit += mainResult.sabitIskeletMm;
    kanat += mainResult.kanatMm;
    kanatSayisi += mainResult.kanatSayisi;

    // 3) Side attachment'lar (ek kasalar) — kendi çevreleri + kendi iç elemanları
    for (final attach in spec.sideAttachments) {
      sabit += (attach.width + attach.height) * 2;
      final attachResult = _sumInternalElements(attach.internalElements);
      sabit += attachResult.sabitIskeletMm;
      kanat += attachResult.kanatMm;
      kanatSayisi += attachResult.kanatSayisi;
    }

    return MetretulResult(
      sabitIskeletMm: sabit,
      kanatMm: kanat,
      kanatSayisi: kanatSayisi,
    );
  }

  /// Bir çizimdeki (Drawing.shapes) tüm shape'lerin toplamı.
  static MetretulResult calculateForShapes(List<ShapeSpec> shapes) {
    var total = MetretulResult.zero;
    for (final s in shapes) {
      total += calculateForShape(s);
    }
    return total;
  }

  /// internalElements listesini sabit/kanat olarak ayırıp toplar.
  /// horizontalLine / verticalLine -> sabit iskelet (uzunluk)
  /// lineGrid (profil kaplı camsız) -> sabit iskelet (kendi çevresi)
  /// triangle (açılır kanat göstergesi) -> kanat metrajı (kendi çevresi) + 1 aksesuar
  /// parallelLines / slideArrow / dotGrid -> hesaba katılmaz
  static MetretulResult _sumInternalElements(List<InternalElement> elements) {
    double sabit = 0;
    double kanat = 0;
    int kanatSayisi = 0;

    for (final e in elements) {
      switch (e.type) {
        case InternalElementType.horizontalLine:
          sabit += e.size.width;
          break;
        case InternalElementType.verticalLine:
          sabit += e.size.height;
          break;
        case InternalElementType.lineGrid:
          sabit += (e.size.width + e.size.height) * 2;
          break;
        case InternalElementType.triangle:
          // Yukarı açılım (üst menteşe / vasistas) metretüle katılmaz.
          // Sol ve sağ açılım kanat olarak sayılır.
          final direction = e.properties['direction'] as String?;
          if (direction != 'up') {
            kanat += (e.size.width + e.size.height) * 2;
            kanatSayisi += 1;
          }
          break;
        case InternalElementType.slideArrow:
          // Sürme sistemi (sola/sağa) — kanat profili olarak sayılır.
          kanat += (e.size.width + e.size.height) * 2;
          kanatSayisi += 1;
          break;
        case InternalElementType.parallelLines:
        case InternalElementType.dotGrid:
          break;
      }
    }

    return MetretulResult(
      sabitIskeletMm: sabit,
      kanatMm: kanat,
      kanatSayisi: kanatSayisi,
    );
  }

  /// Poligon noktalarını doğru sırayla (köşeler arası kenarlar) bağlayarak
  /// çevreyi hesaplar.
  /// getPolygonPoints() her köşe için 2 nokta üretir (kırpma noktaları).
  /// Doğru traversal: TL_top → TR_top → TR_right → BR_right → BR_bottom
  ///                  → BL_bottom → BL_left → TL_left → (kapalı)
  /// Yani indeks sırası: 0, 2, 3, 4, 5, 6, 7, 1
  static double _polygonPerimeter(List<Offset> points) {
    if (points.length < 2) return 0;

    final List<Offset> ordered;
    if (points.length == 8) {
      ordered = [
        points[0], // TL — top edge
        points[2], // TR — top edge
        points[3], // TR — right edge
        points[4], // BR — right edge
        points[5], // BR — bottom edge
        points[6], // BL — bottom edge
        points[7], // BL — left edge
        points[1], // TL — left edge
      ];
    } else {
      ordered = points;
    }

    double total = 0;
    for (int i = 0; i < ordered.length; i++) {
      final a = ordered[i];
      final b = ordered[(i + 1) % ordered.length];
      total += (a - b).distance;
    }
    return total;
  }
}
