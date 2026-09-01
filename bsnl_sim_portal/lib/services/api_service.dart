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
  });
  final String token;
  final String email;
  final String role;
  final String name;
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
    );
  }

  Future<Map<String, dynamic>> me(String base) async {
    final json = await _send(http.get(_uri(base, '/api/me'), headers: _headers()));
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Session invalid'}');
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : <String, dynamic>{};
    return user;
  }

  Future<String> ping(String base) async {
    final json = await _send(http.get(_uri(base, '/api/health')));
    if (json['ok'] != true) {
      throw ApiException('${json['error'] ?? 'Ping failed'}');
    }
    return '${json['message'] ?? 'Connected'}';
  }

  Future<List<Map<String, dynamic>>> listRows(String base, String path) async {
    final json = await _send(http.get(_uri(base, path), headers: _headers()));
    if (json['ok'] != true) {
      throw ApiException('${json['error'] ?? 'List failed'}');
    }
    final rows = (json['rows'] as List?) ?? [];
    return [
      for (final r in rows) Map<String, dynamic>.from(r as Map),
    ];
  }

  Future<void> addRow(String base, String path, Map<String, dynamic> body) async {
    final json = await _send(
      http.post(
        _uri(base, path),
        headers: _headers(),
        body: jsonEncode(body),
      ),
    );
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Add failed'}');
  }

  Future<void> updateRow(String base, String path, int id, Map<String, dynamic> body) async {
    final json = await _send(
      http.put(
        _uri(base, '$path/$id'),
        headers: _headers(),
        body: jsonEncode(body),
      ),
    );
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Update failed'}');
  }

  Future<void> deleteRow(String base, String path, int id) async {
    final json = await _send(
      http.delete(_uri(base, '$path/$id'), headers: _headers()),
    );
    if (json['ok'] != true) throw ApiException('${json['error'] ?? 'Delete failed'}');
  }

  Future<List<SimEntry>> list(String base) async {
    final rows = await listRows(base, '/api/sims');
    return [for (final r in rows) SimEntry.fromSheet(r)];
  }

  Future<void> add(String base, SimEntry entry) =>
      addRow(base, '/api/sims', entry.toJson());

  Future<void> update(String base, SimEntry entry) async {
    final id = entry.rowIndex;
    if (id == null) {
      throw ApiException('Entry id nahi mili. Refresh karke dobara try karo.');
    }
    await updateRow(base, '/api/sims', id, entry.toJson());
  }

  Future<void> delete(String base, SimEntry entry) async {
    final id = entry.rowIndex;
    if (id == null) {
      throw ApiException('Entry id nahi mili. Refresh karke dobara try karo.');
    }
    await deleteRow(base, '/api/sims', id);
  }
}
