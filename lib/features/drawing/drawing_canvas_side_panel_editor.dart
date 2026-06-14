// lib/features/drawing/drawing_canvas_side_panel_editor.dart
//
// _DrawingCanvasPageState için mixin — yan panel bölüm editörü metodları.
// SectionEditorDialog'u SideAttachment verisiyle açar ve sonucu uygular.
//
// KURULUM:
//   drawing_canvas_page.dart içinde class tanımına mixin ekle:
//
//     class _DrawingCanvasPageState extends ConsumerState<DrawingCanvasPage>
//         with SidePanelEditorMixin {          // ← bu satır
//
//   Ve bu dosyayı import et:
//     import 'drawing_canvas_side_panel_editor.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/shape_spec.dart';
import '../../shared/dialogs/section_editor_dialog.dart';
import 'drawing_canvas_page.dart';
import 'providers/drawing_controller_provider.dart';
import 'tools/gap_calculator.dart';
import '../drawing/providers/drawing_controller_side_panel.dart';

mixin SidePanelEditorMixin on ConsumerState<DrawingCanvasPage> {
  // ─── Yardımcı: provider parametresi ─────────────────────────────────────────

  ({String projectId, String drawingId}) get _providerParams =>
      (projectId: widget.projectId, drawingId: widget.drawingId);

  // ─── Yan panel yatay bölüm editörü ──────────────────────────────────────────

  /// Yan panele yatay uzun çizgi eklenince veya mevcut çizgiye tıklanınca açılır.
  void showSidePanelHorizontalEditor(
    String side,
    SideAttachment attach,
    InternalElement? element,
  ) async {
    if (!mounted) return;

    final controllerState = ref.read(
      drawingControllerProvider(_providerParams),
    );
    final controller = ref.read(
      drawingControllerProvider(_providerParams).notifier,
    );

    if (controllerState.currentShape == null) return;
    final spec = controllerState.currentShape!;

    // Güncel attach'ı spec'ten al
    final currentAttach = spec.sideAttachments.firstWhere(
      (a) => a.side == side,
      orElse: () => attach,
    );

    final horizontalLines =
        currentAttach.internalElements
            .where(
              (e) =>
                  e.type == InternalElementType.horizontalLine &&
                  e.properties['isShort'] != true,
            )
            .toList()
          ..sort((a, b) => a.position.dy.compareTo(b.position.dy));

    // element null veya bulunamazsa selectedIndex=0 kullan
    final lineIndex = element != null
        ? horizontalLines.indexWhere((l) => l.id == element.id)
        : -1;
    final selectedIdx = lineIndex == -1 ? 0 : lineIndex;

    final gaps = GapCalculator.calculateGapsFromSize(
      currentAttach.height,
      horizontalLines,
    );

    final shortHLines = currentAttach.internalElements
        .where(
          (e) =>
              e.type == InternalElementType.horizontalLine &&
              e.properties['isShort'] == true,
        )
        .toList();

    // Kayar bottom sheet olarak aç
    final result = await SectionEditorDialog.showSliding(
      context,
      axis: SectionAxis.horizontal,
      shapeSpec: spec,
      totalSize: currentAttach.height,
      initialGaps: gaps,
      shortLines: shortHLines,
      selectedLineIndex: selectedIdx,
      onShortLineChanged: (id, newY) {
        controller.updateSideAttachShortHorizontalLine(side, id, newY);
      },
    );

    if (result == null || !mounted) return;

    // Async sonrası güncel spec'i oku
    final latestSpec = ref
        .read(drawingControllerProvider(_providerParams))
        .currentShape;
    if (latestSpec == null) return;

    final latestAttach = latestSpec.sideAttachments.firstWhere(
      (a) => a.side == side,
      orElse: () => currentAttach,
    );

    final latestLines = latestAttach.internalElements
        .where(
          (e) =>
              e.type == InternalElementType.horizontalLine &&
              e.properties['isShort'] != true,
        )
        .toList();

    final updatedAttach = horizontalLines.isEmpty && result.length > 1
        ? GapCalculator.createHorizontalLinesInAttachment(latestAttach, result)
        : GapCalculator.applyGapsToAttachment(
            latestAttach,
            latestLines,
            result,
          );

    controller.updateSideAttachment(side, updatedAttach);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yan panel yatay bölümler güncellendi'),
          duration: Duration(milliseconds: 800),
        ),
      );
    }
  }

  // ─── Yan panel dikey bölüm editörü ──────────────────────────────────────────

  /// Yan panele dikey uzun çizgi eklenince veya mevcut çizgiye tıklanınca açılır.
  void showSidePanelVerticalEditor(
    String side,
    SideAttachment attach,
    InternalElement? element,
  ) async {
    if (!mounted) return;

    final controllerState = ref.read(
      drawingControllerProvider(_providerParams),
    );
    final controller = ref.read(
      drawingControllerProvider(_providerParams).notifier,
    );

    if (controllerState.currentShape == null) return;
    final spec = controllerState.currentShape!;

    final currentAttach = spec.sideAttachments.firstWhere(
      (a) => a.side == side,
      orElse: () => attach,
    );

    final verticalLines =
        currentAttach.internalElements
            .where(
              (e) =>
                  e.type == InternalElementType.verticalLine &&
                  e.properties['isShort'] != true,
            )
            .toList()
          ..sort((a, b) => a.position.dx.compareTo(b.position.dx));

    // element null veya bulunamazsa selectedIndex=0 kullan
    final lineIndex = element != null
        ? verticalLines.indexWhere((l) => l.id == element.id)
        : -1;
    final selectedIdx = lineIndex == -1 ? 0 : lineIndex;

    final gaps = GapCalculator.calculateVerticalGapsFromSize(
      currentAttach.width,
      verticalLines,
    );

    final shortVLines = currentAttach.internalElements
        .where(
          (e) =>
              e.type == InternalElementType.verticalLine &&
              e.properties['isShort'] == true,
        )
        .toList();

    final result = await SectionEditorDialog.showSliding(
      context,
      axis: SectionAxis.vertical,
      shapeSpec: spec,
      totalSize: currentAttach.width,
      initialGaps: gaps,
      shortLines: shortVLines,
      selectedLineIndex: selectedIdx,
      onShortLineChanged: (id, newX) {
        controller.updateSideAttachShortVerticalLine(side, id, newX);
      },
    );

    if (result == null || !mounted) return;

    final latestSpec = ref
        .read(drawingControllerProvider(_providerParams))
        .currentShape;
    if (latestSpec == null) return;

    final latestAttach = latestSpec.sideAttachments.firstWhere(
      (a) => a.side == side,
      orElse: () => currentAttach,
    );

    final latestLines = latestAttach.internalElements
        .where(
          (e) =>
              e.type == InternalElementType.verticalLine &&
              e.properties['isShort'] != true,
        )
        .toList();

    final updatedAttach = verticalLines.isEmpty && result.length > 1
        ? GapCalculator.createVerticalLinesInAttachment(latestAttach, result)
        : GapCalculator.applyVerticalGapsToAttachment(
            latestAttach,
            latestLines,
            result,
          );

    controller.updateSideAttachment(side, updatedAttach);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yan panel dikey bölümler güncellendi'),
          duration: Duration(milliseconds: 800),
        ),
      );
    }
  }

  // ─── Yan panele element ekleme + editör tetikleyici ──────────────────────────

  /// Mevcut _addElementToSidePanel'ın yerini alır.
  /// Uzun çizgi eklenince editörü otomatik açar.
  void addElementToSidePanelWithEditor(
    String side,
    SideAttachment oldAttach,
    InternalElement newElement,
  ) {
    final controllerState = ref.read(
      drawingControllerProvider(_providerParams),
    );
    final controller = ref.read(
      drawingControllerProvider(_providerParams).notifier,
    );

    if (controllerState.currentShape == null) return;
    final spec = controllerState.currentShape!;

    // Element'i attach'a ekle
    final updatedAttachments = spec.sideAttachments.map((a) {
      if (a.side == side) {
        return a.copyWith(
          internalElements: [...a.internalElements, newElement],
        );
      }
      return a;
    }).toList();

    controller.updateShape(
      controllerState.selectedIndex,
      spec.copyWith(sideAttachments: updatedAttachments),
    );

    // Sadece uzun çizgiler için editörü aç
    final isLongH =
        newElement.type == InternalElementType.horizontalLine &&
        newElement.properties['isShort'] != true;
    final isLongV =
        newElement.type == InternalElementType.verticalLine &&
        newElement.properties['isShort'] != true;

    if (!mounted || (!isLongH && !isLongV)) return;

    // updateShape sonrası bir frame bekle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final freshSpec = ref
          .read(drawingControllerProvider(_providerParams))
          .currentShape;
      if (freshSpec == null) return;

      final freshAttach = freshSpec.sideAttachments.firstWhere(
        (a) => a.side == side,
        orElse: () => oldAttach,
      );

      if (isLongH) {
        showSidePanelHorizontalEditor(side, freshAttach, newElement);
      } else {
        showSidePanelVerticalEditor(side, freshAttach, newElement);
      }
    });
  }
}
