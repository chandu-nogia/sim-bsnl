import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../screens/cbc_page.dart';
import '../screens/ctopup_page.dart';
import '../screens/dashboard_page.dart';
import '../screens/home_page.dart';
import '../screens/settings_page.dart';
import '../state/auth_store.dart';
import '../state/sim_store.dart';
import '../widgets/global_search.dart';

class _NavItem {
  const _NavItem(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;
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

  AuthStore get auth => widget.auth;

  static const _items = [
    _NavItem('dashboard', 'Dashboard', Icons.dashboard_outlined),
    _NavItem('portal', 'BSNL Portal', Icons.sim_card_outlined),
    _NavItem('cbc', 'CBP List', Icons.receipt_long_outlined),
    _NavItem('ctopup', 'CTOPUP', Icons.payments_outlined),
    _NavItem('settings', 'Settings', Icons.settings_outlined),
  ];

  String get _title {
    for (final i in _items) {
      if (i.id == _section) return i.label;
    }
    return 'BSNL Khatushyamji';
  }

  void _go(String id) {
    setState(() => _section = id);
    if (id == 'portal') {
      widget.simStore.setLocation(auth.locationId);
      widget.simStore.load();
    }
  }

  Widget _body() {
    switch (_section) {
      case 'settings':
        return SettingsPage(store: widget.simStore, nested: true);
      case 'portal':
        return HomePage(
          key: ValueKey('portal-${auth.locationId}'),
          store: widget.simStore,
          locationName: 'Khatushyamji',
          nested: true,
        );
      case 'cbc':
        return CbcPage(
          key: ValueKey('cbc-${auth.locationId}'),
          auth: auth,
          locationId: auth.locationId,
          locationName: 'Khatushyamji',
          nested: true,
        );
      case 'ctopup':
        return CtopupPage(
          key: ValueKey('ctopup-${auth.locationId}'),
          auth: auth,
          locationId: auth.locationId,
          locationName: 'Khatushyamji',
          nested: true,
        );
      default:
        return DashboardHome(
          auth: auth,
          simStore: widget.simStore,
          onOpenSection: _go,
        );
    }
  }

  Widget _sidebar() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF071A44), Color(0xFF0B3D91), Color(0xFF0E7490)],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BSNL Khatushyamji', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                SizedBox(height: 4),
                Text('Personal management', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          for (final item in _items)
            ListTile(
              dense: true,
              selected: _section == item.id,
              leading: Icon(item.icon, color: _section == item.id ? BsnlColors.gold : Colors.white70),
              title: Text(
                item.label,
                style: TextStyle(
                  color: _section == item.id ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
              selectedTileColor: Colors.white12,
              onTap: () {
                _go(item.id);
                if (Navigator.of(context).canPop()) Navigator.pop(context);
              },
            ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.logout, color: Colors.white70),
            title: const Text('Logout', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
            onTap: () async {
              await auth.api.logoutAudit(auth.apiBase);
              await auth.logout();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: auth,
      builder: (context, _) {
        final wide = MediaQuery.sizeOf(context).width >= 980;
        final bar = AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_title),
              const Text(
                'Khatushyamji',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white70),
              ),
            ],
          ),
          actions: [
            GlobalSearchButton(auth: auth, onOpen: _go),
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
        final content = DecoratedBox(decoration: bsnlPageGradient(), child: _body());
        if (wide) {
          return Scaffold(
            appBar: bar,
            body: Row(
              children: [
                SizedBox(width: 240, child: _sidebar()),
                Expanded(child: content),
              ],
            ),
          );
        }
        return Scaffold(
          appBar: bar,
          drawer: Drawer(child: _sidebar()),
          body: content,
        );
      },
    );
  }
}
