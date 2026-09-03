import 'package:flutter/material.dart';
import '../app_theme.dart';

enum SimType {
  cymn('CYMN', 'Company New', BsnlColors.cymn),
  mnp('MNP', 'Mobile Number Portability', BsnlColors.mnp),
  swap('Swap', 'SIM swap', BsnlColors.swap),
  postpaid('Postpaid', 'P SWAP / Postpaid', BsnlColors.postpaid);

  const SimType(this.label, this.meaning, this.color);
  final String label;
  final String meaning;
  final Color color;

  static SimType? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final t = raw.trim().toLowerCase();
    for (final v in SimType.values) {
      if (v.label.toLowerCase() == t) return v;
    }
    if (t == 'replace' || t == 'p swap' || t == 'pswap') return SimType.swap;
    return null;
  }
}

const frcChoices = ['0', '1', '2', '3', '4', '5'];

Color frcChipColor(String frc) {
  return switch (frc) {
    '0' => const Color(0xFFCFD8DC),
    '1' => BsnlColors.cymn,
    '2' => BsnlColors.mnp,
    '3' => BsnlColors.issued,
    '4' => BsnlColors.swap,
    '5' => const Color(0xFFFFCDD2),
    _ => const Color(0xFFEEEEEE),
  };
}

class SimEntry {
  SimEntry({
    this.rowIndex,
    required this.date,
    required this.sno,
    required this.name,
    this.altNumber = '',
    this.frc = '',
    required this.type,
    required this.mobile,
    required this.simNo,
    this.simLast6 = '',
    this.status = 'Issued',
    this.locationId,
    this.locationName = '',
  });

  final int? rowIndex;
  final String date;
  final int sno;
  final String name;
  final String altNumber;
  final String frc;
  final SimType type;
  final String mobile;
  final String simNo;
  final String simLast6;
  final String status;
  final int? locationId;
  final String locationName;

  String get last6 {
    if (simLast6.isNotEmpty) return simLast6;
    final d = simNo.replaceAll(RegExp(r'\D'), '');
    if (d.length >= 6) return d.substring(d.length - 6);
    return d;
  }

  SimEntry copyWith({
    int? rowIndex,
    String? date,
    int? sno,
    String? name,
    String? altNumber,
    String? frc,
    SimType? type,
    String? mobile,
    String? simNo,
    String? simLast6,
    String? status,
    int? locationId,
    String? locationName,
  }) {
    return SimEntry(
      rowIndex: rowIndex ?? this.rowIndex,
      date: date ?? this.date,
      sno: sno ?? this.sno,
      name: name ?? this.name,
      altNumber: altNumber ?? this.altNumber,
      frc: frc ?? this.frc,
      type: type ?? this.type,
      mobile: mobile ?? this.mobile,
      simNo: simNo ?? this.simNo,
      simLast6: simLast6 ?? this.simLast6,
      status: status ?? this.status,
      locationId: locationId ?? this.locationId,
      locationName: locationName ?? this.locationName,
    );
  }

  Map<String, String> toSheetMap() => {
        if (rowIndex != null) 'rowIndex': '$rowIndex',
        'date': date,
        'sno': '$sno',
        'name': name,
        'alt': altNumber,
        'frc': frc,
        'type': type.label,
        'mobile': mobile,
        'sim': simNo,
        'last6': last6,
        'status': status,
      };

  factory SimEntry.fromSheet(Map<String, dynamic> m, {int? rowIndex}) {
    String s(String a, [String b = '']) =>
        '${m[a] ?? m[b] ?? ''}'.trim();
    final rawRow = m['rowIndex'];
    final parsedRow = switch (rawRow) {
      int v => v,
      num v => v.toInt(),
      _ => int.tryParse('${rawRow ?? ''}'),
    };
    return SimEntry(
      rowIndex: rowIndex ?? parsedRow,
      date: s('date', 'Date'),
      sno: int.tryParse(s('sno', 'S.No.')) ?? 0,
      name: s('name', 'Name'),
      altNumber: s('alt', 'Alternate Number'),
      frc: s('frc', 'FRC'),
      type: SimType.tryParse(s('type', 'Type')) ?? SimType.cymn,
      mobile: s('mobile', 'Mobile Number'),
      simNo: s('sim', 'SIM No.'),
      simLast6: s('last6', 'SIM Last 6'),
      status: s('status', 'Status').isEmpty ? 'Issued' : s('status', 'Status'),
      locationId: int.tryParse('${m['locationId'] ?? ''}'),
      locationName: s('locationName'),
    );
  }

  Map<String, dynamic> toJson() => {
        if (rowIndex != null) 'rowIndex': rowIndex,
        'date': date,
        'sno': sno,
        'name': name,
        'alt': altNumber,
        'frc': frc,
        'type': type.label,
        'mobile': mobile,
        'sim': simNo,
        'last6': last6,
        'status': status,
        if (locationId != null) 'locationId': locationId,
      };

  factory SimEntry.fromJson(Map<String, dynamic> j) => SimEntry.fromSheet(j);
}
