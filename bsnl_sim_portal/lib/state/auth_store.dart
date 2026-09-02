import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

class AuthStore extends ChangeNotifier {
  AuthStore() {
    _api.tokenGetter = () => token;
    loadSaved();
  }

  final _api = ApiService();
  ApiService get api => _api;

  String? token;
  String? email;
  String role = '';
  String name = '';
  int? locationId;
  String locationName = '';
  String? apiUrl;
  bool loading = true;

  bool get isLoggedIn => (token ?? '').isNotEmpty;
  bool get isAdmin => role == 'admin';
  bool get canWrite => isLoggedIn;

  String get apiBase {
    final saved = (apiUrl ?? '').trim().replaceAll(RegExp(r'/+$'), '');
    if (saved.isNotEmpty) return saved;
    const defined = String.fromEnvironment('API_URL');
    if (defined.trim().isNotEmpty) {
      return defined.trim().replaceAll(RegExp(r'/+$'), '');
    }
    if (kReleaseMode) return 'https://bsnl-sim-api.onrender.com';
    return 'http://localhost:5050';
  }

  Future<void> loadSaved() async {
    loading = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    apiUrl = prefs.getString('apiUrl');
    token = prefs.getString('authToken');
    email = prefs.getString('authEmail');
    role = prefs.getString('authRole') ?? '';
    name = prefs.getString('authName') ?? '';
    locationId = int.tryParse(prefs.getString('authLocationId') ?? '');
    locationName = prefs.getString('authLocationName') ?? '';
    if (isLoggedIn) {
      try {
        final user = await _api.me(apiBase);
        email = '${user['email'] ?? email}';
        role = '${user['role'] ?? role}';
        name = '${user['name'] ?? name}';
        locationId = _asInt(user['locationId']) ?? locationId;
        locationName = '${user['locationName'] ?? locationName}';
        final newToken = '${user['token'] ?? ''}';
        if (newToken.isNotEmpty) token = newToken;
        await _persist();
      } catch (_) {
        await logout();
        return;
      }
    }
    loading = false;
    notifyListeners();
  }

  Future<void> login(String mail, String password) async {
    final out = await _api.login(apiBase, mail.trim(), password);
    token = out.token;
    email = out.email;
    role = out.role;
    name = out.name;
    locationId = out.locationId;
    locationName = out.locationName;
    await _persist();
    notifyListeners();
  }

  Future<void> logout() async {
    token = null;
    email = null;
    role = '';
    name = '';
    locationId = null;
    locationName = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('authToken');
    await prefs.remove('authEmail');
    await prefs.remove('authRole');
    await prefs.remove('authName');
    await prefs.remove('authLocationId');
    await prefs.remove('authLocationName');
    notifyListeners();
  }

  Future<void> saveApiUrl(String url) async {
    apiUrl = url.trim().isEmpty ? null : url.trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    if (apiUrl == null) {
      await prefs.remove('apiUrl');
    } else {
      await prefs.setString('apiUrl', apiUrl!);
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null) return;
    await prefs.setString('authToken', token!);
    await prefs.setString('authEmail', email ?? '');
    await prefs.setString('authRole', role);
    await prefs.setString('authName', name);
    await prefs.setString('authLocationId', '${locationId ?? ''}');
    await prefs.setString('authLocationName', locationName);
  }

  int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v');
  }
}
