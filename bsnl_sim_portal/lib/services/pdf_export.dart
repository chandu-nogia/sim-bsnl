import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/sim_entry.dart';
import 'file_download.dart';

PdfColor _pdf(Color c) => PdfColor(c.r, c.g, c.b, c.a);

Future<void> showSimShareSheet(BuildContext context, List<SimEntry> rows) async {
  if (rows.isEmpty) return;
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF0B3D91)),
            title: const Text('Share colorful PDF'),
            subtitle: Text('${rows.length} rows'),
            onTap: () => Navigator.pop(ctx, 'pdf'),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined, color: Color(0xFF0B3D91)),
            title: const Text('Download PDF'),
            onTap: () => Navigator.pop(ctx, 'download'),
          ),
          ListTile(
            leading: const Icon(Icons.chat_outlined, color: Color(0xFF128C7E)),
            title: const Text('WhatsApp'),
            onTap: () => Navigator.pop(ctx, 'wa'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted || choice == null) return;
  switch (choice) {
    case 'pdf':
      await downloadSimPdf(context, rows, share: true);
    case 'download':
      await downloadSimPdf(context, rows);
    case 'wa':
      await shareSimWhatsApp(context, rows);
  }
}

Future<void> downloadSimPdf(
  BuildContext context,
  List<SimEntry> rows, {
  bool share = false,
}) async {
  if (rows.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF ke liye koi row nahi')),
    );
    return;
  }
  try {
    final bytes = await buildSimPdf(rows);
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final filename = 'BSNL_SIM_Register_$stamp.pdf';
    if (share) {
      final ok = await sharePdfFile(bytes, filename, 'BSNL SIM Register');
      if (ok) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF share ho gaya')),
          );
        }
        return;
      }
    }
    triggerDownload(bytes, filename, 'application/pdf');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            share
                ? '$filename download ho gaya — WhatsApp / Email se share karo'
                : '$filename download ho gaya (${rows.length} rows)',
          ),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF fail: $e'), backgroundColor: Colors.red.shade800),
      );
    }
  }
}

Future<void> shareSimWhatsApp(BuildContext context, List<SimEntry> rows) async {
  if (rows.isEmpty) return;
  final buf = StringBuffer('BSNL SIM Register (${rows.length} entries)\n');
  final n = rows.length > 25 ? 25 : rows.length;
  for (var i = 0; i < n; i++) {
    final e = rows[i];
    buf.writeln('${i + 1}. ${e.name}  ${e.mobile}  ${e.type.label}  FRC ${e.frc.isEmpty ? "-": e.frc}');
  }
  if (rows.length > 25) buf.writeln('… +${rows.length - 25} more (PDF download karo)');
  openWhatsApp(buf.toString());
}

Future<Uint8List> buildSimPdf(List<SimEntry> rows) async {
  final doc = pw.Document();
  const headers = ['#', 'Date', 'Name', 'Type', 'Mobile', 'Alt. No.', 'FRC', 'SIM No.', 'Last 6', 'Status'];
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(22),
      header: (_) => pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(0xFF0B3D91),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Row(
          children: [
            pw.Container(
              width: 12,
              height: 12,
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFFFC107),
                shape: pw.BoxShape.circle,
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Text(
              'BSNL SIM PORTAL',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Spacer(),
            pw.Text(
              DateFormat('d MMM yyyy, HH:mm').format(DateTime.now()),
              style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
            ),
          ],
        ),
      ),
      footer: (c) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${c.pageNumber} / ${c.pagesCount}   •   ${rows.length} rows',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey),
        ),
      ),
      build: (_) => [
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.blueGrey300, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(28),
            1: const pw.FixedColumnWidth(58),
            3: const pw.FixedColumnWidth(62),
            6: const pw.FixedColumnWidth(36),
            8: const pw.FixedColumnWidth(48),
            9: const pw.FixedColumnWidth(52),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF072A66)),
              children: [
                for (final h in headers)
                  _cell(h, color: PdfColors.white, bold: true),
              ],
            ),
            for (var i = 0; i < rows.length; i++)
              _simRow(rows[i], i),
          ],
        ),
      ],
    ),
  );
  return Uint8List.fromList(await doc.save());
}

pw.TableRow _simRow(SimEntry e, int i) {
  final typeBg = _pdf(e.type.color);
  final frcBg = e.frc.isEmpty ? PdfColors.white : _pdf(frcChipColor(e.frc));
  final stripe = i.isEven ? PdfColors.white : PdfColor.fromInt(0xFFF4F7FB);
  return pw.TableRow(
    decoration: pw.BoxDecoration(color: stripe),
    children: [
      _cell('${i + 1}', bold: true),
      _cell(e.date),
      _cell(e.name, bold: true),
      _cell(e.type.label, bg: typeBg, bold: true),
      _cell(e.mobile),
      _cell(e.altNumber.isEmpty ? '—' : e.altNumber),
      _cell(e.frc.isEmpty ? '—' : e.frc, bg: frcBg, bold: true, center: true),
      _cell(e.simNo),
      _cell(e.last6),
      _cell(e.status, bg: PdfColor.fromInt(0xFFC8E6C9), bold: true),
    ],
  );
}

pw.Widget _cell(
  String text, {
  PdfColor? color,
  PdfColor? bg,
  bool bold = false,
  bool center = false,
}) {
  return pw.Container(
    color: bg,
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
    child: pw.Text(
      text,
      textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
      style: pw.TextStyle(
        fontSize: 7.5,
        color: color ?? PdfColors.black,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}

Future<void> downloadRecordsPdf(
  BuildContext context, {
  required String title,
  required List<String> headers,
  required List<List<String>> rows,
  bool share = false,
}) async {
  if (rows.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF ke liye koi row nahi')),
    );
    return;
  }
  try {
    final bytes = await buildRecordsPdf(title: title, headers: headers, rows: rows);
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final filename = '${title.replaceAll(' ', '_')}_$stamp.pdf';
    if (share) {
      final ok = await sharePdfFile(bytes, filename, title);
      if (ok) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF share ho gaya')),
          );
        }
        return;
      }
    }
    triggerDownload(bytes, filename, 'application/pdf');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$filename download ho gaya (${rows.length} rows)')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF fail: $e'), backgroundColor: Colors.red.shade800),
      );
    }
  }
}

Future<Uint8List> buildRecordsPdf({
  required String title,
  required List<String> headers,
  required List<List<String>> rows,
}) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(22),
      header: (_) => pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(0xFF0B3D91),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Row(
          children: [
            pw.Text(
              title.toUpperCase(),
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Spacer(),
            pw.Text(
              DateFormat('d MMM yyyy, HH:mm').format(DateTime.now()),
              style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
            ),
          ],
        ),
      ),
      footer: (c) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${c.pageNumber} / ${c.pagesCount}   •   ${rows.length} rows',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey),
        ),
      ),
      build: (_) => [
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.blueGrey300, width: 0.5),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF072A66)),
              children: [for (final h in headers) _cell(h, color: PdfColors.white, bold: true)],
            ),
            for (var i = 0; i < rows.length; i++)
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: i.isEven ? PdfColors.white : PdfColor.fromInt(0xFFF4F7FB),
                ),
                children: [
                  for (var c = 0; c < rows[i].length; c++)
                    _cell(
                      rows[i][c],
                      bold: c == 0,
                      bg: c == rows[i].length - 1 && rows[i][c].toLowerCase().contains('paid')
                          ? PdfColor.fromInt(0xFFC8E6C9)
                          : null,
                    ),
                ],
              ),
          ],
        ),
      ],
    ),
  );
  return Uint8List.fromList(await doc.save());
}
