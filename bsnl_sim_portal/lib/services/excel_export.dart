import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/sim_entry.dart';
import 'file_download.dart';

Future<void> downloadSimExcel(
  BuildContext context,
  List<SimEntry> rows,
) async {
  if (rows.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Download ke liye koi row nahi')),
    );
    return;
  }

  try {
    final bytes = buildSimExcel(rows);
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final filename = 'BSNL_SIM_Register_$stamp.xlsx';
    triggerDownload(
      bytes,
      filename,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$filename download ho gaya (${rows.length} rows)')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel download fail: $e'), backgroundColor: Colors.red.shade800),
      );
    }
  }
}

Uint8List buildSimExcel(List<SimEntry> rows) {
  final excel = Excel.createExcel();
  const sheetName = 'SIM Register';
  final sheet = excel[sheetName];
  final defaultSheet = excel.getDefaultSheet();
  if (defaultSheet != null && defaultSheet != sheetName) {
    excel.delete(defaultSheet);
  }

  const headers = [
    '#',
    'Date',
    'Name',
    'Type',
    'Mobile',
    'Alternate Number',
    'FRC',
    'SIM No.',
    'SIM Last 6',
    'Status',
  ];
  sheet.appendRow([for (final h in headers) TextCellValue(h)]);

  for (var i = 0; i < rows.length; i++) {
    final e = rows[i];
    sheet.appendRow([
      IntCellValue(i + 1),
      TextCellValue(e.date),
      TextCellValue(e.name),
      TextCellValue(e.type.label),
      TextCellValue(e.mobile),
      TextCellValue(e.altNumber),
      TextCellValue(e.frc),
      TextCellValue(e.simNo),
      TextCellValue(e.last6),
      TextCellValue(e.status),
    ]);
  }

  final encoded = excel.encode();
  if (encoded == null) {
    throw StateError('Excel encode failed');
  }
  return Uint8List.fromList(encoded);
}

Future<void> downloadMapExcel(
  BuildContext context,
  String title,
  List<Map<String, dynamic>> rows,
) async {
  if (rows.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Download ke liye koi row nahi')),
    );
    return;
  }
  try {
    final excel = Excel.createExcel();
    final sheetName = title.replaceAll(RegExp(r'[^A-Za-z0-9 ]'), '').trim();
    final name = sheetName.isEmpty ? 'Report' : sheetName.substring(0, sheetName.length > 28 ? 28 : sheetName.length);
    final sheet = excel[name];
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != name) {
      excel.delete(defaultSheet);
    }
    final headers = rows.first.keys.map((k) => '$k').toList();
    sheet.appendRow([for (final h in headers) TextCellValue(h)]);
    for (final row in rows) {
      sheet.appendRow([
        for (final h in headers) TextCellValue('${row[h] ?? ''}'),
      ]);
    }
    final encoded = excel.encode();
    if (encoded == null) throw StateError('Excel encode failed');
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final filename = '${name.replaceAll(' ', '_')}_$stamp.xlsx';
    triggerDownload(
      Uint8List.fromList(encoded),
      filename,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$filename download ho gaya (${rows.length} rows)')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel download fail: $e'), backgroundColor: Colors.red.shade800),
      );
    }
  }
}
