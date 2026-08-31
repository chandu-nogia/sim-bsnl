import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/seed.dart';
import '../models/sim_entry.dart';
import '../services/api_service.dart';

class SimStore extends ChangeNotifier {
  SimStore() {
    load();
  }

  final _api = ApiService();

  List<SimEntry> entries = [];
  String search = '';
  String typeFilter = 'All';
  String frcFilter = 'All';
  String? apiUrl;
  bool useApi = true;
  bool loading = true;
  bool connected = false;
  String? error;
  String? statusMessage;

  String get apiBase {
    final saved = (apiUrl ?? '').trim().replaceAll(RegExp(r'/+$'), '');
    if (saved.isNotEmpty) return saved;
    if (kReleaseMode) return '';
    return 'http://localhost:5050';
  }

  List<SimEntry> get filtered {
    final q = search.trim().toLowerCase();
    return entries.where((e) {
      if (typeFilter != 'All' && e.type.label != typeFilter) return false;
      if (frcFilter != 'All' && e.frc != frcFilter) return false;
      if (q.isEmpty) return true;
      return e.name.toLowerCase().contains(q) ||
          e.mobile.contains(q) ||
          e.simNo.contains(q) ||
          e.altNumber.contains(q) ||
          e.last6.contains(q) ||
          '${e.sno}'.contains(q);
    }).toList();
  }

  Map<String, int> get counts {
    final m = {for (final t in SimType.values) t.label: 0};
    for (final e in entries) {
      m[e.type.label] = (m[e.type.label] ?? 0) + 1;
    }
    return m;
  }

  int get nextSno {
    if (entries.isEmpty) return 1;
    return entries.map((e) => e.sno).fold<int>(0, (a, b) => a > b ? a : b) + 1;
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    apiUrl = prefs.getString('apiUrl') ?? prefs.getString('scriptUrl');
    if (apiUrl != null && apiUrl!.contains('script.google.com')) {
      apiUrl = null;
    }
    useApi = prefs.getBool('useApi') ?? true;
    try {
      if (useApi) {
        entries = await _api.list(apiBase);
        connected = true;
        final host = apiBase.isEmpty ? 'is site' : apiBase;
        statusMessage = 'Server ($host) se ${entries.length} entries';
      } else {
        connected = false;
        await _loadLocal(prefs);
        statusMessage = 'Local mode — Settings se Node server jodo';
      }
    } catch (e) {
      connected = false;
      error = e.toString();
      statusMessage = null;
      try {
        await _loadLocal(prefs);
        statusMessage =
            'Server nahi mila, local data dikh raha hai. cd server && npm start';
        error = null;
      } catch (_) {}
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadLocal(SharedPreferences prefs) async {
    final raw = prefs.getString('localEntries');
    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List;
      entries = [
        for (final j in list)
          SimEntry.fromJson(Map<String, dynamic>.from(j as Map)),
      ];
    } else {
      entries = List.of(seedEntries);
      await _saveLocal();
    }
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'localEntries',
      jsonEncode([for (final e in entries) e.toJson()]),
    );
  }

  Future<void> saveApiUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    apiUrl = url.trim().isEmpty ? null : url.trim().replaceAll(RegExp(r'/+$'), '');
    useApi = true;
    if (apiUrl == null) {
      await prefs.remove('apiUrl');
    } else {
      await prefs.setString('apiUrl', apiUrl!);
    }
    await prefs.setBool('useApi', true);
    notifyListeners();
    await load();
  }

  Future<void> disconnect() async {
    final prefs = await SharedPreferences.getInstance();
    useApi = false;
    connected = false;
    await prefs.setBool('useApi', false);
    notifyListeners();
    await load();
  }

  void setSearch(String v) {
    search = v;
    notifyListeners();
  }

  void setTypeFilter(String v) {
    typeFilter = typeFilter == v && v != 'All' ? 'All' : v;
    notifyListeners();
  }

  void setFrcFilter(String v) {
    frcFilter = v;
    notifyListeners();
  }

  void clearFilters() {
    search = '';
    typeFilter = 'All';
    frcFilter = 'All';
    notifyListeners();
  }

  int _indexOf(SimEntry entry) {
    if (entry.rowIndex != null) {
      final i = entries.indexWhere((e) => e.rowIndex == entry.rowIndex);
      if (i >= 0) return i;
    }
    final ident = entries.indexWhere((e) => identical(e, entry));
    if (ident >= 0) return ident;
    return entries.indexWhere(
      (e) => e.sno == entry.sno && e.mobile == entry.mobile && e.simNo == entry.simNo,
    );
  }

  Future<void> addEntry(SimEntry entry) async {
    error = null;
    notifyListeners();
    try {
      if (useApi) {
        await _api.add(apiBase, entry);
        await load();
      } else {
        entries = [...entries, entry];
        await _saveLocal();
        statusMessage = 'Local save. Settings se server jodo.';
        notifyListeners();
      }
    } catch (e) {
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateEntry(SimEntry original, SimEntry updated) async {
    error = null;
    notifyListeners();
    try {
      if (useApi) {
        await _api.update(apiBase, updated.copyWith(rowIndex: original.rowIndex));
        await load();
      } else {
        final i = _indexOf(original);
        if (i < 0) throw ApiException('Entry nahi mili');
        entries = [...entries]..[i] = updated;
        await _saveLocal();
        statusMessage = 'Entry update ho gayi';
        notifyListeners();
      }
    } catch (e) {
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteEntry(SimEntry entry) async {
    error = null;
    notifyListeners();
    try {
      if (useApi) {
        await _api.delete(apiBase, entry);
        await load();
      } else {
        final i = _indexOf(entry);
        if (i < 0) throw ApiException('Entry nahi mili');
        entries = [...entries]..removeAt(i);
        await _saveLocal();
        statusMessage = 'Entry delete ho gayi';
        notifyListeners();
      }
    } catch (e) {
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<String> testConnection() async {
    return _api.ping(apiBase);
  }
}
