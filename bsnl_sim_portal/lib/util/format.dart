import 'package:intl/intl.dart';

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

String rupee(num n) => _inr.format(n);

int? asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v');
}

num asNum(dynamic v) {
  if (v is num) return v;
  final s = '$v'.replaceAll(',', '').replaceAll('₹', '').trim();
  return num.tryParse(s) ?? 0;
}

List<Map<String, dynamic>> asMaps(dynamic v) {
  if (v is! List) return [];
  return [for (final r in v) if (r is Map) Map<String, dynamic>.from(r)];
}
