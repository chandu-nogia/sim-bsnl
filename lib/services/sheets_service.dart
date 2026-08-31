import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../models/sim_entry.dart';

class SheetsException implements Exception {
  SheetsException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SheetsService {
  Future<Map<String, dynamic>> call(
    String scriptUrl,
    Map<String, String> params,
  ) async {
    final uri = Uri.parse(scriptUrl.trim()).replace(
      queryParameters: {
        ...Uri.parse(scriptUrl).queryParameters,
        ...params,
      },
    );
    return _jsonp(uri.toString());
  }

  Future<List<SimEntry>> list(String scriptUrl) async {
    final res = await call(scriptUrl, {'action': 'list'});
    if (res['ok'] != true) {
      throw SheetsException('${res['error'] ?? 'List failed'}');
    }
    final rows = (res['rows'] as List?) ?? [];
    return [
      for (final r in rows)
        SimEntry.fromSheet(Map<String, dynamic>.from(r as Map)),
    ];
  }

  Future<void> add(String scriptUrl, SimEntry entry) async {
    final res = await call(scriptUrl, {
      'action': 'add',
      ...entry.toSheetMap(),
    });
    if (res['ok'] != true) {
      throw SheetsException('${res['error'] ?? 'Add failed'}');
    }
  }

  Future<void> update(String scriptUrl, SimEntry entry) async {
    if (entry.rowIndex == null) {
      throw SheetsException('Sheet row nahi mili. Refresh karke dobara try karo.');
    }
    final res = await call(scriptUrl, {
      'action': 'update',
      ...entry.toSheetMap(),
    });
    if (res['ok'] != true) {
      throw SheetsException('${res['error'] ?? 'Update failed'}');
    }
  }

  Future<void> delete(String scriptUrl, SimEntry entry) async {
    if (entry.rowIndex == null) {
      throw SheetsException('Sheet row nahi mili. Refresh karke dobara try karo.');
    }
    final res = await call(scriptUrl, {
      'action': 'delete',
      'rowIndex': '${entry.rowIndex}',
    });
    if (res['ok'] != true) {
      throw SheetsException('${res['error'] ?? 'Delete failed'}');
    }
  }

  Future<String> ping(String scriptUrl) async {
    final res = await call(scriptUrl, {'action': 'ping'});
    if (res['ok'] != true) {
      throw SheetsException('${res['error'] ?? 'Ping failed'}');
    }
    return '${res['message'] ?? 'Connected'}';
  }

  Future<Map<String, dynamic>> _jsonp(String url) async {
    final name = 'bsnlCb${DateTime.now().microsecondsSinceEpoch}';
    final completer = Completer<Map<String, dynamic>>();

    globalContext.setProperty(
      name.toJS,
      ((JSAny? data) {
        try {
          final dart = data.dartify();
          if (dart is Map) {
            completer.complete(Map<String, dynamic>.from(dart));
          } else {
            completer.complete(
              jsonDecode(jsonEncode(dart)) as Map<String, dynamic>,
            );
          }
        } catch (e) {
          completer.completeError(SheetsException('Bad sheet response: $e'));
        }
      }).toJS,
    );

    final sep = url.contains('?') ? '&' : '?';
    final script = web.HTMLScriptElement()
      ..async = true
      ..src = '$url${sep}callback=$name';

    script.onError.listen((_) {
      if (!completer.isCompleted) {
        completer.completeError(
          SheetsException(
            'Google Script tak pahunch nahi paaye. Deploy "Anyone" se karein, URL check karein.',
          ),
        );
      }
    });

    web.document.head!.append(script);

    try {
      return await completer.future.timeout(
        const Duration(seconds: 25),
        onTimeout: () => throw SheetsException(
          'Timeout — Script URL aur Deploy access (Anyone) check karein.',
        ),
      );
    } finally {
      script.remove();
    }
  }
}
