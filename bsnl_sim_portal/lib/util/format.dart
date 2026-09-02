import 'package:intl/intl.dart';

String rupee(num n) {
  final f = NumberFormat.decimalPattern('en_IN');
  return '₹${f.format(n.round())}';
}

int? asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v');
}

num asNum(dynamic v) {
  if (v is num) return v;
  return num.tryParse('$v') ?? 0;
}

List<Map<String, dynamic>> asMaps(dynamic v) {
  if (v is! List) return [];
  return [for (final r in v) if (r is Map) Map<String, dynamic>.from(r)];
}
