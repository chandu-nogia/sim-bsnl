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
  });
  final String token;
  final String email;
  final String role;
  final String name;
  final int? locationId;
  final String locationName;
}

class ApiService {
  static const _timeout = Duration(seconds: 12);
  String? Function()? tokenGetter;

  Uri _uri(String base, String path) {
    final b = base.trim().replaceAll(RegExp(r'/+$'), '');
    if (b.isEmpty) {
      return Uri.parse('${Uri.base.origin}$path');
    }
    return Uri.parse('$b$path');
  }

  Map<String, String> _headers() {
    final token = tokenGetter?.call();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
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
    );
  }

  int? _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v');
  }

  String _withLocation(String path, int? locationId) {
    if (locationId == null) return path;
    return '$path${path.contains('?') ? '&' : '?'}locationId=$locationId';
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

  Future<List<Map<String, dynamic>>> listRows(String base, String path, {int? locationId}) async {
    final json = await _send(http.get(_uri(base, _withLocation(path, locationId)), headers: _headers()));
    if (json['ok'] != true) {
      throw ApiException('${json['error'] ?? 'List failed'}');
    }
    final rows = (json['rows'] as List?) ?? [];
    return [
      for (final r in rows) Map<String, dynamic>.from(r as Map),
    ];
  }

  Future<void> addRow(String base, String path, Map<String, dynamic> body, {int? locationId}) async {
    final json = await _send(
      http.post(
        _uri(base, path),
        headers: _headers(),
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
        headers: _headers(),
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
      http.delete(_uri(base, _withLocation('$path/$id', locationId)), headers: _headers()),
    );
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Delete failed'}');
  }

  Future<List<SimEntry>> list(String base, {int? locationId}) async {
    final rows = await listRows(base, '/api/sims', locationId: locationId);
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

  Future<void> addLocation(String base, {required String name, required String email, required String password}) async {
    final json = await _send(
      http.post(
        _uri(base, '/api/locations'),
        headers: _headers(),
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      ),
    );
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Jagah add fail'}');
  }

  Future<void> updateLocation(
    String base,
    int id, {
    required String name,
    required String email,
    String password = '',
  }) async {
    final json = await _send(
      http.put(
        _uri(base, '/api/locations/$id'),
        headers: _headers(),
        body: jsonEncode({
          'name': name,
          'email': email,
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

  Future<Map<String, dynamic>> summary(String base) async {
    final json = await _send(http.get(_uri(base, '/api/summary'), headers: _headers()));
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Summary fail'}');
    return json;
  }

  Future<List<Map<String, dynamic>>> activity(String base) => listRows(base, '/api/activity');
}
