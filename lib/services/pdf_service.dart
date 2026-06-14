// lib/services/pdf_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../models/drawing.dart';
import '../models/project.dart';
import '../models/shape_spec.dart';
import '../features/drawing/painters/quadrilateral_painter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Renk Sabitleri ───────────────────────────────────────────────────────────
// Border rengi: RGB(127,130,129)
const PdfColor _borderColor = PdfColor.fromInt(0xFF7F8281);
// Başlık arka fon rengi: RGB(83,83,83)
const PdfColor _headerBgColor = PdfColor.fromInt(0xFF535353);
// Başlık font rengi: beyaz
const PdfColor _headerFontColor = PdfColors.white;
// Footer font rengi: RGB(83,83,83)
const PdfColor _footerFontColor = PdfColor.fromInt(0xFF535353);
// Diğer tüm fontlar: siyah
const PdfColor _defaultFontColor = PdfColors.black;

// ─── Firma Bilgileri Modeli ───────────────────────────────────────────────────

class FirmaInfo {
  final String firmaAdi;
  final String telefon;
  final String adres;
  final String? logoPath;
  final String? email;

  const FirmaInfo({
    required this.firmaAdi,
    required this.telefon,
    required this.adres,
    this.logoPath,
    this.email,
  });
}

// ─── PDF Servisi ──────────────────────────────────────────────────────────────

class PdfService {
  static const String _yazilimAdi = 'WinDesign Craft Pro';
  static const String _ureticiFirma = 'UEK DESIGNER';
  static const String _ureticiFirmaMail = 'info@uekdesigner.com';
  static const String _ureticiFirmaTel = '+90 543 872 39 26';
  static const int _copyrightYil = 2026;

  // ─── ANA METOD ───────────────────────────────────────────────────────────────

  static Future<String> generateProjectPdf({
    required Project project,
    required List<Drawing> drawings,
    required FirmaInfo firma,
  }) async {
    final fontData = await rootBundle.load('assets/fonts/OpenSans.ttf');
    final font = pw.Font.ttf(fontData);
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: font),
    );

    pw.ImageProvider? logoImage;
    if (firma.logoPath != null) {
      final logoFile = File(firma.logoPath!);
      if (await logoFile.exists()) {
        final logoBytes = await logoFile.readAsBytes();
        logoImage = pw.MemoryImage(logoBytes);
      }
    }

    pdf.addPage(_buildCoverPage(project, drawings, firma, logoImage));

    for (final drawing in drawings) {
      for (int i = 0; i < drawing.shapes.length; i++) {
        final shape = drawing.shapes[i];
        final pIndex = i + 1;
        final pTotal = drawing.shapes.length;

        final imageBytes = await _renderShapeToPng(shape);
        pw.ImageProvider? shapeImage;
        if (imageBytes != null) {
          shapeImage = pw.MemoryImage(imageBytes);
        }

        pdf.addPage(
          _buildDrawingPage(
            drawing: drawing,
            shape: shape,
            pIndex: pIndex,
            pTotal: pTotal,
            project: project,
            firma: firma,
            logoImage: logoImage,
            shapeImage: shapeImage,
          ),
        );
      }
    }

    Directory outputDir;
    final externalDir = await getExternalStorageDirectory();
    if (externalDir != null) {
      outputDir = Directory('${externalDir.path}/WinDesignCraft');
    } else {
      outputDir = await getApplicationDocumentsDirectory();
    }
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }
    final safeName = project.name
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(' ', '_');
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final fileName = '${safeName}_$dateStr.pdf';
    final filePath = '${outputDir.path}/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
    final prefs = await SharedPreferences.getInstance();
    final savedPaths = prefs.getStringList('saved_pdfs') ?? [];
    savedPaths.insert(0, filePath);
    await prefs.setStringList('saved_pdfs', savedPaths);

    return filePath;
  }

  // ─── KAPAK SAYFASI ────────────────────────────────────────────────────────

  static pw.Page _buildCoverPage(
    Project project,
    List<Drawing> drawings,
    FirmaInfo firma,
    pw.ImageProvider? logoImage,
  ) {
    final date = DateTime.parse(project.createdAt);
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

    final toplamPencere = drawings.fold<int>(
      0,
      (sum, d) => sum + d.shapes.length,
    );

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _buildFirmaHeader(firma, logoImage, dateStr),
            pw.SizedBox(height: 40),
            pw.Center(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _borderColor, width: 1.5),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'TEKNİK ÖLÇÜ FORMU',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: _defaultFontColor,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            pw.SizedBox(height: 40),
            _buildInfoBox(
              title: 'MÜŞTERİ BİLGİLERİ',
              rows: [
                _InfoRow('Ad Soyad', project.name),
                _InfoRow('Telefon', _formatPhone(project.phone)),
                _InfoRow('Adres', project.address),
                if (project.description.isNotEmpty)
                  _InfoRow('Açıklama', project.description),
              ],
            ),
            pw.SizedBox(height: 20),
            _buildInfoBox(
              title: 'ÖZET',
              rows: [
                _InfoRow('Toplam Çizim Grubu', '${drawings.length}'),
                _InfoRow('Toplam Pencere', '$toplamPencere'),
                _InfoRow('Tarih', dateStr),
              ],
            ),
            pw.Spacer(),
            _buildFooter(),
          ],
        );
      },
    );
  }

  // ─── ÇİZİM SAYFASI ───────────────────────────────────────────────────────

  static pw.Page _buildDrawingPage({
    required Drawing drawing,
    required ShapeSpec shape,
    required int pIndex,
    required int pTotal,
    required Project project,
    required FirmaInfo firma,
    required pw.ImageProvider? logoImage,
    required pw.ImageProvider? shapeImage,
  }) {
    final date = DateTime.parse(drawing.createdAt);
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

    final locationParts = <String>[];
    if (drawing.location?.isNotEmpty == true)
      locationParts.add(drawing.location!);
    if (drawing.direction?.isNotEmpty == true)
      locationParts.add(drawing.direction!);
    final locationTitle = locationParts.isEmpty
        ? drawing.name
        : locationParts.join(' · ');

    final String? aciklama = shape.description?.isNotEmpty == true
        ? shape.description
        : null;

    final satirBir = <String>[];
    final satirIki = <String>[];
    final satirUc = <String>[];

    if (shape.systemName?.isNotEmpty == true)
      satirBir.add('Sistem: ${shape.systemName!}');
    if (shape.seriesName?.isNotEmpty == true)
      satirBir.add('Seri: ${shape.seriesName!}');
    if (shape.profileColor?.isNotEmpty == true)
      satirBir.add('Renk: ${_capitalize(shape.profileColor!)}');

    if (shape.glassSystem?.isNotEmpty == true)
      satirIki.add('Cam Sistemi: ${shape.glassSystem!}');
    if (shape.glassTone?.isNotEmpty == true)
      satirIki.add('Cam Tonu: ${shape.glassTone!}');

    if (shape.accessories.isNotEmpty)
      satirUc.add('Aksesuar: ${shape.accessories.join(', ')}');

    final hasTeknik =
        satirBir.isNotEmpty ||
        satirIki.isNotEmpty ||
        satirUc.isNotEmpty ||
        aciklama != null;

    double toplamGenislik = shape.baseWidth;
    double toplamYukseklik = shape.baseHeight;
    for (final a in shape.sideAttachments) {
      toplamGenislik += a.width;
      if (a.height > toplamYukseklik) toplamYukseklik = a.height;
    }
    final bool isLandscape = toplamGenislik > toplamYukseklik;

    return pw.Page(
      pageFormat: isLandscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _buildFirmaHeaderSmall(firma, logoImage, project.name, dateStr),

            pw.SizedBox(height: 5),
            pw.Divider(color: _borderColor, thickness: 0.5),
            pw.SizedBox(height: 4),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  locationTitle,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _defaultFontColor,
                    letterSpacing: 0.6,
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: pw.BoxDecoration(
                    color: _headerBgColor,
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.Text(
                    'P$pIndex / $pTotal',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _headerFontColor,
                    ),
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 5),

            pw.Expanded(
              flex: 75,
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _borderColor, width: 0.5),
                ),
                child: shapeImage != null
                    ? pw.Center(
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(12),
                          child: pw.Image(shapeImage, fit: pw.BoxFit.contain),
                        ),
                      )
                    : pw.Center(
                        child: pw.Text(
                          'Çizim yüklenemedi',
                          style: pw.TextStyle(
                            color: _defaultFontColor,
                            fontSize: 11,
                          ),
                        ),
                      ),
              ),
            ),

            pw.SizedBox(height: 5),

            if (hasTeknik) ...[
              _buildTeknikBilgilerYeni(
                satirBir: satirBir,
                satirIki: satirIki,
                satirUc: satirUc,
              ),
              pw.SizedBox(height: 4),
            ],

            if (aciklama != null) ...[
              _buildAciklamaBox(aciklama),
              pw.SizedBox(height: 4),
            ],

            _buildFooter(),
          ],
        );
      },
    );
  }

  // ─── YENİ TEKNİK BİLGİLER TABLOSU ───────────────────────────────────────

  static pw.Widget _buildTeknikBilgilerYeni({
    required List<String> satirBir,
    required List<String> satirIki,
    required List<String> satirUc,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderColor, width: 0.5),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
              color: _headerBgColor,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(3),
                topRight: pw.Radius.circular(3),
              ),
            ),
            child: pw.Text(
              'TEKNİK BİLGİLER',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: _headerFontColor,
                letterSpacing: 0.8,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (satirBir.isNotEmpty)
                  pw.Text(
                    satirBir.join('   '),
                    style: pw.TextStyle(fontSize: 9, color: _defaultFontColor),
                  ),
                if (satirIki.isNotEmpty) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(
                    satirIki.join('   '),
                    style: pw.TextStyle(fontSize: 9, color: _defaultFontColor),
                  ),
                ],
                if (satirUc.isNotEmpty) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(
                    satirUc.join('   '),
                    style: pw.TextStyle(fontSize: 9, color: _defaultFontColor),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── AÇIKLAMA TABLOSU ────────────────────────────────────────────────────

  static pw.Widget _buildAciklamaBox(String aciklama) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderColor, width: 0.5),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
              color: _headerBgColor,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(3),
                topRight: pw.Radius.circular(3),
              ),
            ),
            child: pw.Text(
              'AÇIKLAMA',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: _headerFontColor,
                letterSpacing: 0.8,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Text(
              aciklama,
              style: pw.TextStyle(fontSize: 9, color: _defaultFontColor),
              maxLines: 4,
            ),
          ),
        ],
      ),
    );
  }

  // ─── YARDIMCI WİDGETLAR ──────────────────────────────────────────────────

  static pw.Widget _buildFirmaHeader(
    FirmaInfo firma,
    pw.ImageProvider? logoImage,
    String dateStr,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderColor, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (logoImage != null)
            pw.Container(
              width: 60,
              height: 60,
              child: pw.Image(logoImage, fit: pw.BoxFit.contain),
            )
          else
            pw.Container(
              width: 60,
              height: 60,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _borderColor),
                borderRadius: pw.BorderRadius.circular(4),
              ),
            ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  firma.firmaAdi,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: _defaultFontColor,
                  ),
                ),
                pw.SizedBox(height: 4),
                if (firma.telefon.isNotEmpty)
                  pw.Text(
                    _formatPhone(firma.telefon),
                    style: pw.TextStyle(fontSize: 11, color: _defaultFontColor),
                  ),
                if (firma.email != null && firma.email!.isNotEmpty)
                  pw.Text(
                    firma.email!,
                    style: pw.TextStyle(fontSize: 11, color: _defaultFontColor),
                  ),
                if (firma.adres.isNotEmpty)
                  pw.Text(
                    firma.adres,
                    style: pw.TextStyle(fontSize: 11, color: _defaultFontColor),
                  ),
              ],
            ),
          ),
          pw.Text(
            dateStr,
            style: pw.TextStyle(fontSize: 11, color: _defaultFontColor),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFirmaHeaderSmall(
    FirmaInfo firma,
    pw.ImageProvider? logoImage,
    String musteriAdi,
    String dateStr,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (logoImage != null)
          pw.Container(
            width: 24,
            height: 24,
            margin: const pw.EdgeInsets.only(right: 6),
            child: pw.Image(logoImage, fit: pw.BoxFit.contain),
          )
        else
          pw.Container(
            width: 24,
            height: 24,
            margin: const pw.EdgeInsets.only(right: 6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _borderColor),
              borderRadius: pw.BorderRadius.circular(2),
            ),
          ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              firma.firmaAdi,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: _defaultFontColor,
              ),
            ),
            if (firma.telefon.isNotEmpty)
              pw.Text(
                _formatPhone(firma.telefon),
                style: pw.TextStyle(fontSize: 8, color: _defaultFontColor),
              ),
            if (firma.email != null && firma.email!.isNotEmpty)
              pw.Text(
                firma.email!,
                style: pw.TextStyle(fontSize: 8, color: _defaultFontColor),
              ),
            if (firma.adres.isNotEmpty)
              pw.Text(
                firma.adres,
                style: pw.TextStyle(fontSize: 8, color: _defaultFontColor),
              ),
          ],
        ),
        pw.Spacer(),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              musteriAdi,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _defaultFontColor,
              ),
            ),
            pw.Text(
              dateStr,
              style: pw.TextStyle(fontSize: 8, color: _defaultFontColor),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildInfoBox({
    required String title,
    required List<_InfoRow> rows,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderColor, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: pw.BoxDecoration(
              color: _headerBgColor,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(4),
                topRight: pw.Radius.circular(4),
              ),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _headerFontColor,
                letterSpacing: 0.8,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              children: rows
                  .map(
                    (r) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 3),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.SizedBox(
                            width: 110,
                            child: pw.Text(
                              r.label,
                              style: pw.TextStyle(
                                fontSize: 11,
                                color: _defaultFontColor,
                              ),
                            ),
                          ),
                          pw.Text(
                            ':',
                            style: pw.TextStyle(
                              fontSize: 11,
                              color: _defaultFontColor,
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Expanded(
                            child: pw.Text(
                              r.value,
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: _defaultFontColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Center(
      child: pw.Column(
        children: [
          pw.Divider(color: _borderColor, thickness: 0.5),
          pw.SizedBox(height: 3),
          pw.Text(
            '$_yazilimAdi  ·  $_ureticiFirma © $_copyrightYil  ·  $_ureticiFirmaMail  · ${_formatPhone(_ureticiFirmaTel)}',
            style: pw.TextStyle(fontSize: 7, color: _footerFontColor),
          ),
        ],
      ),
    );
  }

  // ─── ÇİZİM → PNG RENDER ──────────────────────────────────────────────────

  static Future<Uint8List?> _renderShapeToPng(ShapeSpec shape) async {
    try {
      const double w = 1600;
      const double h = 1200;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = Colors.white);

      const double scaleFactor = 2.8;
      canvas.save();
      canvas.scale(scaleFactor, scaleFactor);

      final painter = ShapePainter(
        shape,
        sideAttachments: shape.sideAttachments,
        showInternalElements: true,
      );
      painter.paint(canvas, Size(w / scaleFactor, h / scaleFactor));

      canvas.restore();

      final picture = recorder.endRecording();
      final image = await picture.toImage(w.toInt(), h.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return null;
      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('❌ Shape render hatası: $e');
      return null;
    }
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  static String _formatPhone(String phone) {
    // +905079446181 → +90 507 944 61 81
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.startsWith('+90') && digits.length == 13) {
      return '${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6, 9)} ${digits.substring(9, 11)} ${digits.substring(11)}';
    }
    return phone; // tanımadığı format → olduğu gibi bırak
  }
}

// ─── Yardımcı veri sınıfı ────────────────────────────────────────────────────

class _InfoRow {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
}
