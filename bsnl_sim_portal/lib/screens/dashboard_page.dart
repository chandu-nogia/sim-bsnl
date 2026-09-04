import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../state/auth_store.dart';
import '../state/sim_store.dart';
import '../util/format.dart';
import '../widgets/bar_chart.dart';
import '../widgets/fade_in.dart';
import '../widgets/kpi_card.dart';
import 'cbc_page.dart';
import 'ctopup_page.dart';
import 'home_page.dart';

class DashboardHome extends StatefulWidget {
  const DashboardHome({
    super.key,
    required this.auth,
    required this.simStore,
    this.onOpenSection,
    this.onOpenLocation,
    this.onLocationsChanged,
  });
  final AuthStore auth;
  final SimStore simStore;
  final ValueChanged<String>? onOpenSection;
  final Future<void> Function(int id, String name, String section)? onOpenLocation;
  final VoidCallback? onLocationsChanged;

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _locations = [];
  List<Map<String, dynamic>> _activity = [];
  Map<String, dynamic> _charts = {};
  Map<String, dynamic> _mine = {};
  int _locationsCount = 0;
  int _employeesCount = 0;
  int _activeEmployees = 0;
  int _pending = 0;
  int _failed = 0;
  int _todayActivity = 0;

  AuthStore get auth => widget.auth;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (auth.isAdmin) {
        final summary = await auth.api.summary(auth.apiBase);
        final activity = await auth.api.activity(auth.apiBase);
        setState(() {
          _locations = asMaps(summary['byLocation']);
          _charts = summary['charts'] is Map ? Map<String, dynamic>.from(summary['charts'] as Map) : {};
          _locationsCount = asInt(summary['locations']) ?? _locations.length;
          _employeesCount = asInt(summary['employees']) ?? 0;
          _activeEmployees = asInt(summary['activeEmployees']) ?? _employeesCount;
          _pending = asInt(summary['pending']) ?? 0;
          _failed = asInt(summary['failed']) ?? 0;
          _todayActivity = asInt(summary['todayActivity']) ?? 0;
          _activity = activity;
        });
      } else {
        final id = auth.effectiveLocationId;
        if (id != null) {
          final loc = await auth.api.locationSummary(auth.apiBase, id);
          setState(() => _mine = loc);
        }
        final rows = await auth.api.listLocations(auth.apiBase);
        setState(() => _locations = rows);
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<({String label, num value})> _pts(String key) {
    return [
      for (final r in asMaps(_charts[key]))
        (label: '${r['name'] ?? r['date'] ?? r['month'] ?? r['email'] ?? ''}', value: asNum(r['value'] ?? r['count'] ?? r['amount'] ?? r['cbc'] ?? 0)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (_error != null)
            Card(
              color: const Color(0xFFFFEBEE),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, style: TextStyle(color: Colors.red.shade900)),
              ),
            ),
          if (auth.isAdmin) ...[
            FadeIn(
              child: Text(
                'Operations',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: BsnlColors.navyDark),
              ),
            ),
            const SizedBox(height: 4),
            const Text('Live numbers from MongoDB. Click a card to open the list.', style: TextStyle(color: BsnlColors.muted)),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, box) {
                final cols = box.maxWidth >= 1100 ? 3 : box.maxWidth >= 700 ? 2 : 1;
                final w = (box.maxWidth - (cols - 1) * 10) / cols;
                final items = <(String, String, IconData, String)>[
                  ('Total Employees', '$_employeesCount', Icons.badge_outlined, 'employees'),
                  ('Active Employees', '$_activeEmployees', Icons.verified_outlined, 'employees'),
                  ('Active Locations', '$_locationsCount', Icons.place_outlined, 'locations'),
                  ('Pending items', '$_pending', Icons.hourglass_empty, 'closing'),
                  ("Today's activity", '$_todayActivity', Icons.bolt_outlined, 'activity'),
                  ('Failed C-TopUp', '$_failed', Icons.error_outline, 'ctopup'),
                ];
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final it in items)
                      SizedBox(
                        width: w,
                        child: KpiCard(
                          label: it.$1,
                          value: it.$2,
                          icon: it.$3,
                          onTap: () => widget.onOpenSection?.call(it.$4),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            const Text('Module comparison', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: BsnlColors.navyDark)),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, box) {
                final charts = [
                  SimpleBarChart(title: 'Portal records by location', points: _pts('usersByLocation')),
                  SimpleBarChart(title: 'CBC amount by location', points: _pts('cbcByLocation')),
                  SimpleBarChart(title: 'C-TopUp by location', points: _pts('ctopupByLocation')),
                  SimpleBarChart(title: '14-day activity', points: _pts('dailyTxns')),
                ];
                final wide = box.maxWidth >= 900;
                if (!wide) return Column(children: [for (final c in charts) ...[c, const SizedBox(height: 10)]]);
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in charts) SizedBox(width: (box.maxWidth - 10) / 2, child: c),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Text('Location performance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: BsnlColors.navyDark)),
                const Spacer(),
                TextButton(onPressed: () => widget.onOpenSection?.call('locations'), child: const Text('Manage locations')),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(BsnlColors.navyDark),
                  headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  columns: const [
                    DataColumn(label: Text('Location')),
                    DataColumn(label: Text('Employees')),
                    DataColumn(label: Text('BSNL')),
                    DataColumn(label: Text('CBC')),
                    DataColumn(label: Text('C-TopUp')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: [
                    for (final row in _locations)
                      DataRow(
                        cells: [
                          DataCell(
                            Text('${row['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            onTap: () => _openLoc(row, 'portal'),
                          ),
                          DataCell(Text('${asNum(row['employees']).round()}'), onTap: () => widget.onOpenSection?.call('employees')),
                          DataCell(Text('${asNum(row['sims']).round()}'), onTap: () => _openLoc(row, 'portal')),
                          DataCell(Text('${asNum(row['cbcCount']).round()}'), onTap: () => _openLoc(row, 'cbc')),
                          DataCell(Text('${asNum(row['ctopupCount']).round()}'), onTap: () => _openLoc(row, 'ctopup')),
                          DataCell(Text('${row['status'] ?? 'active'}')),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Text('Recent activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: BsnlColors.navyDark)),
                const Spacer(),
                TextButton(onPressed: () => widget.onOpenSection?.call('activity'), child: const Text('View all')),
              ],
            ),
            const SizedBox(height: 8),
            if (_activity.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No activity yet', style: TextStyle(color: BsnlColors.muted))))
            else
              for (final a in _activity.take(8)) ActivityTile(row: a),
          ] else ...[
            Text(
              'Welcome ${auth.name.isEmpty ? 'Employee' : auth.name}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: BsnlColors.navyDark),
            ),
            const SizedBox(height: 6),
            Text(
              'Assigned Location: ${_locTitleName()}',
              style: const TextStyle(fontWeight: FontWeight.w700, color: BsnlColors.muted),
            ),
            const SizedBox(height: 14),
            _StatGrid(
              items: [
                ('Users', '${asNum(_mine['sims']).round()}', Icons.people_outline, const Color(0xFF0E7490)),
                ('CBC', rupee(asNum(_mine['cbcAmount'])), Icons.receipt_long_outlined, const Color(0xFF16A34A)),
                ('C-TopUp', rupee(asNum(_mine['ctopupAmount'])), Icons.payments_outlined, const Color(0xFF7C3AED)),
                ('Today users', '${asNum(_mine['newUsersToday']).round()}', Icons.person_add_alt, const Color(0xFF0369A1)),
              ],
            ),
            const SizedBox(height: 16),
            LocationPortalGrid(
              auth: auth,
              simStore: widget.simStore,
              locationId: auth.effectiveLocationId,
              locationName: auth.locationName,
              onOpenModule: widget.onOpenLocation == null
                  ? null
                  : (section) {
                      final id = auth.effectiveLocationId ?? 0;
                      widget.onOpenLocation!(id, auth.locationName, section);
                    },
            ),
          ],
        ],
      ),
    );
  }

  String _locTitleName() {
    if (auth.locationName.isNotEmpty) return auth.locationName;
    return '—';
  }

  Future<void> _openLoc(Map<String, dynamic> row, String section) async {
    final id = asInt(row['id']) ?? 0;
    final name = '${row['name'] ?? ''}';
    if (widget.onOpenLocation != null) {
      await widget.onOpenLocation!(id, name, section);
      return;
    }
    await auth.selectLocation(id, name: name);
    widget.onOpenSection?.call(section);
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.items});
  final List<(String, String, IconData, Color)> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth >= 1100 ? 4 : box.maxWidth >= 720 ? 3 : 2;
        final w = (box.maxWidth - (cols - 1) * 10) / cols;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final it in items)
              SizedBox(
                width: w,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(it.$3, color: it.$4),
                        const SizedBox(height: 8),
                        Text(it.$1, style: const TextStyle(color: BsnlColors.muted, fontWeight: FontWeight.w700, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(it.$2, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class ActivityTile extends StatelessWidget {
  const ActivityTile({super.key, required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          switch ('${row['action']}') {
            'add' => Icons.add_circle_outline,
            'delete' => Icons.delete_outline,
            'update' => Icons.edit_outlined,
            'login' => Icons.login,
            _ => Icons.history,
          },
          color: BsnlColors.navy,
        ),
        title: Text('${row['detail'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${row['locationName'] ?? ''}  •  ${row['name'] ?? row['email'] ?? ''}  •  ${row['section'] ?? ''}\n${row['at'] ?? ''}',
        ),
        isThreeLine: true,
      ),
    );
  }
}

class LocationHubPage extends StatelessWidget {
  const LocationHubPage({
    super.key,
    required this.auth,
    required this.simStore,
    required this.locationId,
    required this.locationName,
    this.embedded = false,
    this.onOpenModule,
  });
  final AuthStore auth;
  final SimStore simStore;
  final int locationId;
  final String locationName;
  final bool embedded;
  final void Function(String section)? onOpenModule;

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Text(
          locationName.isEmpty ? 'My location' : locationName,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: BsnlColors.navyDark),
        ),
        const SizedBox(height: 6),
        const Text(
          'BSNL Portal, CBC List and C-TopUp for this location',
          style: TextStyle(color: BsnlColors.muted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        LocationPortalGrid(
          auth: auth,
          simStore: simStore,
          locationId: locationId,
          locationName: locationName,
          onOpenModule: onOpenModule,
        ),
      ],
    );
    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(title: Text('$locationName')),
      body: body,
    );
  }
}

class LocationPortalGrid extends StatelessWidget {
  const LocationPortalGrid({
    super.key,
    required this.auth,
    required this.simStore,
    required this.locationId,
    required this.locationName,
    this.onOpenModule,
  });
  final AuthStore auth;
  final SimStore simStore;
  final int? locationId;
  final String locationName;
  final void Function(String section)? onOpenModule;

  void _open(BuildContext context, String section) {
    final id = locationId;
    if (onOpenModule != null) {
      onOpenModule!(section);
      return;
    }
    if (section == 'portal') {
      simStore.setLocation(id);
      simStore.load();
      Navigator.of(context).push(
        fadeRoute(HomePage(store: simStore, locationName: locationName)),
      );
      return;
    }
    if (section == 'cbc') {
      Navigator.of(context).push(
        fadeRoute(CbcPage(auth: auth, locationId: id, locationName: locationName)),
      );
      return;
    }
    Navigator.of(context).push(
      fadeRoute(CtopupPage(auth: auth, locationId: id, locationName: locationName)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = [
      _PortalData(
        index: '01',
        title: 'BSNL Portal',
        subtitle: 'CYMN / MNP / Swap / Postpaid',
        icon: Icons.sim_card_outlined,
        colors: const [Color(0xFF0B3D91), Color(0xFF1A73E8)],
        onTap: () => _open(context, 'portal'),
      ),
      _PortalData(
        index: '02',
        title: 'CBC List',
        subtitle: 'Date, amount, transaction ID',
        icon: Icons.receipt_long_outlined,
        colors: const [Color(0xFF0E7490), Color(0xFF22C55E)],
        onTap: () => _open(context, 'cbc'),
      ),
      _PortalData(
        index: '03',
        title: 'C-TopUp',
        subtitle: 'Number, amount, payment status',
        icon: Icons.payments_outlined,
        colors: const [Color(0xFF7C3AED), Color(0xFFEC4899)],
        onTap: () => _open(context, 'ctopup'),
      ),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 900;
        if (!wide) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                HoverLift(child: _PortalCard(data: cards[i])),
                if (i < cards.length - 1) const SizedBox(height: 14),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: HoverLift(child: _PortalCard(data: cards[i]))),
              if (i < cards.length - 1) const SizedBox(width: 16),
            ],
          ],
        );
      },
    );
  }
}

class _PortalData {
  const _PortalData({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
  });
  final String index;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;
}

class _PortalCard extends StatelessWidget {
  const _PortalCard({required this.data});
  final _PortalData data;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: data.onTap,
        child: SizedBox(
          height: 210,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: data.colors,
                    ),
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              data.index,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const Spacer(),
                          Icon(data.icon, color: Colors.white, size: 32),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        data.title,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        data.subtitle,
                        style: const TextStyle(color: BsnlColors.muted, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded, color: BsnlColors.navy),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kept so older imports of DashboardPage still compile.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.auth, required this.simStore});
  final AuthStore auth;
  final SimStore simStore;

  @override
  Widget build(BuildContext context) {
    return DashboardHome(auth: auth, simStore: simStore);
  }
}
