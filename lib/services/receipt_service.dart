// lib/services/receipt_service.dart

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../features/settings/settings_page.dart';

class ReceiptService {
  static const PdfColor _blueColor = PdfColor.fromInt(0xFF1565C0);
  static const PdfColor _redColor = PdfColor.fromInt(0xFFB71C1C);
  static const PdfColor _greenColor = PdfColor.fromInt(0xFF2E7D32);
  static const PdfColor _greyLight = PdfColor.fromInt(0xFFF9F9F9);
  static const PdfColor _greyBorder = PdfColor.fromInt(0xFFEEEEEE);
  static const PdfColor _textPrimary = PdfColor.fromInt(0xFF212121);
  static const PdfColor _textSecondary = PdfColor.fromInt(0xFF757575);
  static const PdfColor _headerBg = PdfColor.fromInt(0xFFE3F2FD);
  static const PdfColor _cancelHeaderBg = PdfColor.fromInt(0xFFFFEBEE);
  static const PdfColor _tableHeaderBg = PdfColor.fromInt(0xFFEEEEEE);

  static Future<Map<String, String>> _loadFirmaInfo() async {
    final settings = await SettingsService.loadFirmaSettings();
    return {
      'firmaAdi': settings.firmaAdi.isNotEmpty
          ? settings.firmaAdi
          : 'Firma Adi Belirtilmemis',
      'adres': settings.adres,
      'tel': settings.telefon,
      'email': settings.email,
    };
  }

  static Future<pw.Font> _loadFont() async {
    final fontData = await rootBundle.load('assets/fonts/OpenSans.ttf');
    return pw.Font.ttf(fontData);
  }

  static Future<Uint8List> _generateQrImage(String data) async {
    final qrPainter = QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: true,
      color: const Color(0xFF212121),
      emptyColor: const Color(0xFFFFFFFF),
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    qrPainter.paint(canvas, const Size(200, 200));
    final picture = recorder.endRecording();
    final img = await picture.toImage(200, 200);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Normal ödeme dekontu
  static Future<void> shareReceipt({
    required Map<String, dynamic> payment,
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    required double grandTotal,
    required double discount,
    required double totalPaid,
    required double remaining,
    required List<Map<String, dynamic>> allPayments,
  }) async {
    final file = await _generateReceiptPdf(
      payment: payment,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      isCancelled: false,
      grandTotal: grandTotal,
      discount: discount,
      totalPaid: totalPaid,
      remaining: remaining,
      allPayments: allPayments,
    );
    try {
      await Share.shareXFiles([
        XFile(file.path, mimeType: 'application/pdf'),
      ], subject: 'Odeme Dekontu - ${payment['dekont_no']}');
    } catch (_) {}
  }

  /// İptal dekontu — sade, sadece bakiye gösterilir
  static Future<void> shareCancelReceipt({
    required Map<String, dynamic> payment,
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    required double grandTotal,
    required double discount,
    required double totalPaid,
    required double remaining,
    required List<Map<String, dynamic>> allPayments,
  }) async {
    final file = await _generateReceiptPdf(
      payment: payment,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      isCancelled: true,
      grandTotal: grandTotal,
      discount: discount,
      totalPaid: totalPaid,
      remaining: remaining,
      allPayments: allPayments,
    );
    try {
      await Share.shareXFiles([
        XFile(file.path, mimeType: 'application/pdf'),
      ], subject: 'Iptal Dekontu - ${payment['dekont_no']}');
    } catch (_) {}
  }

  static Future<File> _generateReceiptPdf({
    required Map<String, dynamic> payment,
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    required bool isCancelled,
    required double grandTotal,
    required double discount,
    required double totalPaid,
    required double remaining,
    required List<Map<String, dynamic>> allPayments,
  }) async {
    final firma = await _loadFirmaInfo();
    final font = await _loadFont();
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: font),
    );

    final dekontNo = payment['dekont_no'] as String? ?? '-';
    final amount = (payment['amount'] as num).toDouble();
    final paidAt = DateTime.parse(payment['paid_at'] as String);
    final cancelReason = payment['cancel_reason'] as String?;
    final cancelledAt = payment['cancelled_at'] != null
        ? DateTime.parse(payment['cancelled_at'] as String)
        : null;

    final now = DateTime.now();
    final todayStr = _fmtDate(now);
    final netTotal = grandTotal - discount;

    final qrContent =
        'Dekont: $dekontNo | Musteri: $customerName | Tutar: ${amount.toStringAsFixed(0)} TL | Tarih: ${_fmtDate(paidAt)}';
    final qrBytes = await _generateQrImage(qrContent);
    final qrImage = pw.MemoryImage(qrBytes);
    final base = pw.TextStyle(font: font);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ── HEADER ──
            _buildHeader(firma, dekontNo, todayStr, isCancelled, base),

            pw.SizedBox(height: 10),

            // ── MÜŞTERİ + ÖDEME BİLGİLERİ (yan yana) ──
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Sol: müşteri
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: _greyLight,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: _greyBorder),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'MUSTERI BILGILERI',
                          style: base.copyWith(
                            fontSize: 8,
                            color: _textSecondary,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          customerName,
                          style: base.copyWith(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: _textPrimary,
                          ),
                        ),
                        if (customerPhone.isNotEmpty)
                          pw.Text(
                            customerPhone,
                            style: base.copyWith(
                              fontSize: 9,
                              color: _textSecondary,
                            ),
                          ),
                        if (customerAddress.isNotEmpty)
                          pw.Text(
                            customerAddress,
                            style: base.copyWith(
                              fontSize: 9,
                              color: _textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                // Sağ: ödeme özeti
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: _greyLight,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: _greyBorder),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'ODEME BILGILERI',
                          style: base.copyWith(
                            fontSize: 8,
                            color: _textSecondary,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        _summaryRow(
                          'Toplam',
                          '${grandTotal.toStringAsFixed(0)}TL',
                          base,
                        ),
                        if (discount > 0)
                          _summaryRow(
                            'Indirim',
                            '${discount.toStringAsFixed(0)}TL',
                            base,
                            valueColor: _redColor,
                          ),
                        _summaryRow(
                          'Net Tutar',
                          '${(grandTotal - discount).toStringAsFixed(0)}TL',
                          base,
                          valueColor: _blueColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 10),

            // ── İPTAL İSE: sade içerik ──
            if (isCancelled) ...[
              _buildCancelSection(
                amount,
                cancelledAt,
                cancelReason,
                totalPaid,
                netTotal,
                remaining,
                base,
              ),
            ] else ...[
              // ── ÖDEME TABLOSU ──
              _buildPaymentTable(allPayments, dekontNo, base),

              pw.SizedBox(height: 8),

              // ── ÖZET ALT BAR ──
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: pw.BoxDecoration(
                  color: _greyLight,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: _greyBorder),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Odeme Toplami:',
                      style: base.copyWith(fontSize: 10, color: _textSecondary),
                    ),
                    pw.Text(
                      '${totalPaid.toStringAsFixed(0)}TL',
                      style: base.copyWith(fontSize: 10, color: _textPrimary),
                    ),
                    pw.SizedBox(width: 20),
                    pw.Text(
                      'Kalan Odeme:',
                      style: base.copyWith(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: remaining > 0 ? _redColor : _greenColor,
                      ),
                    ),
                    pw.Text(
                      '${remaining.toStringAsFixed(0)}TL',
                      style: base.copyWith(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: remaining > 0 ? _redColor : _greenColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            pw.Spacer(),

            // ── QR + DOĞRULAMA ──
            pw.Divider(color: _greyBorder),
            pw.SizedBox(height: 6),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(width: 60, height: 60, child: pw.Image(qrImage)),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Dogrulama Kodu: $dekontNo',
                        style: base.copyWith(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: _textPrimary,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'QR kodu okutun veya dekont numarasini uygulamadan sorgulayabilirsiniz.',
                        style: base.copyWith(
                          fontSize: 7,
                          color: _textSecondary,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Bu belge resmi vergi faturasi degildir. Yalnizca odeme kaydi amaciyla duzenlenmiştir.',
                        style: base.copyWith(
                          fontSize: 7,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final fileName = isCancelled
        ? 'iptal_dekontu_$dekontNo.pdf'
        : 'odeme_dekontu_$dekontNo.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // ── HEADER ──
  static pw.Widget _buildHeader(
    Map<String, String> firma,
    String dekontNo,
    String todayStr,
    bool isCancelled,
    pw.TextStyle base,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: isCancelled ? _cancelHeaderBg : _headerBg,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(
          color: isCancelled ? _redColor : _blueColor,
          width: 1,
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                firma['firmaAdi']!,
                style: base.copyWith(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                  color: isCancelled ? _redColor : _blueColor,
                ),
              ),
              if (firma['tel']!.isNotEmpty)
                pw.Text(
                  firma['tel']!,
                  style: base.copyWith(fontSize: 9, color: _textSecondary),
                ),
              if (firma['email']!.isNotEmpty)
                pw.Text(
                  firma['email']!,
                  style: base.copyWith(fontSize: 9, color: _textSecondary),
                ),
              if (firma['adres']!.isNotEmpty)
                pw.Text(
                  firma['adres']!,
                  style: base.copyWith(fontSize: 9, color: _textSecondary),
                ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                isCancelled ? 'IPTAL DEKONTU' : 'ODEME DEKONTU',
                style: base.copyWith(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: isCancelled ? _redColor : _blueColor,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: pw.BoxDecoration(
                  color: isCancelled ? _redColor : _blueColor,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  dekontNo,
                  style: base.copyWith(
                    color: PdfColors.white,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Olusturulma: $todayStr',
                style: base.copyWith(fontSize: 8, color: _textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── İPTAL İÇERİĞİ ──
  static pw.Widget _buildCancelSection(
    double amount,
    DateTime? cancelledAt,
    String? cancelReason,
    double totalPaid,
    double netTotal,
    double remaining,
    pw.TextStyle base,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // İptal tutar kutusu
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFFFF3F3),
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: _redColor, width: 0.5),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Iptal Edilen Tutar',
                style: base.copyWith(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: _redColor,
                ),
              ),
              pw.Text(
                '${amount.toStringAsFixed(0)} TL',
                style: base.copyWith(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: _redColor,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        // Güncel bakiye
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: pw.BoxDecoration(
            color: _greyLight,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: _greyBorder),
          ),
          child: pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Toplam Tutar',
                    style: base.copyWith(fontSize: 10, color: _textSecondary),
                  ),
                  pw.Text(
                    '${netTotal.toStringAsFixed(0)} TL',
                    style: base.copyWith(fontSize: 10, color: _textPrimary),
                  ),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Odenen (Iptal Sonrasi)',
                    style: base.copyWith(fontSize: 10, color: _textSecondary),
                  ),
                  pw.Text(
                    '${totalPaid.toStringAsFixed(0)} TL',
                    style: base.copyWith(fontSize: 10, color: _greenColor),
                  ),
                ],
              ),
              pw.Divider(color: _greyBorder, height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Kalan Borc',
                    style: base.copyWith(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: remaining > 0 ? _redColor : _greenColor,
                    ),
                  ),
                  pw.Text(
                    '${remaining.toStringAsFixed(0)} TL',
                    style: base.copyWith(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: remaining > 0 ? _redColor : _greenColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (cancelReason != null && cancelReason.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFFFF3F3),
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: _redColor, width: 0.5),
            ),
            child: pw.Row(
              children: [
                pw.Text(
                  'Iptal Nedeni: ',
                  style: base.copyWith(fontSize: 9, color: _textSecondary),
                ),
                pw.Expanded(
                  child: pw.Text(
                    cancelReason,
                    style: base.copyWith(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _redColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        pw.SizedBox(height: 10),
        pw.Center(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _redColor, width: 2),
              borderRadius: pw.BorderRadius.circular(4),
              color: const PdfColor.fromInt(0xFFFFF3F3),
            ),
            child: pw.Text(
              'IPTAL EDILDI',
              style: base.copyWith(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: _redColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── ÖDEME TABLOSU ──
  static pw.Widget _buildPaymentTable(
    List<Map<String, dynamic>> payments,
    String currentDekontNo,
    pw.TextStyle base,
  ) {
    final headers = ['Tarih', 'Aciklama', 'Tutar', 'Sonuc', 'Dekont'];
    final colWidths = [0.14, 0.26, 0.14, 0.14, 0.22];

    pw.Widget cell(
      String text, {
      bool header = false,
      bool isCancel = false,
      bool isCurrent = false,
      pw.Alignment align = pw.Alignment.centerLeft,
    }) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: pw.Align(
          alignment: align,
          child: pw.Text(
            text,
            style: base.copyWith(
              fontSize: header ? 9 : 9,
              fontWeight: header || isCurrent
                  ? pw.FontWeight.bold
                  : pw.FontWeight.normal,
              color: isCancel
                  ? _redColor
                  : (header ? _textSecondary : _textPrimary),
            ),
          ),
        ),
      );
    }

    List<pw.TableRow> rows = [
      // Başlık satırı
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _tableHeaderBg),
        children: headers.map((h) => cell(h, header: true)).toList(),
      ),
    ];

    for (final p in payments) {
      final pDate = DateTime.parse(p['paid_at'] as String);
      final pAmount = (p['amount'] as num).toDouble();
      final pDekont = p['dekont_no'] as String? ?? '-';
      final pIsCancelled = (p['status'] as String?) == 'cancelled';
      final pNote = pIsCancelled
          ? (p['cancel_reason'] as String? ?? p['note'] as String? ?? '')
          : (p['note'] as String? ?? '');
      final isCurrent = pDekont == currentDekontNo;

      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: isCurrent
                ? const PdfColor.fromInt(0xFFF1F8F1)
                : pIsCancelled
                ? const PdfColor.fromInt(0xFFFFF3F3)
                : PdfColors.white,
          ),
          children: [
            cell(_fmtDate(pDate), isCancel: pIsCancelled, isCurrent: isCurrent),
            cell(pNote, isCancel: pIsCancelled, isCurrent: isCurrent),
            cell(
              '${pAmount.toStringAsFixed(0)}TL',
              isCancel: pIsCancelled,
              isCurrent: isCurrent,
              align: pw.Alignment.centerRight,
            ),
            cell(
              pIsCancelled ? 'Iptal' : 'Odendi',
              isCancel: pIsCancelled,
              isCurrent: isCurrent,
            ),
            cell(pDekont, isCancel: pIsCancelled, isCurrent: isCurrent),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: _greyBorder, width: 0.5),
      columnWidths: {
        0: pw.FlexColumnWidth(colWidths[0]),
        1: pw.FlexColumnWidth(colWidths[1]),
        2: pw.FlexColumnWidth(colWidths[2]),
        3: pw.FlexColumnWidth(colWidths[3]),
        4: pw.FlexColumnWidth(colWidths[4]),
      },
      children: rows,
    );
  }

  static pw.Widget _summaryRow(
    String label,
    String value,
    pw.TextStyle base, {
    PdfColor? valueColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: base.copyWith(fontSize: 9, color: _textSecondary),
          ),
          pw.Text(
            value,
            style: base.copyWith(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: valueColor ?? _textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
