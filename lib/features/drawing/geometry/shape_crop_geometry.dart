import 'dart:math' as math;
import 'dart:ui';
import '../../../models/shape_spec.dart';

/// Ana şeklin kırpma (crop), kenar bulma ve boyut hesapları.
/// Sadece ana dörtgenle ilgilenir. Yan panel, koordinat, eksen hesabı burada yok.
class ShapeCropGeometry {
  const ShapeCropGeometry._();

  // ── KENAR BULMA: Verilen X veya Y'de ana şeklin sınırı kaç mm? ──

  /// Verilen bir X koordinatında şeklin ÜST kenarının Y değerini döndürür.
  ///
  /// Şeklin köşeleri kırpık (chamfer) olabilir. Bu metot, X konumuna göre
  /// hangi kırpma bölgesinde olduğumuzu belirler ve o bölgeye karşılık gelen
  /// üst kenarın Y değerini doğrusal interpolasyon (lerp) ile hesaplar.
  ///
  /// Üç durum söz konusudur:
  /// - [x] sol üst kırpma bölgesi içindeyse (x <= topLeftX):
  ///   Sol üst köşe kırpmasının eğim çizgisi üzerinde Y hesaplanır.
  ///   topLeftX == 0 ise kırpma yok demektir, doğrudan tam köşe Y'si döner.
  ///
  /// - [x] sağ üst kırpma bölgesi içindeyse (x >= baseWidth - topRightX):
  ///   Sağ üst köşe kırpmasının eğim çizgisi üzerinde Y hesaplanır.
  ///   topRightX == 0 ise kırpma yok demektir, doğrudan tam köşe Y'si döner.
  ///
  /// - İkisi de değilse: Şeklin tam üst kenarında olduğu anlamına gelir,
  ///   Y değeri olarak [spec.baseHeight] döner (üst kenar düz çizgidir).
  ///
  /// Koordinat sistemi: Y ekseni aşağıdan yukarıya doğru artar.
  /// Yani baseHeight, en üst noktayı temsil eder.
  static double topYAtX(ShapeSpec spec, double x) {
    if (x <= spec.topLeftX) {
      if (spec.topLeftX == 0) return spec.baseHeight - spec.topLeftY;
      final ratio = x / spec.topLeftX;
      return (spec.baseHeight - spec.topLeftY) + (spec.topLeftY * ratio);
    } else if (x >= spec.baseWidth - spec.topRightX) {
      final remaining = spec.baseWidth - x;
      if (spec.topRightX == 0) return spec.baseHeight - spec.topRightY;
      final ratio = remaining / spec.topRightX;
      return (spec.baseHeight - spec.topRightY) + (spec.topRightY * ratio);
    }
    return spec.baseHeight;
  }

  /// Verilen bir X koordinatında şeklin ALT kenarının Y değerini döndürür.
  ///
  /// [topYAtX] ile aynı mantığı izler; bu sefer alt köşe kırpmalarına göre
  /// hesaplama yapılır. Y ekseni aşağıdan yukarıya arttığından alt kenar
  /// Y değerleri küçük sayılardır (0'a yakın).
  ///
  /// Üç durum söz konusudur:
  /// - [x] sol alt kırpma bölgesi içindeyse (x <= bottomLeftX):
  ///   Sol alt köşe kırpmasının eğim çizgisi üzerinde Y hesaplanır.
  ///   bottomLeftX == 0 ise kırpma yok, doğrudan bottomLeftY döner.
  ///
  /// - [x] sağ alt kırpma bölgesi içindeyse (x >= baseWidth - bottomRightX):
  ///   Sağ alt köşe kırpmasının eğim çizgisi üzerinde Y hesaplanır.
  ///   bottomRightX == 0 ise kırpma yok, doğrudan bottomRightY döner.
  ///
  /// - İkisi de değilse: Şeklin tam alt kenarıdır, Y = 0 döner.
  static double bottomYAtX(ShapeSpec spec, double x) {
    if (x <= spec.bottomLeftX) {
      if (spec.bottomLeftX == 0) return spec.bottomLeftY;
      final ratio = x / spec.bottomLeftX;
      return spec.bottomLeftY * (1 - ratio);
    } else if (x >= spec.baseWidth - spec.bottomRightX) {
      final remaining = spec.baseWidth - x;
      if (spec.bottomRightX == 0) return spec.bottomRightY;
      final ratio = remaining / spec.bottomRightX;
      return spec.bottomRightY * (1 - ratio);
    }
    return 0;
  }

  /// Verilen bir Y koordinatında şeklin SOL kenarının X değerini döndürür.
  ///
  /// Sol kenarda iki kırpma bölgesi olabilir: sol üst ve sol alt.
  /// Bu metot Y konumunu bu iki bölgeye göre değerlendirir ve
  /// doğrusal interpolasyon ile sol sınırın X değerini hesaplar.
  ///
  /// Üç durum söz konusudur:
  /// - [y] sol üst kırpma bölgesi içindeyse (y >= baseHeight - topLeftY):
  ///   Üst sol kırpmanın eğim çizgisi üzerinde X hesaplanır.
  ///   ratio arttıkça X değeri topLeftX'e yaklaşır (köşeye doğru).
  ///
  /// - [y] sol alt kırpma bölgesi içindeyse (y <= bottomLeftY):
  ///   Alt sol kırpmanın eğim çizgisi üzerinde X hesaplanır.
  ///   ratio arttıkça X değeri sıfıra doğru azalır.
  ///
  /// - İkisi de değilse: Düz sol kenardayız, X = 0 döner.
  static double leftXAtY(ShapeSpec spec, double y) {
    final topYAtLeft = spec.baseHeight - spec.topLeftY;
    if (spec.topLeftY > 0 && y >= topYAtLeft) {
      final ratio = (y - topYAtLeft) / spec.topLeftY;
      return spec.topLeftX * ratio;
    } else if (spec.bottomLeftY > 0 && y <= spec.bottomLeftY) {
      final ratio = y / spec.bottomLeftY;
      return spec.bottomLeftX * (1 - ratio);
    }
    return 0;
  }

  /// Verilen bir Y koordinatında şeklin SAĞ kenarının X değerini döndürür.
  ///
  /// [leftXAtY] ile simetrik mantıkta çalışır; bu sefer sağ köşe
  /// kırpmalarına göre sağ sınırın X değeri hesaplanır.
  ///
  /// Üç durum söz konusudur:
  /// - [y] sağ üst kırpma bölgesi içindeyse (y >= baseHeight - topRightY):
  ///   Üst sağ kırpmanın eğim çizgisi üzerinde X hesaplanır.
  ///   ratio arttıkça X değeri (baseWidth - topRightX)'e yaklaşır.
  ///
  /// - [y] sağ alt kırpma bölgesi içindeyse (y <= bottomRightY):
  ///   Alt sağ kırpmanın eğim çizgisi üzerinde X hesaplanır.
  ///   ratio arttıkça X değeri (baseWidth - bottomRightX)'e doğru kayar.
  ///
  /// - İkisi de değilse: Düz sağ kenardayız, X = baseWidth döner.
  static double rightXAtY(ShapeSpec spec, double y) {
    final topYAtRight = spec.baseHeight - spec.topRightY;
    if (spec.topRightY > 0 && y >= topYAtRight) {
      final ratio = (y - topYAtRight) / spec.topRightY;
      return spec.baseWidth - (spec.topRightX * ratio);
    } else if (spec.bottomRightY > 0 && y <= spec.bottomRightY) {
      final ratio = y / spec.bottomRightY;
      return spec.baseWidth - (spec.bottomRightX * (1 - ratio));
    }
    return spec.baseWidth;
  }

  // ── BOYUT HESAPLARI ──

  /// Sadece ana şeklin (yan paneller hariç) kaplama alanını [Size] olarak döndürür.
  ///
  /// Kırpma (crop/chamfer) dahil tüm köşe kesintileri zaten [spec.boundingSize]
  /// içinde hesaplanmış olarak gelir. Bu metot yalnızca o değeri iletir;
  /// herhangi bir ek hesap yapmaz.
  ///
  /// Yan paneller bu hesabın dışındadır. Yan paneller dahil toplam alan için
  /// [totalBounds] metodunu kullanın.
  static Size mainShapeBounds(ShapeSpec spec) => spec.boundingSize;

  /// Ana şekil ve tüm yan panellerin birlikte kapladığı toplam alanı [Size] olarak döndürür.
  ///
  /// Canvas'ın ne kadar alana ihtiyaç duyduğunu belirlemek için kullanılır.
  ///
  /// Hesaplama adımları:
  /// 1. Yan panel yoksa [spec.boundingSize] doğrudan döner, ek işlem yapılmaz.
  ///
  /// 2. Yan paneller varsa her biri için:
  ///    - 'left' tarafındaki panellerin genişlikleri toplanarak [leftExtra] bulunur
  ///      (birden fazla sol panel varsa en geniş olan alınır).
  ///    - 'right' tarafındaki paneller için aynı işlem [rightExtra] ile yapılır.
  ///    - Tüm panellerin yükseklikleri ana şekil yüksekliği ile karşılaştırılarak
  ///      [maxHeight] (en büyük yükseklik) belirlenir.
  ///
  /// 3. Sonuç: genişlik = baseBounds.width + leftExtra + rightExtra,
  ///           yükseklik = maxHeight
  static Size totalBounds(ShapeSpec spec) {
    final baseBounds = spec.boundingSize;
    if (spec.sideAttachments.isEmpty) return baseBounds;

    double leftExtra = 0, rightExtra = 0;
    double maxHeight = baseBounds.height;

    for (final attach in spec.sideAttachments) {
      if (attach.side == 'left') {
        leftExtra = math.max(leftExtra, attach.width);
      } else {
        rightExtra = math.max(rightExtra, attach.width);
      }
      maxHeight = math.max(maxHeight, attach.height);
    }

    return Size(baseBounds.width + leftExtra + rightExtra, maxHeight);
  }
}
