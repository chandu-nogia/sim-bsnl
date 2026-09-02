import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../screens/activity_page.dart';
import '../screens/cbc_page.dart';
import '../screens/ctopup_page.dart';
import '../screens/dashboard_page.dart';
import '../screens/employees_page.dart';
import '../screens/home_page.dart';
import '../screens/locations_page.dart';
import '../screens/reports_page.dart';
import '../screens/settings_page.dart';
import '../state/auth_store.dart';
import '../state/sim_store.dart';

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
        _NavItem('users', 'Users', Icons.people_outline),
        _NavItem('reports', 'Reports', Icons.assessment_outlined, adminOnly: true),
        _NavItem('activity', 'Activity Logs', Icons.history),
        _NavItem('settings', 'Settings', Icons.settings_outlined, adminOnly: true),
      ];
    }
    return const [
      _NavItem('dashboard', 'Dashboard', Icons.dashboard_outlined),
      _NavItem('mylocation', 'My Location', Icons.place_outlined),
      _NavItem('portal', 'BSNL Portal', Icons.sim_card_outlined),
      _NavItem('cbc', 'CBC List', Icons.receipt_long_outlined),
      _NavItem('ctopup', 'C-TopUp', Icons.payments_outlined),
      _NavItem('users', 'Users', Icons.people_outline),
      _NavItem('activity', 'My Activity', Icons.history),
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
      if (auth.effectiveLocationId == null && rows.isNotEmpty) {
        final first = rows.first;
        final id = int.tryParse('${first['id']}') ?? 0;
        if (id > 0) {
          await auth.selectLocation(id, name: '${first['name'] ?? ''}');
        }
      } else if (auth.locationName.isEmpty && auth.effectiveLocationId != null) {
        for (final r in rows) {
          if ('${r['id']}' == '${auth.effectiveLocationId}') {
            await auth.selectLocation(auth.effectiveLocationId, name: '${r['name'] ?? ''}');
            break;
          }
        }
      }
    } catch (_) {}
  }

  String get _title {
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
      widget.simStore.load();
    }
  }

  Widget _body() {
    switch (_section) {
      case 'locations':
        return LocationsPage(auth: auth, onChanged: _loadLocations);
      case 'employees':
        return EmployeesPage(auth: auth);
      case 'reports':
        return ReportsPage(auth: auth);
      case 'activity':
        return ActivityPage(auth: auth);
      case 'settings':
        return SettingsPage(store: widget.simStore, nested: true);
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
        );
      default:
        return DashboardHome(
          auth: auth,
          simStore: widget.simStore,
          onOpenSection: _go,
          onLocationsChanged: _loadLocations,
        );
    }
  }

  Widget _sidebar(bool rail) {
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
        for (final item in _items)
          if (!item.adminOnly || auth.isAdmin)
            ListTile(
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
            ),
      ],
    );
    return ColoredBox(color: BsnlColors.navyDark, child: nav);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: auth,
      builder: (context, _) {
        final wide = MediaQuery.sizeOf(context).width >= 980;
        final locChoices = [
          for (final r in _locations)
            (
              int.tryParse('${r['id']}') ?? 0,
              '${r['name'] ?? ''}${r['status'] == 'inactive' ? ' (off)' : ''}',
            ),
        ].where((e) => e.$1 > 0).toList();
        final switcher = locChoices.length <= 1
            ? Text(
                _locName.isEmpty ? (auth.isAdmin ? 'All locations' : 'No location') : _locName,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              )
            : DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  dropdownColor: BsnlColors.navyDark,
                  value: locChoices.any((e) => e.$1 == _locId) ? _locId : locChoices.first.$1,
                  iconEnabledColor: Colors.white,
                  items: [
                    for (final c in locChoices)
                      DropdownMenuItem(
                        value: c.$1,
                        child: Text(c.$2, style: const TextStyle(color: Colors.white)),
                      ),
                  ],
                  onChanged: (id) async {
                    if (id == null) return;
                    final name = locChoices.firstWhere((e) => e.$1 == id).$2.replaceAll(' (off)', '');
                    await auth.selectLocation(id, name: name);
                    widget.simStore.setLocation(id);
                    if (_section == 'portal' || _section == 'users') widget.simStore.load();
                    setState(() {});
                  },
                ),
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
            IconButton(
              tooltip: 'Logout',
              onPressed: auth.logout,
              icon: const Icon(Icons.logout),
            ),
          ],
        );

        final content = ColoredBox(
          color: BsnlColors.page,
          child: _body(),
        );

        if (wide) {
          return Scaffold(
            appBar: bar,
            body: Row(
              children: [
                SizedBox(width: 232, child: _sidebar(false)),
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
