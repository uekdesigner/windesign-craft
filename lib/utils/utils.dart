// lib/utils/utils.dart
import 'dart:ui';
import '../models/shape_spec.dart';

// =============================================================================
// CROP (KIRPMA) FONKSİYONLARI
// =============================================================================

/// Köşelerden kırpılmış poligonun noktalarını hesaplar
List<Offset> buildCropPolygon(
  double W,
  double H,
  double L,
  double T,
  double R,
  double B,
) {
  final pts = <Offset>[];

  // Sol-üst köşe bölgesi
  if (L > 0 && T > 0) {
    pts.add(Offset(0, L));
    pts.add(Offset(T, 0));
  } else {
    pts.add(const Offset(0, 0));
  }

  // Sağ-üst köşe bölgesi
  if (R > 0 && T > 0) {
    pts.add(Offset(W - T, 0));
    pts.add(Offset(W, R));
  } else {
    pts.add(Offset(W, 0));
  }

  // Sağ-alt köşe bölgesi
  if (R > 0 && B > 0) {
    pts.add(Offset(W, H - R));
    pts.add(Offset(W - B, H));
  } else {
    pts.add(Offset(W, H));
  }

  // Sol-alt köşe bölgesi
  if (L > 0 && B > 0) {
    pts.add(Offset(B, H));
    pts.add(Offset(0, H - L));
  } else {
    pts.add(Offset(0, H));
  }

  return pts;
}

/// Kırpma değerlerini doğrular
String? validateCropValues(
  double W,
  double H,
  double L,
  double T,
  double R,
  double B,
) {
  if (L < 0 || T < 0 || R < 0 || B < 0) {
    return "Negatif değer girilemez.";
  }

  if (L + R >= W) {
    return "Sol + Sağ değerleri genişlikten büyük olamaz.";
  }

  if (T + B >= H) {
    return "Üst + Alt değerleri yükseklikten büyük olamaz.";
  }

  return null;
}

// =============================================================================
// GEOMETRİK HESAPLAMA FONKSİYONLARI
// =============================================================================

/// Nokta listesinden sınırlayıcı kutu boyutunu hesaplar
Size calculateBoundingBox(List<Offset> points) {
  if (points.isEmpty) return Size.zero;

  final minX = points.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
  final maxX = points.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
  final minY = points.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
  final maxY = points.map((p) => p.dy).reduce((a, b) => a > b ? a : b);

  return Size(maxX - minX, maxY - minY);
}

/// İki nokta arasındaki mesafeyi hesaplar
double calculateDistance(Offset a, Offset b) {
  final dx = a.dx - b.dx;
  final dy = a.dy - b.dy;
  return (dx * dx + dy * dy);
}

// =============================================================================
// KOORDİNAT DÖNÜŞÜM FONKSİYONLARI
// =============================================================================

/// Pixel koordinatını MM koordinatına dönüştürür
Offset convertPxToMm(Offset pxPos, Size canvasSize, Size shapeSizeMm) {
  final scaleX = canvasSize.width / shapeSizeMm.width;
  final scaleY = canvasSize.height / shapeSizeMm.height;
  final scale = scaleX < scaleY ? scaleX : scaleY;

  final dx = (canvasSize.width - shapeSizeMm.width * scale) / 2;
  final dy = (canvasSize.height - shapeSizeMm.height * scale) / 2;

  final shifted = pxPos - Offset(dx, dy);
  return Offset(shifted.dx / scale, shifted.dy / scale);
}

/// MM koordinatını Pixel koordinatına dönüştürür
Offset convertMmToPx(Offset mmPos, Size canvasSize, Size shapeSizeMm) {
  final scaleX = canvasSize.width / shapeSizeMm.width;
  final scaleY = canvasSize.height / shapeSizeMm.height;
  final scale = scaleX < scaleY ? scaleX : scaleY;

  final dx = (canvasSize.width - shapeSizeMm.width * scale) / 2;
  final dy = (canvasSize.height - shapeSizeMm.height * scale) / 2;

  return Offset(mmPos.dx * scale + dx, mmPos.dy * scale + dy);
}

/// Canvas ölçek faktörünü hesaplar
double calculateScaleFactor(Size canvasSize, Size contentSize) {
  final scaleX = canvasSize.width / contentSize.width;
  final scaleY = canvasSize.height / contentSize.height;
  return scaleX < scaleY ? scaleX : scaleY;
}

// =============================================================================
// MATEMATİKSEL YARDIMCI FONKSİYONLARI
// =============================================================================

/// Değeri belirli aralıkta sınırlandırır
double clamp(double value, double min, double max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

/// Milimetreyi metreye çevirir
double mmToM(double mm) => mm / 1000.0;

/// Metreyi milimetreye çevirir
double mToMm(double m) => m * 1000.0;
