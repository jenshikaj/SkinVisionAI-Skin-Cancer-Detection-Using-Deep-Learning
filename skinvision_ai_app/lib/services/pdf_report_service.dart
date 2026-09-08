// services/pdf_report_service.dart
// ──────────────────────────────────
// Generates a branded SkinVision AI PDF report from analysis results.
//
// pubspec.yaml dependencies:
//   pdf: ^3.10.8
//   printing: ^5.12.0
//   path_provider: ^2.1.2
//   share_plus: ^7.2.2

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

// ── Theme colors ──────────────────────────────────────────────────────────────
const _primary = PdfColor.fromInt(0xFF0A7EA4);
const _primaryDark = PdfColor.fromInt(0xFF055C7A);
const _accent = PdfColor.fromInt(0xFF00C9B1);
const _success = PdfColor.fromInt(0xFF38A169);
const _warning = PdfColor.fromInt(0xFFF6AD55);
const _danger = PdfColor.fromInt(0xFFE53E3E);
const _info = PdfColor.fromInt(0xFF3182CE);
const _purple = PdfColor.fromInt(0xFF7B61FF);
const _textDark = PdfColor.fromInt(0xFF0D2233);
const _textLight = PdfColor.fromInt(0xFF8EA9B5);
const _surface = PdfColor.fromInt(0xFFF0F7FA);
const _white = PdfColors.white;

// Light tint backgrounds (solid colors, no alpha arithmetic)
const _primaryTint = PdfColor.fromInt(0xFFE0F3FA);
const _successTint = PdfColor.fromInt(0xFFEBF7F1);
const _warningTint = PdfColor.fromInt(0xFFFFF3E0);
const _dangerTint = PdfColor.fromInt(0xFFFFF0F0); // very light red
const _infoTint = PdfColor.fromInt(0xFFEBF4FF);
const _purpleTint = PdfColor.fromInt(0xFFF0EDFF);

// Border colors (muted versions of theme colors)
const _primaryBorder = PdfColor.fromInt(0xFFB8DCE8);
const _successBorder = PdfColor.fromInt(0xFFA8D5BB);
const _warningBorder = PdfColor.fromInt(0xFFF0C080);
const _dangerBorder = PdfColor.fromInt(0xFFF0AAAA);
const _infoBorder = PdfColor.fromInt(0xFFAACCF0);
const _purpleBorder = PdfColor.fromInt(0xFFCCC5F5);

class PdfReportService {
  static Future<void> shareReport({
    required Map<String, dynamic> insights,
    required File? imageFile,
  }) async {
    final pdfBytes = await _buildPdf(insights: insights, imageFile: imageFile);
    final dir = await getTemporaryDirectory();
    final disease = (insights['disease'] ?? 'report')
        .toString()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(' ', '_');
    final file = File('${dir.path}/SkinVisionAI_$disease.pdf');
    await file.writeAsBytes(pdfBytes);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject:
          'SkinVisionAI Report — ${insights['disease'] ?? 'Skin Analysis'}',
    );
  }

  static Future<Uint8List> _buildPdf({
    required Map<String, dynamic> insights,
    required File? imageFile,
  }) async {
    final pdf = pw.Document();

    // Logo
    pw.ImageProvider? logoImage;
    try {
      final bytes = await rootBundle.load('assets/app_icon/splash.png');
      logoImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {}

    // Skin image
    pw.ImageProvider? skinImage;
    if (imageFile != null && await imageFile.exists()) {
      try {
        skinImage = pw.MemoryImage(await imageFile.readAsBytes());
      } catch (_) {}
    }

    // Data
    final disease = insights['disease']?.toString() ?? 'Unknown';
    final diseaseConf = _formatPercent(insights['disease_confidence']);
    final stage = insights['stage']?.toString() ?? '--';
    final stageConf = _formatPercent(insights['stage_confidence']);
    final summary = insights['summary']?.toString() ?? '';
    final definition = insights['definition']?.toString() ?? '';
    final causes = insights['causes']?.toString() ?? '';
    final symptoms = _toList(insights['symptoms']);
    final selfCare = _toList(insights['self_care']);
    final redFlags = _toList(insights['red_flags']);
    final whenCare = _toList(insights['when_to_seek_care']);
    final nextSteps = _toList(insights['next_steps']);

    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year}  '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    final stageColor = _stageColor(stage);
    final stageTint = _stageTint(stage);
    final stageBorder = _stageBorderColor(stage);

    // Fonts
    final fontReg = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();
    final fontEB = await PdfGoogleFonts.nunitoExtraBold();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (ctx) => [
        // ── Gradient header ─────────────────────────────────────────────────
        pw.Container(
          width: double.infinity,
          decoration: const pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [_primaryDark, _primary, _accent],
              begin: pw.Alignment.centerLeft,
              end: pw.Alignment.centerRight,
            ),
          ),
          padding: const pw.EdgeInsets.fromLTRB(28, 22, 28, 22),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(children: [
                if (logoImage != null) ...[
                  pw.Container(
                    width: 44,
                    height: 44,
                    decoration: pw.BoxDecoration(
                        color: _white,
                        borderRadius: pw.BorderRadius.circular(10)),
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Image(logoImage),
                  ),
                  pw.SizedBox(width: 12),
                ],
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('SkinVision AI',
                          style: pw.TextStyle(
                              font: fontEB, fontSize: 20, color: _white)),
                      pw.Text('Dermatology Analysis Report',
                          style: pw.TextStyle(
                              font: fontReg,
                              fontSize: 10,
                              color: PdfColor(1, 1, 1, 0.75))),
                    ]),
              ]),
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Generated',
                        style: pw.TextStyle(
                            font: fontReg,
                            fontSize: 8,
                            color: PdfColor(1, 1, 1, 0.75))),
                    pw.Text(dateStr,
                        style: pw.TextStyle(
                            font: fontBold, fontSize: 9, color: _white)),
                  ]),
            ],
          ),
        ),

        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(28, 18, 28, 0),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 18),

              // ── Image + result card ────────────────────────────────────
              pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (skinImage != null) ...[
                      pw.ClipRRect(
                        horizontalRadius: 10,
                        verticalRadius: 10,
                        child: pw.Image(skinImage,
                            width: 130, height: 130, fit: pw.BoxFit.cover),
                      ),
                      pw.SizedBox(width: 16),
                    ],
                    pw.Expanded(
                        child: pw.Container(
                      padding: const pw.EdgeInsets.all(16),
                      decoration: pw.BoxDecoration(
                        color: _surface,
                        borderRadius: pw.BorderRadius.circular(12),
                        border: pw.Border.all(color: _primaryBorder, width: 1),
                      ),
                      child: pw.Column(children: [
                        // Disease row
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Expanded(
                                child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Detected Condition',
                                    style: pw.TextStyle(
                                        font: fontReg,
                                        fontSize: 8,
                                        color: _textLight)),
                                pw.SizedBox(height: 2),
                                pw.Text(disease,
                                    style: pw.TextStyle(
                                        font: fontEB,
                                        fontSize: 12,
                                        color: _primary)),
                              ],
                            )),
                            pw.SizedBox(width: 8),
                            // Badge: light tint bg + primary text
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: pw.BoxDecoration(
                                color: _primaryTint,
                                borderRadius: pw.BorderRadius.circular(6),
                                border: pw.Border.all(
                                    color: _primaryBorder, width: 0.5),
                              ),
                              child: pw.Text(diseaseConf,
                                  style: pw.TextStyle(
                                      font: fontBold,
                                      fontSize: 11,
                                      color: _primary)),
                            ),
                          ],
                        ),

                        pw.Divider(color: _primaryBorder, thickness: 0.5),
                        pw.SizedBox(height: 6),

                        // Stage row
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Expanded(
                                child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Severity Stage',
                                    style: pw.TextStyle(
                                        font: fontReg,
                                        fontSize: 8,
                                        color: _textLight)),
                                pw.SizedBox(height: 2),
                                pw.Text(stage,
                                    style: pw.TextStyle(
                                        font: fontEB,
                                        fontSize: 12,
                                        color: stageColor)),
                              ],
                            )),
                            pw.SizedBox(width: 8),
                            // Badge: light tint bg + stage color text
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: pw.BoxDecoration(
                                color: stageTint,
                                borderRadius: pw.BorderRadius.circular(6),
                                border: pw.Border.all(
                                    color: stageBorder, width: 0.5),
                              ),
                              child: pw.Text(stageConf,
                                  style: pw.TextStyle(
                                      font: fontBold,
                                      fontSize: 11,
                                      color: stageColor)),
                            ),
                          ],
                        ),
                      ]),
                    )),
                  ]),

              pw.SizedBox(height: 16),

              // ── Sections ───────────────────────────────────────────────
              if (summary.isNotEmpty) ...[
                _sectionCard(fontBold, fontEB, fontReg, 'Summary', summary,
                    _primary, _primaryTint, _primaryBorder),
                pw.SizedBox(height: 12),
              ],
              if (definition.isNotEmpty) ...[
                _sectionCard(
                    fontBold,
                    fontEB,
                    fontReg,
                    'What is this condition?',
                    definition,
                    _purple,
                    _purpleTint,
                    _purpleBorder),
                pw.SizedBox(height: 12),
              ],
              if (causes.isNotEmpty) ...[
                _sectionCard(fontBold, fontEB, fontReg, 'Why does it happen?',
                    causes, _warning, _warningTint, _warningBorder),
                pw.SizedBox(height: 12),
              ],
              if (symptoms.isNotEmpty) ...[
                _listCard(fontBold, fontEB, fontReg, 'Symptoms', symptoms,
                    _warning, _warningTint, _warningBorder),
                pw.SizedBox(height: 12),
              ],
              if (selfCare.isNotEmpty) ...[
                _listCard(fontBold, fontEB, fontReg, 'Self-Care Tips', selfCare,
                    _success, _successTint, _successBorder),
                pw.SizedBox(height: 12),
              ],

              // Red Flags — white bg, red border, dark text (not red bg)
              if (redFlags.isNotEmpty) ...[
                _listCard(
                    fontBold,
                    fontEB,
                    fontReg,
                    'Red Flags — Warning Signs',
                    redFlags,
                    _danger,
                    _dangerTint,
                    _dangerBorder,
                    itemTextColor: _danger),
                pw.SizedBox(height: 12),
              ],

              if (whenCare.isNotEmpty) ...[
                _listCard(
                    fontBold,
                    fontEB,
                    fontReg,
                    'When to Seek Medical Care',
                    whenCare,
                    _info,
                    _infoTint,
                    _infoBorder),
                pw.SizedBox(height: 12),
              ],
              if (nextSteps.isNotEmpty) ...[
                _listCard(fontBold, fontEB, fontReg, 'Recommended Next Steps',
                    nextSteps, _success, _successTint, _successBorder),
                pw.SizedBox(height: 18),
              ],

              // ── Footer ─────────────────────────────────────────────────
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  gradient: const pw.LinearGradient(
                    colors: [_primaryDark, _primary],
                    begin: pw.Alignment.centerLeft,
                    end: pw.Alignment.centerRight,
                  ),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(children: [
                  pw.Text('SkinVision AI — Powered by SkinFusionNet',
                      style: pw.TextStyle(
                          font: fontBold, fontSize: 9, color: _white),
                      textAlign: pw.TextAlign.center),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'This is an AI-generated educational report and NOT a medical diagnosis. Please consult a qualified dermatologist.',
                    style: pw.TextStyle(
                        font: fontReg,
                        fontSize: 7.5,
                        color: PdfColor(1, 1, 1, 0.75)),
                    textAlign: pw.TextAlign.center,
                  ),
                ]),
              ),

              pw.SizedBox(height: 16),
            ],
          ),
        ),
      ],
    ));

    return pdf.save();
  }

  // ── Section card (text body) ──────────────────────────────────────────────
  static pw.Widget _sectionCard(
    pw.Font bold,
    pw.Font eb,
    pw.Font reg,
    String title,
    String text,
    PdfColor color,
    PdfColor tint,
    PdfColor border,
  ) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: border, width: 1),
      ),
      child:
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(children: [
          pw.Container(
              width: 4,
              height: 14,
              decoration: pw.BoxDecoration(
                  color: color, borderRadius: pw.BorderRadius.circular(2))),
          pw.SizedBox(width: 8),
          pw.Text(title,
              style: pw.TextStyle(font: eb, fontSize: 11, color: color)),
        ]),
        pw.SizedBox(height: 8),
        pw.Text(text,
            style: pw.TextStyle(
                font: reg, fontSize: 9.5, color: _textDark, lineSpacing: 2)),
      ]),
    );
  }

  // ── List card (bullet items) ──────────────────────────────────────────────
  static pw.Widget _listCard(
    pw.Font bold,
    pw.Font eb,
    pw.Font reg,
    String title,
    List<String> items,
    PdfColor color,
    PdfColor tint,
    PdfColor border, {
    PdfColor? itemTextColor,
  }) {
    final textColor = itemTextColor ?? _textDark;
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _white, // always white bg — no tint fill
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: border, width: 1),
      ),
      child:
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(children: [
          pw.Container(
              width: 4,
              height: 14,
              decoration: pw.BoxDecoration(
                  color: color, borderRadius: pw.BorderRadius.circular(2))),
          pw.SizedBox(width: 8),
          pw.Text(title,
              style: pw.TextStyle(font: eb, fontSize: 11, color: color)),
        ]),
        pw.SizedBox(height: 10),
        ...items.map((item) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 5,
                      height: 5,
                      margin: const pw.EdgeInsets.only(top: 4, right: 8),
                      decoration: pw.BoxDecoration(
                          color: color, shape: pw.BoxShape.circle),
                    ),
                    pw.Expanded(
                        child: pw.Text(item,
                            style: pw.TextStyle(
                                font: reg,
                                fontSize: 9.5,
                                color: textColor,
                                lineSpacing: 1.5))),
                  ]),
            )),
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static String _formatPercent(dynamic v) {
    if (v == null) return '--';
    if (v is num) return '${v.toStringAsFixed(1)}%';
    return v.toString();
  }

  static List<String> _toList(dynamic v) {
    if (v == null) return [];
    if (v is List)
      return v
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    final s = v.toString().trim();
    return s.isEmpty ? [] : [s];
  }

  static PdfColor _stageColor(String s) {
    switch (s.toLowerCase()) {
      case 'mild':
        return _success;
      case 'moderate':
        return _warning;
      case 'severe':
        return _danger;
      default:
        return _textLight;
    }
  }

  static PdfColor _stageTint(String s) {
    switch (s.toLowerCase()) {
      case 'mild':
        return _successTint;
      case 'moderate':
        return _warningTint;
      case 'severe':
        return _dangerTint;
      default:
        return _surface;
    }
  }

  static PdfColor _stageBorderColor(String s) {
    switch (s.toLowerCase()) {
      case 'mild':
        return _successBorder;
      case 'moderate':
        return _warningBorder;
      case 'severe':
        return _dangerBorder;
      default:
        return _primaryBorder;
    }
  }
}
