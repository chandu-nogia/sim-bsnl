import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/seed.dart';
import '../models/sim_entry.dart';
import '../services/api_service.dart';
import 'auth_store.dart';

class SimStore extends ChangeNotifier {
  SimStore(this.auth);

  final AuthStore auth;
  ApiService get _api => auth.api;

  List<SimEntry> entries = [];
  String search = '';
  String typeFilter = 'All';
  String frcFilter = 'All';
  DateTime? fromDate;
  DateTime? toDate;
  String sortBy = 'date';
  bool sortAsc = false;
  bool useApi = true;
  bool loading = true;
  bool connected = false;
  String? error;
  String? statusMessage;
  bool get canWrite => auth.canWrite;
  String get apiBase => auth.apiBase;
  int? locationId;

  void setLocation(int? id) {
    locationId = id;
  }

  List<SimEntry> get filtered {
    final loc = auth.effectiveLocationId;
    final q = search.trim().toLowerCase();
    final from = fromDate == null ? null : DateTime(fromDate!.year, fromDate!.month, fromDate!.day);
    final to = toDate == null ? null : DateTime(toDate!.year, toDate!.month, toDate!.day, 23, 59, 59);
    final rows = entries.where((e) {
      if (loc != null && e.locationId != null && e.locationId != loc) return false;
      if (typeFilter != 'All' && e.type.label != typeFilter) return false;
      if (frcFilter != 'All' && e.frc != frcFilter) return false;
      if (from != null || to != null) {
        final d = _parseDate(e.date);
        if (from != null && d.isBefore(from)) return false;
        if (to != null && d.isAfter(to)) return false;
      }
      if (q.isEmpty) return true;
      return e.name.toLowerCase().contains(q) ||
          e.mobile.contains(q) ||
          e.simNo.contains(q) ||
          e.altNumber.contains(q) ||
          e.last6.contains(q) ||
          '${e.sno}'.contains(q);
    }).toList();
    rows.sort((a, b) {
      int cmp;
      if (sortBy == 'name') {
        cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      } else {
        cmp = _parseDate(a.date).compareTo(_parseDate(b.date));
      }
      return sortAsc ? cmp : -cmp;
    });
    return rows;
  }

  DateTime _parseDate(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
    final iso = DateTime.tryParse(t);
    if (iso != null) return iso;
    final p = t.split(RegExp(r'[/-]'));
    if (p.length != 3) return DateTime.fromMillisecondsSinceEpoch(0);
    final a = int.tryParse(p[0].trim());
    final b = int.tryParse(p[1].trim());
    var y = int.tryParse(p[2].trim());
    if (a == null || b == null || y == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (y < 100) y += 2000;
    if (p[0].trim().length == 4) return DateTime(a, b, y);
    return DateTime(y, b, a);
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

  int? get _queryLocationId => auth.effectiveLocationId;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    useApi = prefs.getBool('useApi') ?? true;
    if (kReleaseMode) useApi = true;
    try {
      if (useApi) {
        final loc = _queryLocationId;
        entries = await _api.list(apiBase, locationId: loc);
        if (loc != null) {
          entries = [for (final e in entries) if (e.locationId == null || e.locationId == loc) e];
        }
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
      entries = [];
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
    await auth.saveApiUrl(url);
    useApi = true;
    final prefs = await SharedPreferences.getInstance();
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
    fromDate = null;
    toDate = null;
    sortBy = 'date';
    sortAsc = false;
    notifyListeners();
  }

  void setDateRange({DateTime? from, DateTime? to, bool clearFrom = false, bool clearTo = false}) {
    if (clearFrom) fromDate = null;
    if (clearTo) toDate = null;
    if (from != null) fromDate = from;
    if (to != null) toDate = to;
    notifyListeners();
  }

  void setSort(String by, bool asc) {
    sortBy = by;
    sortAsc = asc;
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

  Future<void> addEntry(SimEntry entry, {int? locationId}) async {
    if (!canWrite) throw ApiException('Add karne ki permission nahi');
    error = null;
    notifyListeners();
    try {
      if (useApi) {
        await _api.add(apiBase, entry, locationId: locationId ?? _queryLocationId);
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

  Future<void> updateEntry(SimEntry original, SimEntry updated, {int? locationId}) async {
    if (!canWrite) throw ApiException('Update karne ki permission nahi');
    error = null;
    notifyListeners();
    try {
      if (useApi) {
        await _api.update(
          apiBase,
          updated.copyWith(rowIndex: original.rowIndex),
          locationId: locationId ?? _queryLocationId ?? original.locationId,
        );
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
    if (!canWrite) throw ApiException('Delete karne ki permission nahi');
    error = null;
    notifyListeners();
    try {
      if (useApi) {
        await _api.delete(apiBase, entry, locationId: _queryLocationId ?? entry.locationId);
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
