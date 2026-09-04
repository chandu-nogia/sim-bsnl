import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../screens/activity_page.dart';
import '../screens/cbc_page.dart';
import '../screens/ctopup_page.dart';
import '../screens/dashboard_page.dart';
import '../screens/employees_page.dart';
import '../screens/home_page.dart';
import '../screens/locations_page.dart';
import '../screens/ops_pages.dart';
import '../screens/profile_page.dart';
import '../screens/recycle_page.dart';
import '../screens/reports_page.dart';
import '../screens/settings_page.dart';
import '../state/auth_store.dart';
import '../state/sim_store.dart';
import '../widgets/global_search.dart';

class _NavItem {
  const _NavItem(this.id, this.label, this.icon, {this.adminOnly = false});
  final String id;
  final String label;
  final IconData icon;
  final bool adminOnly;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.auth, required this.simStore});
  final AuthStore auth;
  final SimStore simStore;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String _section = 'dashboard';
  List<Map<String, dynamic>> _locations = [];

  AuthStore get auth => widget.auth;

  List<_NavItem> get _items {
    if (auth.isAdmin) {
      return const [
        _NavItem('dashboard', 'Dashboard', Icons.dashboard_outlined),
        _NavItem('locations', 'Locations', Icons.place_outlined, adminOnly: true),
        _NavItem('employees', 'Employees', Icons.badge_outlined, adminOnly: true),
        _NavItem('portal', 'BSNL Portal', Icons.sim_card_outlined),
        _NavItem('cbc', 'CBC List', Icons.receipt_long_outlined),
        _NavItem('ctopup', 'C-TopUp', Icons.payments_outlined),
        _NavItem('reports', 'Reports', Icons.assessment_outlined, adminOnly: true),
        _NavItem('activity', 'Activity Logs', Icons.history),
        _NavItem('notifications', 'Notifications', Icons.notifications_outlined),
        _NavItem('recycle', 'Recycle Bin', Icons.delete_outline),
        _NavItem('health', 'System Health', Icons.monitor_heart_outlined, adminOnly: true),
        _NavItem('profile', 'Profile', Icons.person_outline),
        _NavItem('settings', 'Settings', Icons.settings_outlined, adminOnly: true),
      ];
    }
    return const [
      _NavItem('dashboard', 'Dashboard', Icons.dashboard_outlined),
      _NavItem('portal', 'BSNL Portal', Icons.sim_card_outlined),
      _NavItem('cbc', 'CBC List', Icons.receipt_long_outlined),
      _NavItem('ctopup', 'C-TopUp', Icons.payments_outlined),
      _NavItem('activity', 'My Activity', Icons.history),
      _NavItem('notifications', 'Notifications', Icons.notifications_outlined),
      _NavItem('recycle', 'Recycle Bin', Icons.delete_outline),
      _NavItem('profile', 'Profile', Icons.person_outline),
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    try {
      final rows = await auth.api.listLocations(auth.apiBase);
      if (!mounted) return;
      setState(() => _locations = rows);
      if (!auth.isAdmin) {
        for (final r in rows) {
          if ('${r['id']}' == '${auth.effectiveLocationId}') {
            if (auth.locationName.isEmpty) {
              await auth.selectLocation(auth.effectiveLocationId, name: '${r['name'] ?? ''}');
            }
            break;
          }
        }
      }
    } catch (_) {}
  }

  String get _title {
    if (_section == 'profile') return 'Profile';
    if (_section == 'mylocation') {
      return _locName.isEmpty ? 'My Location' : _locName;
    }
    for (final i in _items) {
      if (i.id == _section) return i.label;
    }
    return 'BSNL';
  }

  int? get _locId => auth.effectiveLocationId;
  String get _locName => auth.locationName;

  void _go(String id) {
    setState(() => _section = id);
    if (id == 'portal' || id == 'users') {
      widget.simStore.setLocation(_locId);
      if (_locId != null) widget.simStore.load();
    }
  }

  Future<void> _openLocation(int id, String name, String section) async {
    if (id <= 0) return;
    await auth.selectLocation(id, name: name);
    widget.simStore.setLocation(id);
    _go(section);
  }

  Widget _body() {
    switch (_section) {
      case 'locations':
        return LocationsPage(auth: auth, onChanged: _loadLocations);
      case 'employees':
        return EmployeesPage(key: ValueKey('emp-$_locId'), auth: auth);
      case 'reports':
        return ReportsPage(auth: auth);
      case 'activity':
        return ActivityPage(auth: auth);
      case 'settings':
        return SettingsPage(store: widget.simStore, nested: true);
      case 'profile':
        return ProfilePage(auth: auth);
      case 'recycle':
        return RecyclePage(auth: auth);
      case 'notifications':
        return NotificationsPage(auth: auth);
      case 'health':
        return HealthPage(auth: auth);
      case 'portal':
      case 'users':
        return HomePage(
          key: ValueKey('portal-$_locId'),
          store: widget.simStore,
          locationName: _locName,
          nested: true,
        );
      case 'cbc':
        return CbcPage(
          key: ValueKey('cbc-$_locId'),
          auth: auth,
          locationId: _locId,
          locationName: _locName,
          nested: true,
        );
      case 'ctopup':
        return CtopupPage(
          key: ValueKey('ctopup-$_locId'),
          auth: auth,
          locationId: _locId,
          locationName: _locName,
          nested: true,
        );
      case 'mylocation':
        return LocationHubPage(
          key: ValueKey('hub-$_locId'),
          auth: auth,
          simStore: widget.simStore,
          locationId: _locId ?? 0,
          locationName: _locName,
          embedded: true,
          onOpenModule: (section) => _openLocation(_locId ?? 0, _locName, section),
        );
      default:
        return DashboardHome(
          auth: auth,
          simStore: widget.simStore,
          onOpenSection: _go,
          onOpenLocation: _openLocation,
          onLocationsChanged: _loadLocations,
        );
    }
  }

  Widget _sidebar(bool rail) {
    Widget tile(_NavItem item) {
      return ListTile(
        dense: true,
        selected: _section == item.id,
        leading: Icon(item.icon, color: _section == item.id ? BsnlColors.gold : Colors.white70),
        title: rail
            ? null
            : Text(
                item.label,
                style: TextStyle(
                  color: _section == item.id ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
        selectedTileColor: Colors.white12,
        onTap: () {
          _go(item.id);
          if (!rail && Navigator.of(context).canPop()) Navigator.pop(context);
        },
      );
    }

    final nav = ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: BsnlColors.gold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.cell_tower, color: BsnlColors.navyDark, size: 20),
              ),
              if (!rail) ...[
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'BSNL Manager',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (auth.isAdmin) ...[
          tile(const _NavItem('dashboard', 'Dashboard', Icons.dashboard_outlined)),
          tile(const _NavItem('employees', 'Employees', Icons.badge_outlined, adminOnly: true)),
          tile(const _NavItem('locations', 'Locations', Icons.place_outlined, adminOnly: true)),
          tile(const _NavItem('portal', 'BSNL Portal', Icons.sim_card_outlined)),
          tile(const _NavItem('cbc', 'CBC List', Icons.receipt_long_outlined)),
          tile(const _NavItem('ctopup', 'C-TopUp', Icons.payments_outlined)),
          tile(const _NavItem('reports', 'Reports', Icons.assessment_outlined, adminOnly: true)),
          tile(const _NavItem('activity', 'Activity Logs', Icons.history)),
          tile(const _NavItem('notifications', 'Notifications', Icons.notifications_outlined)),
          tile(const _NavItem('recycle', 'Recycle Bin', Icons.delete_outline)),
          tile(const _NavItem('health', 'System Health', Icons.monitor_heart_outlined, adminOnly: true)),
          tile(const _NavItem('profile', 'Profile', Icons.person_outline)),
          tile(const _NavItem('settings', 'Settings', Icons.settings_outlined, adminOnly: true)),
        ] else ...[
          for (final item in _items) tile(item),
        ],
      ],
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF071A44), Color(0xFF0B3D91), Color(0xFF0E7490)],
        ),
      ),
      child: nav,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: auth,
      builder: (context, _) {
        final wide = MediaQuery.sizeOf(context).width >= 980;
        final Widget switcher = Text(
          auth.isAdmin
              ? 'All locations'
              : (_locName.isEmpty ? 'Assigned Location' : 'Assigned Location: $_locName'),
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        );

        final bar = AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_title),
              DefaultTextStyle.merge(
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white70),
                child: switcher,
              ),
            ],
          ),
          actions: [
            GlobalSearchButton(
              auth: auth,
              onOpen: (section, {locationId, locationName = '', employeeEmail}) async {
                if (locationId != null && locationId > 0) {
                  await auth.selectLocation(locationId, name: locationName);
                  widget.simStore.setLocation(locationId);
                }
                if (section == 'employees' && (employeeEmail ?? '').isNotEmpty) {
                  _go('employees');
                  return;
                }
                _go(section);
              },
            ),
            IconButton(
              tooltip: 'Notifications',
              onPressed: () => _go('notifications'),
              icon: const Icon(Icons.notifications_outlined),
            ),
            IconButton(
              tooltip: 'Logout',
              onPressed: () async {
                await auth.api.logoutAudit(auth.apiBase);
                await auth.logout();
              },
              icon: const Icon(Icons.logout),
            ),
          ],
        );

        final content = DecoratedBox(
          decoration: bsnlPageGradient(),
          child: _body(),
        );

        if (wide) {
          return Scaffold(
            appBar: bar,
            body: Row(
              children: [
                SizedBox(width: 248, child: _sidebar(false)),
                Expanded(child: content),
              ],
            ),
          );
        }
        return Scaffold(
          appBar: bar,
          drawer: Drawer(child: _sidebar(false)),
          body: content,
        );
      },
    );
  }
}
