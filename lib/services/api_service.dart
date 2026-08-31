import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/sim_entry.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ApiService {
  static const _timeout = Duration(seconds: 12);

  Uri _uri(String base, String path) {
    final b = base.trim().replaceAll(RegExp(r'/+$'), '');
    if (b.isEmpty) {
      return Uri.parse('${Uri.base.origin}$path');
    }
    return Uri.parse('$b$path');
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
        'Server nahi mila. Terminal: cd server && npm start\n($e)',
      );
    }
  }

  Future<String> ping(String base) async {
    final json = await _send(http.get(_uri(base, '/api/health')));
    if (json['ok'] != true) {
      throw ApiException('${json['error'] ?? 'Ping failed'}');
    }
    return '${json['message'] ?? 'Connected'}';
  }

  Future<List<SimEntry>> list(String base) async {
    final json = await _send(http.get(_uri(base, '/api/sims')));
    if (json['ok'] != true) {
      throw ApiException('${json['error'] ?? 'List failed'}');
    }
    final rows = (json['rows'] as List?) ?? [];
    return [
      for (final r in rows)
        SimEntry.fromSheet(Map<String, dynamic>.from(r as Map)),
    ];
  }

  Future<void> add(String base, SimEntry entry) async {
    final json = await _send(
      http.post(
        _uri(base, '/api/sims'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(entry.toJson()),
      ),
    );
    if (json['ok'] != true) {
      throw ApiException('${json['error'] ?? 'Add failed'}');
    }
  }

  Future<void> update(String base, SimEntry entry) async {
    final id = entry.rowIndex;
    if (id == null) {
      throw ApiException('Entry id nahi mili. Refresh karke dobara try karo.');
    }
    final json = await _send(
      http.put(
        _uri(base, '/api/sims/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(entry.toJson()),
      ),
    );
    if (json['ok'] != true) {
      throw ApiException('${json['error'] ?? 'Update failed'}');
    }
  }

  Future<void> delete(String base, SimEntry entry) async {
    final id = entry.rowIndex;
    if (id == null) {
      throw ApiException('Entry id nahi mili. Refresh karke dobara try karo.');
    }
    final json = await _send(http.delete(_uri(base, '/api/sims/$id')));
    if (json['ok'] != true) {
      throw ApiException('${json['error'] ?? 'Delete failed'}');
    }
  }
}
