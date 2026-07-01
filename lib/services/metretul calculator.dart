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
          kanat += (e.size.width + e.size.height) * 2;
          kanatSayisi += 1;
          break;
        case InternalElementType.parallelLines:
        case InternalElementType.slideArrow:
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

  /// Poligon noktalarının çevresini (ardışık noktalar arası Öklid mesafesi
  /// toplamı, kapalı poligon) hesaplar. Köşe kırpmaları (çapraz kesimler)
  /// varsa bu, düz (width+height)*2'den farklı ve doğru sonucu verir.
  static double _polygonPerimeter(List<Offset> points) {
    if (points.length < 2) return 0;
    double total = 0;
    for (int i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      total += (a - b).distance;
    }
    return total;
  }
}
