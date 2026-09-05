import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/sim_entry.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.needsCreate = false, this.locationName = '', this.duplicate = false});
  final String message;
  final bool needsCreate;
  final String locationName;
  final bool duplicate;
  @override
  String toString() => message;
}

class PagedRows {
  PagedRows({
    required this.rows,
    required this.total,
    this.page = 1,
    this.limit = 50,
    this.walletAmount = 0,
    this.remainingBalance = 0,
    this.totalAdded = 0,
    this.totalUsed = 0,
    this.combinedCommission = 0,
    this.totalCommission = 0,
    this.previousBalance = 0,
    this.cbpCommissionPercent = 0,
    this.ctopupCommissionPercent = 0,
  });
  final List<Map<String, dynamic>> rows;
  final int total;
  final int page;
  final int limit;
  final num walletAmount;
  final num remainingBalance;
  final num totalAdded;
  final num totalUsed;
  final num combinedCommission;
  final num totalCommission;
  final num previousBalance;
  final num cbpCommissionPercent;
  final num ctopupCommissionPercent;
}

class LoginResult {
  LoginResult({
    required this.token,
    required this.email,
    required this.role,
    required this.name,
    this.locationId,
    this.locationName = '',
    this.assignedLocations = const [],
  });
  final String token;
  final String email;
  final String role;
  final String name;
  final int? locationId;
  final String locationName;
  final List<int> assignedLocations;
}

class ApiService {
  static const _timeout = Duration(seconds: 45);
  String? Function()? tokenGetter;
  int? Function()? locationIdGetter;

  Uri _uri(String base, String path) {
    final b = base.trim().replaceAll(RegExp(r'/+$'), '');
    if (b.isEmpty) {
      return Uri.parse('${Uri.base.origin}$path');
    }
    return Uri.parse('$b$path');
  }

  Map<String, String> _headers({int? locationId}) {
    final token = tokenGetter?.call();
    final loc = locationId ?? locationIdGetter?.call();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (loc != null) 'X-Location-Id': '$loc',
    };
  }

  Map<String, dynamic> _decode(http.Response res) {
    if (res.statusCode >= 400) {
      try {
        final json = jsonDecode(res.body);
        if (json is Map && json['error'] != null) {
          throw ApiException(
            '${json['error']}',
            needsCreate: json['needsCreate'] == true,
            locationName: '${json['locationName'] ?? ''}',
            duplicate: json['duplicate'] == true,
          );
        }
      } catch (e) {
        if (e is ApiException) rethrow;
      }
      throw ApiException('Server error ${res.statusCode}');
    }
    final json = jsonDecode(res.body);
    if (json is! Map) throw ApiException('Bad server response');
    return Map<String, dynamic>.from(json);
  }

  Future<Map<String, dynamic>> _send(Future<http.Response> future) async {
    try {
      final res = await future.timeout(_timeout);
      return _decode(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        'Server se connect nahi ho paya. Internet check karo, 10 second baad Retry dabao.',
      );
    }
  }

  int? _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v');
  }

  num _num(dynamic v) {
    if (v is num) return v;
    return num.tryParse('$v') ?? 0;
  }

  List<int> _ints(dynamic v) {
    if (v is! List) return [];
    return [for (final x in v) if (_int(x) != null) _int(x)!];
  }

  String _withQuery(String path, Map<String, String?> q) {
    final parts = <String>[];
    q.forEach((k, v) {
      if (v != null && v.trim().isNotEmpty) {
        parts.add('${Uri.encodeQueryComponent(k)}=${Uri.encodeQueryComponent(v.trim())}');
      }
    });
    if (parts.isEmpty) return path;
    return '$path${path.contains('?') ? '&' : '?'}${parts.join('&')}';
  }

  Future<LoginResult> login(String base, String email, String password) async {
    final json = await _send(
      http.post(
        _uri(base, '/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ),
    );
    if (json['ok'] != true) {
      throw ApiException('${json['error'] ?? 'Login failed'}');
    }
    final user = json['user'] is Map ? Map<String, dynamic>.from(json['user'] as Map) : {};
    return LoginResult(
      token: '${json['token'] ?? ''}',
      email: '${user['email'] ?? email}',
      role: '${user['role'] ?? ''}',
      name: '${user['name'] ?? ''}',
      locationId: _int(user['locationId']),
      locationName: '${user['locationName'] ?? ''}',
      assignedLocations: _ints(user['assignedLocations']),
    );
  }

  Future<Map<String, dynamic>> me(String base) async {
    final json = await _send(http.get(_uri(base, '/api/me'), headers: _headers()));
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Session invalid'}');
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : <String, dynamic>{};
    if (json['token'] != null) user['token'] = json['token'];
    return user;
  }

  Future<String> ping(String base) async {
    final json = await _send(http.get(_uri(base, '/api/health')));
    if (json['ok'] != true) {
      throw ApiException('${json['error'] ?? 'Ping failed'}');
    }
    return '${json['message'] ?? 'Connected'}';
  }

  Future<PagedRows> listPage(
    String base,
    String path, {
    int? locationId,
    String? q,
    String? from,
    String? to,
    String? status,
    String? type,
    String? txnType,
    String? minAmount,
    String? maxAmount,
    String? sort,
    String? order,
    int? page,
    int? limit,
  }) async {
    final json = await _send(
      http.get(
        _uri(
          base,
          _withQuery(path, {
            'locationId': locationId?.toString(),
            'q': q,
            'from': from,
            'to': to,
            'status': status,
            'type': type,
            'txnType': txnType,
            'minAmount': minAmount,
            'maxAmount': maxAmount,
            'sort': sort,
            'order': order,
            'page': page?.toString(),
            'limit': limit?.toString(),
          }),
        ),
        headers: _headers(locationId: locationId),
      ),
    );
    if (json['ok'] != true) {
      throw ApiException('${json['error'] ?? 'List failed'}');
    }
    final rows = (json['rows'] as List?) ?? [];
    return PagedRows(
      rows: [for (final r in rows) Map<String, dynamic>.from(r as Map)],
      total: _int(json['total']) ?? rows.length,
      page: _int(json['page']) ?? (page ?? 1),
      limit: _int(json['limit']) ?? (limit ?? rows.length),
      walletAmount: _num(json['walletAmount'] ?? json['totalCreditsNum'] ?? json['totalAdded'] ?? json['currentBalanceNum']),
      remainingBalance: _num(json['remainingBalance'] ?? json['currentBalanceNum'] ?? json['currentBalance']),
      totalAdded: _num(json['totalAdded'] ?? json['totalCreditsNum'] ?? json['totalCredits'] ?? json['walletAmount']),
      totalUsed: _num(json['totalUsed'] ?? json['totalTransactionAmountNum'] ?? json['totalTransactionAmount'] ?? json['combinedAmount']),
      combinedCommission: _num(json['combinedCommission'] ?? json['totalCommissionNum'] ?? json['totalCommission']),
      totalCommission: _num(json['totalCommissionNum'] ?? json['totalCommission'] ?? json['combinedCommission']),
      previousBalance: _num(json['previousBalance'] ?? json['currentBalanceNum'] ?? json['currentBalance'] ?? json['remainingBalance']),
      cbpCommissionPercent: _num(json['cbpCommissionPercent']),
      ctopupCommissionPercent: _num(json['ctopupCommissionPercent']),
    );
  }

  Future<List<Map<String, dynamic>>> listRows(
    String base,
    String path, {
    int? locationId,
    String? q,
    String? from,
    String? to,
    String? status,
    String? type,
    String? txnType,
    String? minAmount,
    String? maxAmount,
    String? sort,
    String? order,
    int? page,
    int? limit,
  }) async {
    final out = await listPage(
      base,
      path,
      locationId: locationId,
      q: q,
      from: from,
      to: to,
      status: status,
      type: type,
      txnType: txnType,
      minAmount: minAmount,
      maxAmount: maxAmount,
      sort: sort,
      order: order,
      page: page,
      limit: limit,
    );
    return out.rows;
  }

  Future<void> addRow(String base, String path, Map<String, dynamic> body, {int? locationId}) async {
    final json = await _send(
      http.post(
        _uri(base, path),
        headers: _headers(locationId: locationId),
        body: jsonEncode({
          ...body,
          'locationId': ?locationId,
        }),
      ),
    );
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Add failed'}');
  }

  Future<void> updateRow(String base, String path, int id, Map<String, dynamic> body, {int? locationId}) async {
    final json = await _send(
      http.put(
        _uri(base, '$path/$id'),
        headers: _headers(locationId: locationId),
        body: jsonEncode({
          ...body,
          'locationId': ?locationId,
        }),
      ),
    );
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Update failed'}');
  }

  Future<void> deleteRow(String base, String path, int id, {int? locationId}) async {
    final json = await _send(
      http.delete(
        _uri(base, _withQuery('$path/$id', {'locationId': locationId?.toString()})),
        headers: _headers(locationId: locationId),
      ),
    );
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Delete failed'}');
  }

  Future<List<SimEntry>> list(
    String base, {
    int? locationId,
    String? from,
    String? to,
    String? sort,
    String? order,
  }) async {
    final rows = await listRows(
      base,
      '/api/sims',
      locationId: locationId,
      from: from,
      to: to,
      sort: sort,
      order: order,
      limit: 500,
    );
    return [for (final r in rows) SimEntry.fromSheet(r)];
  }

  Future<void> add(String base, SimEntry entry, {int? locationId}) =>
      addRow(base, '/api/sims', entry.toJson(), locationId: locationId);

  Future<void> update(String base, SimEntry entry, {int? locationId}) async {
    final id = entry.rowIndex;
    if (id == null) {
      throw ApiException('Entry id nahi mili. Refresh karke dobara try karo.');
    }
    await updateRow(base, '/api/sims', id, entry.toJson(), locationId: locationId);
  }

  Future<void> delete(String base, SimEntry entry, {int? locationId}) async {
    final id = entry.rowIndex;
    if (id == null) {
      throw ApiException('Entry id nahi mili. Refresh karke dobara try karo.');
    }
    await deleteRow(base, '/api/sims', id, locationId: locationId);
  }

  Future<Map<String, dynamic>> search(String base, String q) async {
    final json = await _send(
      http.get(_uri(base, _withQuery('/api/search', {'q': q})), headers: _headers()),
    );
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Search fail'}');
    return json['groups'] is Map ? Map<String, dynamic>.from(json['groups'] as Map) : {};
  }

  Future<void> logoutAudit(String base) async {
    try {
      await _send(http.post(_uri(base, '/api/logout'), headers: _headers()));
    } catch (_) {}
  }

  Future<Map<String, dynamic>> dashboard(String base, {String? from, String? to, String? period}) async {
    final json = await _send(
      http.get(
        _uri(base, _withQuery('/api/dashboard', {'from': from, 'to': to, 'period': period})),
        headers: _headers(),
      ),
    );
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Dashboard fail'}');
    return json;
  }

  String _servicePath(String service) {
    final s = service.trim().toLowerCase();
    if (s == 'ctopup' || s == 'c-topup' || s == 'topup') return 'ctopup';
    return 'cbp';
  }

  Future<Map<String, dynamic>> serviceWallet(String base, String service) async {
    final json = await _send(http.get(_uri(base, '/api/wallet/${_servicePath(service)}'), headers: _headers()));
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Wallet fail'}');
    return json;
  }

  Future<PagedRows> serviceLedger(String base, String service, {
    String? q,
    String? from,
    String? to,
    String? txnType,
    int? page,
    int? limit,
  }) {
    return listPage(
      base,
      '/api/wallet/${_servicePath(service)}/ledger',
      q: q,
      from: from,
      to: to,
      txnType: txnType,
      page: page,
      limit: limit,
    );
  }

  Future<PagedRows> serviceCommission(String base, String service, {
    String? q,
    String? from,
    String? to,
    int? page,
    int? limit,
  }) {
    return listPage(
      base,
      '/api/wallet/${_servicePath(service)}/commission',
      q: q,
      from: from,
      to: to,
      page: page,
      limit: limit,
    );
  }

  Future<Map<String, dynamic>> addServiceMoney(String base, String service, String amount, {String remark = '', String source = 'manual'}) async {
    final json = await _send(
      http.post(
        _uri(base, '/api/wallet/${_servicePath(service)}/add-money'),
        headers: _headers(),
        body: jsonEncode({'amount': amount, 'remark': remark, 'source': source}),
      ),
    );
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Add money fail'}');
    return json;
  }

  Future<Map<String, dynamic>> withdrawServiceMoney(String base, String service, String amount, {String reason = ''}) async {
    final json = await _send(
      http.post(
        _uri(base, '/api/wallet/${_servicePath(service)}/withdraw'),
        headers: _headers(),
        body: jsonEncode({'amount': amount, 'reason': reason}),
      ),
    );
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Withdraw fail'}');
    return json;
  }

  Future<Map<String, dynamic>> reverseServiceTxn(String base, String service, {int? id, String? transactionId}) async {
    final json = await _send(
      http.post(
        _uri(base, '/api/wallet/${_servicePath(service)}/reversal'),
        headers: _headers(),
        body: jsonEncode({
          'id': ?id,
          'transactionId': ?transactionId,
        }),
      ),
    );
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Reversal fail'}');
    return json;
  }

  Future<Map<String, dynamic>> appConfig(String base) async {
    final json = await _send(http.get(_uri(base, '/api/config'), headers: _headers()));
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Config fail'}');
    return json;
  }

  Future<Map<String, dynamic>> walletSummary(String base) async {
    final json = await _send(http.get(_uri(base, '/api/wallet/summary'), headers: _headers()));
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Wallet fail'}');
    return json;
  }

  Future<Map<String, dynamic>> saveWallet(String base, String amount, {String remark = ''}) async {
    final json = await _send(
      http.post(
        _uri(base, '/api/wallet/transactions'),
        headers: _headers(),
        body: jsonEncode({'amount': amount, 'remark': remark}),
      ),
    );
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Wallet add fail'}');
    return json;
  }

  Future<void> updateProfile(String base, String name) async {
    final json = await _send(
      http.put(_uri(base, '/api/me'), headers: _headers(), body: jsonEncode({'name': name})),
    );
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Profile update fail'}');
  }

  Future<void> changePassword(String base, String current, String next) async {
    final json = await _send(
      http.post(
        _uri(base, '/api/me/password'),
        headers: _headers(),
        body: jsonEncode({'current': current, 'next': next}),
      ),
    );
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Password change fail'}');
  }
}
