import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../screens/activity_page.dart';
import '../screens/cbc_page.dart';
import '../screens/ctopup_page.dart';
import '../screens/dashboard_page.dart';
import '../screens/employees_page.dart';
import '../screens/home_page.dart';
import '../screens/locations_page.dart';
import '../screens/profile_page.dart';
import '../screens/recycle_page.dart';
import '../screens/reports_page.dart';
import '../screens/settings_page.dart';
import '../screens/shop_page.dart';
import '../state/auth_store.dart';
import '../state/sim_store.dart';
import '../util/format.dart';

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
        _NavItem('stock', 'SIM Stock', Icons.inventory_2_outlined),
        _NavItem('closing', 'Daily Closing', Icons.event_available_outlined),
        _NavItem('recycle', 'Recycle Bin', Icons.delete_outline),
        _NavItem('reports', 'Reports', Icons.assessment_outlined, adminOnly: true),
        _NavItem('activity', 'Activity Logs', Icons.history),
        _NavItem('profile', 'Profile', Icons.person_outline),
        _NavItem('settings', 'Settings', Icons.settings_outlined, adminOnly: true),
      ];
    }
    return const [
      _NavItem('dashboard', 'Dashboard', Icons.dashboard_outlined),
      _NavItem('portal', 'BSNL Portal', Icons.sim_card_outlined),
      _NavItem('cbc', 'CBC List', Icons.receipt_long_outlined),
      _NavItem('ctopup', 'C-TopUp', Icons.payments_outlined),
      _NavItem('stock', 'SIM Stock', Icons.inventory_2_outlined),
      _NavItem('closing', 'Daily Closing', Icons.event_available_outlined),
      _NavItem('recycle', 'Recycle Bin', Icons.delete_outline),
      _NavItem('activity', 'Activity', Icons.history),
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

  Widget _pickLocationFirst() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Pehle jagah choose karo. Har jagah ka BSNL Portal / CBC / C-TopUp alag table hai.',
          style: TextStyle(fontWeight: FontWeight.w700, color: BsnlColors.navyDark),
        ),
        const SizedBox(height: 12),
        for (final r in _locations)
          Card(
            child: ListTile(
              leading: const Icon(Icons.place_outlined, color: BsnlColors.navy),
              title: Text('${r['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Is jagah ka data alag table mein khulega'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openLocation(asInt(r['id']) ?? 0, '${r['name'] ?? ''}', _section),
            ),
          ),
      ],
    );
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
      case 'stock':
        if (auth.isAdmin && _locId == null) return _pickLocationFirst();
        return StockPage(key: ValueKey('stock-$_locId'), auth: auth);
      case 'closing':
        if (auth.isAdmin && _locId == null) return _pickLocationFirst();
        return ClosingPage(key: ValueKey('close-$_locId'), auth: auth);
      case 'portal':
      case 'users':
        if (auth.isAdmin && _locId == null) return _pickLocationFirst();
        return HomePage(
          key: ValueKey('portal-$_locId'),
          store: widget.simStore,
          locationName: _locName,
          nested: true,
        );
      case 'cbc':
        if (auth.isAdmin && _locId == null) return _pickLocationFirst();
        return CbcPage(
          key: ValueKey('cbc-$_locId'),
          auth: auth,
          locationId: _locId,
          locationName: _locName,
          nested: true,
        );
      case 'ctopup':
        if (auth.isAdmin && _locId == null) return _pickLocationFirst();
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
    final locTiles = [
      for (final r in _locations)
        if (asInt(r['id']) != null)
          (
            asInt(r['id'])!,
            '${r['name'] ?? ''}${r['status'] == 'inactive' ? ' (off)' : ''}',
          ),
    ];

    Widget branch(String section, String label, IconData icon) {
      final selected = _section == section;
      return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          leading: Icon(icon, color: selected ? BsnlColors.gold : Colors.white70),
          title: rail
              ? const SizedBox.shrink()
              : Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
          iconColor: Colors.white70,
          collapsedIconColor: Colors.white54,
          initiallyExpanded: selected,
          children: [
            ListTile(
              dense: true,
              title: rail ? null : const Text('All Locations', style: TextStyle(color: Colors.white70, fontSize: 13)),
              onTap: () async {
                await auth.selectLocation(null, name: 'All Locations');
                widget.simStore.setLocation(null);
                _go('dashboard');
              },
            ),
            for (final loc in locTiles)
              ListTile(
                dense: true,
                selected: selected && _locId == loc.$1,
                title: rail
                    ? null
                    : Text(loc.$2, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                selectedTileColor: Colors.white12,
                onTap: () => _openLocation(loc.$1, loc.$2.replaceAll(' (off)', ''), section),
              ),
          ],
        ),
      );
    }

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
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              backgroundColor: Colors.transparent,
              collapsedBackgroundColor: Colors.transparent,
              leading: Icon(
                Icons.place_outlined,
                color: _section == 'locations' ? BsnlColors.gold : Colors.white70,
              ),
              title: Text(
                'Locations',
                style: TextStyle(
                  color: _section == 'locations' ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              iconColor: Colors.white70,
              collapsedIconColor: Colors.white54,
              initiallyExpanded: _section == 'locations',
              children: [
                ListTile(
                  dense: true,
                  title: const Text('All Locations', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  onTap: () => _go('locations'),
                ),
                ListTile(
                  dense: true,
                  title: const Text('Add Location', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  onTap: () => _go('locations'),
                ),
              ],
            ),
          ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              backgroundColor: Colors.transparent,
              collapsedBackgroundColor: Colors.transparent,
              leading: Icon(
                Icons.badge_outlined,
                color: _section == 'employees' ? BsnlColors.gold : Colors.white70,
              ),
              title: Text(
                'Employees',
                style: TextStyle(
                  color: _section == 'employees' ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              iconColor: Colors.white70,
              collapsedIconColor: Colors.white54,
              initiallyExpanded: _section == 'employees',
              children: [
                ListTile(
                  dense: true,
                  title: const Text('All Employees', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  onTap: () async {
                    await auth.selectLocation(null, name: 'All Locations');
                    _go('employees');
                  },
                ),
                for (final loc in locTiles)
                  ListTile(
                    dense: true,
                    title: Text(loc.$2, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    onTap: () async {
                      await auth.selectLocation(loc.$1, name: loc.$2.replaceAll(' (off)', ''));
                      _go('employees');
                    },
                  ),
              ],
            ),
          ),
          branch('portal', 'BSNL Portal', Icons.sim_card_outlined),
          branch('cbc', 'CBC List', Icons.receipt_long_outlined),
          branch('ctopup', 'C-TopUp', Icons.payments_outlined),
          tile(const _NavItem('stock', 'SIM Stock', Icons.inventory_2_outlined)),
          tile(const _NavItem('closing', 'Daily Closing', Icons.event_available_outlined)),
          tile(const _NavItem('recycle', 'Recycle Bin', Icons.delete_outline)),
          tile(const _NavItem('reports', 'Reports', Icons.assessment_outlined, adminOnly: true)),
          tile(const _NavItem('activity', 'Activity Logs', Icons.history)),
          tile(const _NavItem('profile', 'Profile', Icons.person_outline)),
          tile(const _NavItem('settings', 'Settings', Icons.settings_outlined, adminOnly: true)),
        ] else ...[
          for (final item in _items) tile(item),
        ],
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
        final currentInList = locChoices.any((e) => e.$1 == _locId);
        final Widget switcher;
        if (!auth.isAdmin) {
          switcher = Text(
            _locName.isEmpty ? 'Assigned Location' : 'Assigned Location: $_locName',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          );
        } else {
          switcher = DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              dropdownColor: BsnlColors.navyDark,
              value: currentInList ? _locId : null,
              iconEnabledColor: Colors.white,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All Locations', style: TextStyle(color: Colors.white)),
                ),
                for (final c in locChoices)
                  DropdownMenuItem(
                    value: c.$1,
                    child: Text(c.$2, style: const TextStyle(color: Colors.white)),
                  ),
              ],
              onChanged: (id) async {
                if (id == null) {
                  await auth.selectLocation(null, name: 'All Locations');
                  widget.simStore.setLocation(null);
                  _go('dashboard');
                  return;
                }
                final name = locChoices.firstWhere((e) => e.$1 == id).$2.replaceAll(' (off)', '');
                await auth.selectLocation(id, name: name);
                widget.simStore.setLocation(id);
                if (_section == 'portal' || _section == 'users') widget.simStore.load();
                setState(() {});
              },
            ),
          );
        }

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
