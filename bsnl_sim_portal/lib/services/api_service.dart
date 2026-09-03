import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/sim_entry.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
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
  static const _timeout = Duration(seconds: 20);
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
          throw ApiException('${json['error']}');
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
        'Server nahi mila. Terminal: cd backend && npm start\n($e)',
      );
    }
  }

  int? _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v');
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

  Future<List<Map<String, dynamic>>> listRows(
    String base,
    String path, {
    int? locationId,
    String? q,
    String? from,
    String? to,
    String? employee,
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
            'employee': employee,
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
    return [for (final r in rows) Map<String, dynamic>.from(r as Map)];
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

  Future<List<SimEntry>> list(String base, {int? locationId}) async {
    final rows = await listRows(base, '/api/sims', locationId: locationId, limit: 500);
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

  Future<List<Map<String, dynamic>>> listLocations(String base) =>
      listRows(base, '/api/locations');

  Future<void> addLocation(
    String base, {
    required String name,
    String code = '',
    String address = '',
    String status = 'active',
    String email = '',
    String password = '',
  }) async {
    final json = await _send(
      http.post(
        _uri(base, '/api/locations'),
        headers: _headers(),
        body: jsonEncode({
          'name': name,
          'code': code,
          'address': address,
          'status': status,
          if (email.isNotEmpty) 'email': email,
          if (password.isNotEmpty) 'password': password,
        }),
      ),
    );
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Jagah add fail'}');
  }

  Future<void> updateLocation(
    String base,
    int id, {
    required String name,
    String code = '',
    String address = '',
    String status = 'active',
    String email = '',
    String password = '',
  }) async {
    final json = await _send(
      http.put(
        _uri(base, '/api/locations/$id'),
        headers: _headers(),
        body: jsonEncode({
          'name': name,
          'code': code,
          'address': address,
          'status': status,
          if (email.isNotEmpty) 'email': email,
          if (password.isNotEmpty) 'password': password,
        }),
      ),
    );
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Jagah update fail'}');
  }

  Future<void> deleteLocation(String base, int id) async {
    final json = await _send(http.delete(_uri(base, '/api/locations/$id'), headers: _headers()));
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Jagah delete fail'}');
  }

  Future<List<Map<String, dynamic>>> listEmployees(String base) =>
      listRows(base, '/api/employees');

  Future<void> saveEmployee(
    String base, {
    String? id,
    required String name,
    required String email,
    String password = '',
    List<int> assignedLocations = const [],
    String location = '',
    String status = 'active',
  }) async {
    final body = {
      'name': name,
      'email': email,
      'assignedLocations': assignedLocations,
      if (assignedLocations.isNotEmpty) 'locationId': assignedLocations.first,
      if (location.trim().isNotEmpty) 'location': location.trim(),
      if (location.trim().isNotEmpty) 'locationName': location.trim(),
      'status': status,
      if (password.isNotEmpty) 'password': password,
    };
    final json = id == null || id.isEmpty
        ? await _send(http.post(_uri(base, '/api/employees'), headers: _headers(), body: jsonEncode(body)))
        : await _send(
            http.put(
              _uri(base, '/api/employees/${Uri.encodeComponent(id)}'),
              headers: _headers(),
              body: jsonEncode(body),
            ),
          );
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Employee save fail'}');
  }

  Future<void> resetEmployeePassword(String base, String id, String password) async {
    final json = await _send(
      http.post(
        _uri(base, '/api/employees/${Uri.encodeComponent(id)}/reset-password'),
        headers: _headers(),
        body: jsonEncode({'password': password}),
      ),
    );
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Password reset fail'}');
  }

  Future<void> deleteEmployee(String base, String id) async {
    final json = await _send(
      http.delete(_uri(base, '/api/employees/${Uri.encodeComponent(id)}'), headers: _headers()),
    );
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Employee delete fail'}');
  }

  Future<Map<String, dynamic>> summary(String base) async {
    final json = await _send(http.get(_uri(base, '/api/summary'), headers: _headers()));
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Summary fail'}');
    return json;
  }

  Future<Map<String, dynamic>> locationSummary(String base, int id) async {
    final json = await _send(http.get(_uri(base, '/api/summary/location/$id'), headers: _headers()));
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Summary fail'}');
    return json['location'] is Map
        ? Map<String, dynamic>.from(json['location'] as Map)
        : json;
  }

  Future<Map<String, dynamic>> reports(
    String base, {
    required String type,
    String? from,
    String? to,
    int? locationId,
    String? employee,
  }) async {
    final json = await _send(
      http.get(
        _uri(
          base,
          _withQuery('/api/reports', {
            'type': type,
            'from': from,
            'to': to,
            'locationId': locationId?.toString(),
            'employee': employee,
          }),
        ),
        headers: _headers(),
      ),
    );
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Report fail'}');
    return json;
  }

  Future<Map<String, dynamic>> activityPage(
    String base, {
    int? locationId,
    String? employee,
    String? action,
    String? q,
    String? from,
    String? to,
    int page = 1,
    int limit = 40,
  }) async {
    final json = await _send(
      http.get(
        _uri(
          base,
          _withQuery('/api/activity', {
            'locationId': locationId?.toString(),
            'employee': employee,
            'action': action,
            'q': q,
            'from': from,
            'to': to,
            'page': '$page',
            'limit': '$limit',
          }),
        ),
        headers: _headers(),
      ),
    );
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Activity fail'}');
    return json;
  }

  Future<List<Map<String, dynamic>>> activity(String base) async {
    final json = await activityPage(base, limit: 40);
    final rows = (json['rows'] as List?) ?? [];
    return [for (final r in rows) Map<String, dynamic>.from(r as Map)];
  }
}
