// lib/services/excel_export_service.dart

import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'database.dart';

class ExcelExportService {
  /// Tüm projeleri ve ödemeleri Excel'e aktar, paylaş
  static Future<void> exportAndShare() async {
    final data = await LocalDatabase().getExportData();
    final projects = data['projects'] as List<Map<String, dynamic>>;
    final payments = data['payments'] as List<Map<String, dynamic>>;

    final excel = Excel.createExcel();

    // ── MÜŞTERİLER SAYFASI ──
    final Sheet customersSheet = excel['Müşteriler'];
    excel.setDefaultSheet('Müşteriler');

    // Başlık satırı
    final customerHeaders = [
      'Proje Adı',
      'Müşteri Adı',
      'Telefon',
      'Adres',
      'Açıklama',
      'İskonto (₺)',
      'Oluşturma Tarihi',
    ];
    for (var i = 0; i < customerHeaders.length; i++) {
      final cell = customersSheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(customerHeaders[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#1565C0'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }

    // Proje satırları
    for (var i = 0; i < projects.length; i++) {
      final p = projects[i];
      final rowIndex = i + 1;
      final createdAt = DateTime.tryParse(p['created_at'] as String? ?? '');
      final dateStr = createdAt != null
          ? '${createdAt.day.toString().padLeft(2, '0')}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.year}'
          : '';

      final rowData = [
        p['name'] as String? ?? '',
        p['name'] as String? ?? '',
        p['phone'] as String? ?? '',
        p['address'] as String? ?? '',
        p['description'] as String? ?? '',
        (p['discount'] as num?)?.toDouble() ?? 0.0,
        dateStr,
      ];

      for (var j = 0; j < rowData.length; j++) {
        final cell = customersSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: j, rowIndex: rowIndex),
        );
        final val = rowData[j];
        if (val is double) {
          cell.value = DoubleCellValue(val);
        } else {
          cell.value = TextCellValue(val.toString());
        }
        cell.cellStyle = CellStyle(
          backgroundColorHex: rowIndex % 2 == 0
              ? ExcelColor.fromHexString('#F5F5F5')
              : ExcelColor.fromHexString('#FFFFFF'),
        );
      }
    }

    // Kolon genişlikleri
    customersSheet.setColumnWidth(0, 25);
    customersSheet.setColumnWidth(2, 18);
    customersSheet.setColumnWidth(3, 30);
    customersSheet.setColumnWidth(4, 30);

    // ── ÖDEMELER SAYFASI ──
    final Sheet paymentsSheet = excel['Ödemeler'];

    final paymentHeaders = [
      'Dekont No',
      'Proje ID',
      'Tutar (₺)',
      'Ödeme Tarihi',
      'Not',
      'Durum',
      'İptal Tarihi',
      'İptal Sebebi',
    ];

    for (var i = 0; i < paymentHeaders.length; i++) {
      final cell = paymentsSheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(paymentHeaders[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#1565C0'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }

    // Proje ID → Proje adı map
    final projectMap = {
      for (final p in projects) p['id'] as String: p['name'] as String? ?? '',
    };

    for (var i = 0; i < payments.length; i++) {
      final p = payments[i];
      final rowIndex = i + 1;

      final paidAt = DateTime.tryParse(p['paid_at'] as String? ?? '');
      final paidStr = paidAt != null
          ? '${paidAt.day.toString().padLeft(2, '0')}.${paidAt.month.toString().padLeft(2, '0')}.${paidAt.year}'
          : '';

      final cancelledAt = p['cancelled_at'] != null
          ? DateTime.tryParse(p['cancelled_at'] as String)
          : null;
      final cancelStr = cancelledAt != null
          ? '${cancelledAt.day.toString().padLeft(2, '0')}.${cancelledAt.month.toString().padLeft(2, '0')}.${cancelledAt.year}'
          : '';

      final status = p['status'] as String? ?? 'active';
      final statusLabel = status == 'cancelled' ? 'İptal' : 'Aktif';

      final projectName =
          projectMap[p['project_id'] as String? ?? ''] ??
          (p['project_id'] as String? ?? '');

      final rowData = [
        p['dekont_no'] as String? ?? '-',
        projectName,
        (p['amount'] as num?)?.toDouble() ?? 0.0,
        paidStr,
        p['note'] as String? ?? '',
        statusLabel,
        cancelStr,
        p['cancel_reason'] as String? ?? '',
      ];

      for (var j = 0; j < rowData.length; j++) {
        final cell = paymentsSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: j, rowIndex: rowIndex),
        );
        final val = rowData[j];
        if (val is double) {
          cell.value = DoubleCellValue(val);
        } else {
          cell.value = TextCellValue(val.toString());
        }

        // İptal edilenleri kırmızı yap
        cell.cellStyle = CellStyle(
          backgroundColorHex: status == 'cancelled'
              ? ExcelColor.fromHexString('#FFEBEE')
              : rowIndex % 2 == 0
              ? ExcelColor.fromHexString('#F5F5F5')
              : ExcelColor.fromHexString('#FFFFFF'),
          fontColorHex: status == 'cancelled'
              ? ExcelColor.fromHexString('#B71C1C')
              : ExcelColor.fromHexString('#000000'),
        );
      }
    }

    paymentsSheet.setColumnWidth(0, 20);
    paymentsSheet.setColumnWidth(1, 25);
    paymentsSheet.setColumnWidth(3, 15);
    paymentsSheet.setColumnWidth(4, 25);
    paymentsSheet.setColumnWidth(6, 15);
    paymentsSheet.setColumnWidth(7, 25);

    // ── KAYDET VE PAYLAŞ ──
    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final fileName =
        'windesign_veriler_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.xlsx';
    final file = File('${dir.path}/$fileName');
    final bytes = excel.encode();
    if (bytes != null) {
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([
        XFile(
          file.path,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      ], subject: 'WinDesign Craft Pro - Veri Dışa Aktarımı');
    }
  }
}
