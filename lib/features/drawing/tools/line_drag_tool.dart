import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/drawing_controller_provider.dart';
import '../providers/tool_mode_provider.dart';

/// Sadece uzun yatay/dikey çizgilerin sürükle-bırak (GestureDetector/Pan) mantığı.
/// Preview, sınır kontrolü, bırakınca ekleme, tool reset ve SnackBar burada.
class LineDragTool {
  final WidgetRef ref;
  final BuildContext context;
  final String projectId;
  final String drawingId;

  /// Preview state'ini güncellemek için callback'ler.
  /// - [onHorizontalPreviewChanged] : Yatay çizgi önizlemesinin Y pozisyonu değişince tetiklenir.
  ///   null gelirse önizleme gizlenir (sınır dışına çıkıldı demektir).
  /// - [onVerticalPreviewChanged]   : Dikey çizgi önizlemesinin X pozisyonu değişince tetiklenir.
  ///   null gelirse önizleme gizlenir.
  /// - [onClearPreview]             : Pan hareketi bitince her iki önizlemeyi de temizler.
  final ValueChanged<double?> onHorizontalPreviewChanged;
  final ValueChanged<double?> onVerticalPreviewChanged;
  final VoidCallback onClearPreview;

  LineDragTool({
    required this.ref,
    required this.context,
    required this.projectId,
    required this.drawingId,
    required this.onHorizontalPreviewChanged,
    required this.onVerticalPreviewChanged,
    required this.onClearPreview,
  });

  // ─────────────────────────────────────────────
  // YATAY ÇİZGİ (Sürükle-Bırak)
  // ─────────────────────────────────────────────

  /// Kullanıcı parmağını ekranda sürüklerken her frame'de çağrılır.
  /// Parmağın ekran koordinatını (localPosition) mm cinsine çevirir ve
  /// yatay çizgi önizlemesinin Y pozisyonunu günceller.
  ///
  /// Parametreler:
  /// - [localPosition] : GestureDetector'dan gelen widget-local piksel koordinatı.
  /// - [screenToMm]    : Piksel koordinatını mm koordinatına çeviren dönüşüm fonksiyonu.
  ///
  /// Davranış:
  /// - Hesaplanan Y değeri şeklin dikey sınırları içindeyse (0 <= mmY <= baseHeight)
  ///   [onHorizontalPreviewChanged] ile yeni Y pozisyonu bildirilir; önizleme çizgisi çizilir.
  /// - Parmak sınırın dışına çıkarsa null gönderilir; önizleme gizlenir.
  /// - Aktif şekil (currentShape) henüz yoksa hiçbir işlem yapılmaz, erken çıkılır.
  void onHorizontalPanUpdate(
    Offset localPosition,
    Offset Function(Offset screenPos) screenToMm,
  ) {
    final mmPos = screenToMm(localPosition);
    final mmY = mmPos.dy;

    final spec = ref
        .read(
          drawingControllerProvider((
            projectId: projectId,
            drawingId: drawingId,
          )),
        )
        .currentShape;

    if (spec == null) return;

    if (mmY >= 0 && mmY <= spec.baseHeight) {
      onHorizontalPreviewChanged(mmY);
    } else {
      onHorizontalPreviewChanged(null);
    }
  }

  /// Kullanıcı parmağını ekrandan kaldırınca çağrılır.
  /// Geçerli bir önizleme pozisyonu varsa yatay çizgiyi kalıcı olarak ekler,
  /// ardından tool modunu sıfırlar ve kullanıcıya bilgi SnackBar'ı gösterir.
  ///
  /// Parametreler:
  /// - [previewMmY]          : Sürükleme sırasında hesaplanan son geçerli Y değeri (mm).
  ///   null ise şekil sınırı dışında bırakılmış demektir; çizgi eklenmez.
  /// - [addHorizontalLineAtY]: Controller üzerinde yatay çizgiyi kalıcı ekleyen fonksiyon.
  ///
  /// Davranış:
  /// - [previewMmY] geçerliyse (null değilse):
  ///   1. [addHorizontalLineAtY] ile çizgi kalıcı eklenir.
  ///   2. [toolModeProvider] resetlenir; kullanıcı otomatik seçim moduna geçer.
  ///   3. 600ms süreli bilgi SnackBar'ı gösterilir.
  /// - Her iki durumda da [onClearPreview] ile önizleme temizlenir.
  void onHorizontalPanEnd(
    double? previewMmY,
    void Function(double mmY) addHorizontalLineAtY,
  ) {
    if (previewMmY != null) {
      addHorizontalLineAtY(previewMmY);
      ref.read(toolModeProvider.notifier).reset();
    }
    onClearPreview();
  }

  // ─────────────────────────────────────────────
  // DİKEY ÇİZGİ (Sürükle-Bırak)
  // ─────────────────────────────────────────────

  /// Kullanıcı parmağını ekranda sürüklerken her frame'de çağrılır.
  /// Parmağın ekran koordinatını (localPosition) mm cinsine çevirir ve
  /// dikey çizgi önizlemesinin X pozisyonunu günceller.
  ///
  /// Parametreler:
  /// - [localPosition] : GestureDetector'dan gelen widget-local piksel koordinatı.
  /// - [screenToMm]    : Piksel koordinatını mm koordinatına çeviren dönüşüm fonksiyonu.
  ///
  /// Davranış:
  /// - Hesaplanan X değeri şeklin yatay sınırları içindeyse (0 <= mmX <= baseWidth)
  ///   [onVerticalPreviewChanged] ile yeni X pozisyonu bildirilir; önizleme çizgisi çizilir.
  /// - Parmak sınırın dışına çıkarsa null gönderilir; önizleme gizlenir.
  /// - Aktif şekil (currentShape) henüz yoksa hiçbir işlem yapılmaz, erken çıkılır.
  void onVerticalPanUpdate(
    Offset localPosition,
    Offset Function(Offset screenPos) screenToMm,
  ) {
    final mmPos = screenToMm(localPosition);
    final mmX = mmPos.dx;

    final spec = ref
        .read(
          drawingControllerProvider((
            projectId: projectId,
            drawingId: drawingId,
          )),
        )
        .currentShape;

    if (spec == null) return;

    if (mmX >= 0 && mmX <= spec.baseWidth) {
      onVerticalPreviewChanged(mmX);
    } else {
      onVerticalPreviewChanged(null);
    }
  }

  /// Kullanıcı parmağını ekrandan kaldırınca çağrılır.
  /// Geçerli bir önizleme pozisyonu varsa dikey çizgiyi kalıcı olarak ekler,
  /// ardından tool modunu sıfırlar ve kullanıcıya bilgi SnackBar'ı gösterir.
  ///
  /// Parametreler:
  /// - [previewMmX]         : Sürükleme sırasında hesaplanan son geçerli X değeri (mm).
  ///   null ise şekil sınırı dışında bırakılmış demektir; çizgi eklenmez.
  /// - [addVerticalLineAtX] : Controller üzerinde dikey çizgiyi kalıcı ekleyen fonksiyon.
  ///
  /// Davranış:
  /// - [previewMmX] geçerliyse (null değilse):
  ///   1. [addVerticalLineAtX] ile çizgi kalıcı eklenir.
  ///   2. [toolModeProvider] resetlenir; kullanıcı otomatik seçim moduna geçer.
  ///   3. 600ms süreli bilgi SnackBar'ı gösterilir.
  /// - Her iki durumda da [onClearPreview] ile önizleme temizlenir.
  void onVerticalPanEnd(
    double? previewMmX,
    void Function(double mmX) addVerticalLineAtX,
  ) {
    if (previewMmX != null) {
      addVerticalLineAtX(previewMmX);
      ref.read(toolModeProvider.notifier).reset();
    }
    onClearPreview();
  }
}
