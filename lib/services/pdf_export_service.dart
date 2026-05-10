import 'dart:developer';

import 'package:ai_medicine_tracker/helper/constant.dart';
import 'package:ai_medicine_tracker/models/user_medication.dart';
import 'package:ai_medicine_tracker/repository/medicine_repository.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfExportService {
  PdfExportService._();

  // ── Medicine info PDF ─────────────────────────────────

  static Future<void> exportMedicineInfo(MedicineItem item) async {
    try {
      final font = await _loadFont();
      final boldFont = await _loadBoldFont();
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          theme: pw.ThemeData.withFont(base: font, bold: boldFont),
          header: (_) => _header(),
          footer: (_) => _footer(),
          build: (_) => [
            _medicineTitle(item.originalName),
            pw.SizedBox(height: 16),
            ...item.sections.entries
                .where((e) => e.value.isNotEmpty)
                .map((e) => _section(e.key, e.value)),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename:
            '${item.originalName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_info.pdf',
      );
    } catch (e) {
      log('❌ PDF export error: $e');
      rethrow;
    }
  }

  // ── Medications list PDF ──────────────────────────────

  static Future<void> exportMedicationsList(
    List<UserMedication> meds, {
    String personLabel = 'My',
  }) async {
    try {
      final font = await _loadFont();
      final boldFont = await _loadBoldFont();
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          theme: pw.ThemeData.withFont(base: font, bold: boldFont),
          header: (_) => _header(),
          footer: (_) => _footer(),
          build: (_) => [
            _listTitle('$personLabel Medications'),
            pw.SizedBox(height: 16),
            if (meds.isEmpty)
              pw.Text('No medications added yet.',
                  style: const pw.TextStyle(color: PdfColors.grey600))
            else
              ...meds.asMap().entries.map((e) => _medCard(e.key + 1, e.value)),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename:
            '${personLabel.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_medications.pdf',
      );
    } catch (e) {
      log('❌ PDF export error: $e');
      rethrow;
    }
  }

  // ── Font loading ──────────────────────────────────────

  static Future<pw.Font> _loadFont() async {
    try {
      return await PdfGoogleFonts.notoSansRegular();
    } catch (_) {
      return pw.Font.helvetica();
    }
  }

  static Future<pw.Font> _loadBoldFont() async {
    try {
      return await PdfGoogleFonts.notoSansBold();
    } catch (_) {
      return pw.Font.helveticaBold();
    }
  }

  // ── Shared widgets ────────────────────────────────────

  static pw.Widget _header() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.green700, width: 1.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            Constants.appName,
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.green700,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            'AI-Powered Medical Information',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  static pw.Widget _footer() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border:
            pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            'Disclaimer: This information is AI-generated for educational purposes only. '
            'Always consult a qualified doctor or pharmacist before making any medical decisions.',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 3),
          pw.UrlLink(
            destination:
                'https://play.google.com/store/apps/details?id=${Constants.packageName}',
            child: pw.Text(
              '${Constants.appName}  •  play.google.com/store/apps/details?id=${Constants.packageName}',
              style: pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.green700,
                  fontWeight: pw.FontWeight.bold,
                  decoration: pw.TextDecoration.underline),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _medicineTitle(String name) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.green200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            name,
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey900,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated on ${_fmtDate(DateTime.now())}  •  ${Constants.appName}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  static pw.Widget _listTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.green200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey900,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated on ${_fmtDate(DateTime.now())}  •  ${Constants.appName}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  static pw.Widget _section(String title, List<String> points) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const pw.BoxDecoration(
              color: PdfColors.green700,
              borderRadius:
                  pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.SizedBox(height: 6),
          ...points.map(
            (p) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4, left: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('• ',
                      style: const pw.TextStyle(
                          fontSize: 10, color: PdfColors.green700)),
                  pw.Expanded(
                    child: pw.Text(p,
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey800)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _medCard(int index, UserMedication med) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 24,
            height: 24,
            decoration: const pw.BoxDecoration(
              color: PdfColors.green700,
              shape: pw.BoxShape.circle,
            ),
            child: pw.Center(
              child: pw.Text(
                '$index',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  med.name,
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey900,
                  ),
                ),
                if (med.dosage.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(med.dosage,
                      style: const pw.TextStyle(
                          fontSize: 10, color: PdfColors.green700)),
                ],
                if (med.notes.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(med.notes,
                      style: const pw.TextStyle(
                          fontSize: 10, color: PdfColors.grey600)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime dt) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }
}
