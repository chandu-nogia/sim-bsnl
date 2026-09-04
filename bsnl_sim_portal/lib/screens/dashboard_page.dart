import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../state/auth_store.dart';
import '../state/sim_store.dart';
import '../util/format.dart';
import '../widgets/bar_chart.dart';
import '../widgets/fade_in.dart';
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
  Map<String, dynamic> _totals = {};
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
          _totals = summary['totals'] is Map ? Map<String, dynamic>.from(summary['totals'] as Map) : {};
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
                'All records  •  All locations',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: BsnlColors.navyDark),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Har jagah ka BSNL, CBC aur C-TopUp alag. Cards par click karke list kholo.',
              style: TextStyle(color: BsnlColors.muted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            _StatGrid(
              items: [
                _DashStat('Locations', '$_locationsCount', Icons.place_outlined, const Color(0xFF0B3D91), const Color(0xFF3B82F6), 'locations'),
                _DashStat('Employees', '$_employeesCount', Icons.badge_outlined, const Color(0xFF1D4ED8), const Color(0xFF60A5FA), 'employees'),
                _DashStat('Active staff', '$_activeEmployees', Icons.verified_outlined, const Color(0xFF0369A1), const Color(0xFF22D3EE), 'employees'),
                _DashStat('BSNL records', '${asNum(_totals['sims']).round()}', Icons.sim_card_outlined, const Color(0xFF0E7490), const Color(0xFF2DD4BF), 'portal'),
                _DashStat('CBC records', '${asNum(_totals['cbcCount']).round()}', Icons.receipt_long_outlined, const Color(0xFF15803D), const Color(0xFF4ADE80), 'cbc'),
                _DashStat('C-TopUp records', '${asNum(_totals['ctopupCount']).round()}', Icons.payments_outlined, const Color(0xFF7C3AED), const Color(0xFFF472B6), 'ctopup'),
                _DashStat('CBC amount', rupee(asNum(_totals['cbcAmount'])), Icons.account_balance_wallet_outlined, const Color(0xFF047857), const Color(0xFF34D399), 'cbc'),
                _DashStat('C-TopUp amount', rupee(asNum(_totals['ctopupAmount'])), Icons.currency_rupee, const Color(0xFF6D28D9), const Color(0xFFC084FC), 'ctopup'),
                _DashStat('Today CBC', rupee(asNum(_totals['cbcAmountToday'])), Icons.today_outlined, const Color(0xFF059669), const Color(0xFFA3E635), 'cbc'),
                _DashStat('Today C-TopUp', rupee(asNum(_totals['ctopupAmountToday'])), Icons.today, const Color(0xFF9333EA), const Color(0xFFFB7185), 'ctopup'),
                _DashStat('Monthly CBC', rupee(asNum(_totals['cbcAmountMonth'])), Icons.calendar_month, const Color(0xFF0F766E), const Color(0xFF5EEAD4), 'cbc'),
                _DashStat('Monthly C-TopUp', rupee(asNum(_totals['ctopupAmountMonth'])), Icons.calendar_today, const Color(0xFF5B21B6), const Color(0xFFF9A8D4), 'ctopup'),
                _DashStat('Transactions', '${asNum(_totals['transactions']).round()}', Icons.swap_horiz, const Color(0xFF1D4ED8), const Color(0xFF38BDF8), 'reports'),
                _DashStat('New users today', '${asNum(_totals['newUsersToday']).round()}', Icons.person_add_alt, const Color(0xFFEA580C), const Color(0xFFFBBF24), 'portal'),
                _DashStat('New users month', '${asNum(_totals['newUsersMonth']).round()}', Icons.group_add_outlined, const Color(0xFFB45309), const Color(0xFFF59E0B), 'portal'),
                _DashStat('Today activity', '$_todayActivity', Icons.bolt_outlined, const Color(0xFFBE123C), const Color(0xFFFB7185), 'activity'),
                _DashStat('Pending C-TopUp', '$_pending', Icons.hourglass_empty, const Color(0xFFC2410C), const Color(0xFFF97316), 'ctopup'),
                _DashStat('Failed C-TopUp', '$_failed', Icons.error_outline, const Color(0xFFB91C1C), const Color(0xFFF43F5E), 'ctopup'),
              ],
              onOpen: (id) => widget.onOpenSection?.call(id),
            ),
            const SizedBox(height: 18),
            const Text('Charts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: BsnlColors.navyDark)),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, box) {
                final charts = [
                  SimpleBarChart(title: 'Portal records by location', points: _pts('usersByLocation'), colors: const [Color(0xFF0E7490), Color(0xFF22D3EE)]),
                  SimpleBarChart(title: 'CBC amount by location', points: _pts('cbcByLocation'), colors: const [Color(0xFF15803D), Color(0xFF4ADE80)]),
                  SimpleBarChart(title: 'C-TopUp by location', points: _pts('ctopupByLocation'), colors: const [Color(0xFF7C3AED), Color(0xFFF472B6)]),
                  SimpleBarChart(title: 'Daily transactions', points: _pts('dailyTxns'), colors: const [Color(0xFF1D4ED8), Color(0xFF38BDF8)]),
                  SimpleBarChart(title: 'Monthly amounts', points: _pts('monthlyAmounts'), colors: const [Color(0xFF0F766E), Color(0xFFFBBF24)]),
                  SimpleBarChart(title: 'Employee activity', points: _pts('employeeActivity'), colors: const [Color(0xFFEA580C), Color(0xFFF59E0B)]),
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
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('Location-wise data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: BsnlColors.navyDark)),
                const Spacer(),
                TextButton(onPressed: () => widget.onOpenSection?.call('locations'), child: const Text('Manage locations')),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Har location ka Portal / CBC / C-TopUp alag table. Card par click karke us jagah ka data kholo.',
              style: TextStyle(color: BsnlColors.muted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, box) {
                final cols = box.maxWidth >= 1100 ? 2 : 1;
                final w = cols == 1 ? box.maxWidth : (box.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (var i = 0; i < _locations.length; i++)
                      SizedBox(
                        width: w,
                        child: _LocationCard(
                          row: _locations[i],
                          colorIndex: i,
                          onOpen: () => _openLoc(_locations[i], 'mylocation'),
                          onOpenPortal: () => _openLoc(_locations[i], 'portal'),
                          onOpenCbc: () => _openLoc(_locations[i], 'cbc'),
                          onOpenCtopup: () => _openLoc(_locations[i], 'ctopup'),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Card(
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFF0B3D91)),
                  headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  columns: const [
                    DataColumn(label: Text('Location')),
                    DataColumn(label: Text('Employees')),
                    DataColumn(label: Text('BSNL')),
                    DataColumn(label: Text('CBC')),
                    DataColumn(label: Text('CBC ₹')),
                    DataColumn(label: Text('C-TopUp')),
                    DataColumn(label: Text('C-TopUp ₹')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: [
                    for (final row in _locations)
                      DataRow(
                        cells: [
                          DataCell(
                            Text('${row['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            onTap: () => _openLoc(row, 'mylocation'),
                          ),
                          DataCell(Text('${asNum(row['employees']).round()}'), onTap: () => widget.onOpenSection?.call('employees')),
                          DataCell(Text('${asNum(row['sims']).round()}'), onTap: () => _openLoc(row, 'portal')),
                          DataCell(Text('${asNum(row['cbcCount']).round()}'), onTap: () => _openLoc(row, 'cbc')),
                          DataCell(Text(rupee(asNum(row['cbcAmount']))), onTap: () => _openLoc(row, 'cbc')),
                          DataCell(Text('${asNum(row['ctopupCount']).round()}'), onTap: () => _openLoc(row, 'ctopup')),
                          DataCell(Text(rupee(asNum(row['ctopupAmount']))), onTap: () => _openLoc(row, 'ctopup')),
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
              for (final a in _activity.take(12)) ActivityTile(row: a),
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
                _DashStat('Users', '${asNum(_mine['sims']).round()}', Icons.people_outline, const Color(0xFF0E7490), const Color(0xFF22D3EE), 'portal'),
                _DashStat('CBC', rupee(asNum(_mine['cbcAmount'])), Icons.receipt_long_outlined, const Color(0xFF15803D), const Color(0xFF4ADE80), 'cbc'),
                _DashStat('C-TopUp', rupee(asNum(_mine['ctopupAmount'])), Icons.payments_outlined, const Color(0xFF7C3AED), const Color(0xFFF472B6), 'ctopup'),
                _DashStat('Today users', '${asNum(_mine['newUsersToday']).round()}', Icons.person_add_alt, const Color(0xFFEA580C), const Color(0xFFFBBF24), 'portal'),
              ],
              onOpen: (id) {
                final locId = auth.effectiveLocationId ?? 0;
                widget.onOpenLocation?.call(locId, auth.locationName, id);
              },
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

class _DashStat {
  const _DashStat(this.label, this.value, this.icon, this.from, this.to, this.section);
  final String label;
  final String value;
  final IconData icon;
  final Color from;
  final Color to;
  final String section;
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.items, this.onOpen});
  final List<_DashStat> items;
  final void Function(String section)? onOpen;

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
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onOpen == null ? null : () => onOpen!(it.section),
                    borderRadius: BorderRadius.circular(18),
                    child: Ink(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [it.from, it.to],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: it.from.withValues(alpha: 0.28),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(it.icon, color: Colors.white, size: 22),
                            const SizedBox(height: 10),
                            Text(
                              it.label,
                              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              it.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
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

const _locPalette = [
  [Color(0xFF0B3D91), Color(0xFF3B82F6)],
  [Color(0xFF0E7490), Color(0xFF14B8A6)],
  [Color(0xFF7C3AED), Color(0xFFEC4899)],
  [Color(0xFFB45309), Color(0xFFF59E0B)],
  [Color(0xFF15803D), Color(0xFF4ADE80)],
  [Color(0xFFBE123C), Color(0xFFFB7185)],
];

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.row,
    required this.colorIndex,
    required this.onOpen,
    required this.onOpenPortal,
    required this.onOpenCbc,
    required this.onOpenCtopup,
  });
  final Map<String, dynamic> row;
  final int colorIndex;
  final VoidCallback onOpen;
  final VoidCallback onOpenPortal;
  final VoidCallback onOpenCbc;
  final VoidCallback onOpenCtopup;

  @override
  Widget build(BuildContext context) {
    final colors = _locPalette[colorIndex % _locPalette.length];
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white24,
                    foregroundColor: Colors.white,
                    child: Text(
                      '${row['name'] ?? 'L'}'.isEmpty ? 'L' : '${row['name']}'.substring(0, 1).toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${row['name'] ?? ''}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                        Text(
                          '${row['code'] ?? ''}  •  ${row['status'] ?? 'active'}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip('Portal ${asNum(row['sims']).round()}', const Color(0xFFD6E8FF), const Color(0xFF0B3D91)),
                      _chip('CBC ${asNum(row['cbcCount']).round()}', const Color(0xFFD1FAE5), const Color(0xFF047857)),
                      _chip(rupee(asNum(row['cbcAmount'])), const Color(0xFFD1FAE5), const Color(0xFF047857)),
                      _chip('TopUp ${asNum(row['ctopupCount']).round()}', const Color(0xFFEDE9FE), const Color(0xFF6D28D9)),
                      _chip(rupee(asNum(row['ctopupAmount'])), const Color(0xFFFCE7F3), const Color(0xFF9D174D)),
                      _chip('Staff ${asNum(row['employees']).round()}', const Color(0xFFFFE4C4), const Color(0xFF9A3412)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0B3D91)),
                        onPressed: onOpenPortal,
                        icon: const Icon(Icons.sim_card_outlined, size: 16),
                        label: const Text('BSNL Portal'),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF15803D)),
                        onPressed: onOpenCbc,
                        icon: const Icon(Icons.receipt_long_outlined, size: 16),
                        label: const Text('CBC List'),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
                        onPressed: onOpenCtopup,
                        icon: const Icon(Icons.payments_outlined, size: 16),
                        label: const Text('C-TopUp'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String t, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: fg)),
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
        leading: CircleAvatar(
          backgroundColor: switch ('${row['action']}') {
            'add' => const Color(0xFFD1FAE5),
            'delete' => const Color(0xFFFECACA),
            'update' => const Color(0xFFDBEAFE),
            'login' => const Color(0xFFEDE9FE),
            _ => const Color(0xFFFFE4C4),
          },
          child: Icon(
            switch ('${row['action']}') {
              'add' => Icons.add_circle_outline,
              'delete' => Icons.delete_outline,
              'update' => Icons.edit_outlined,
              'login' => Icons.login,
              _ => Icons.history,
            },
            color: switch ('${row['action']}') {
              'add' => const Color(0xFF047857),
              'delete' => const Color(0xFFB91C1C),
              'update' => const Color(0xFF1D4ED8),
              'login' => const Color(0xFF7C3AED),
              _ => const Color(0xFFB45309),
            },
          ),
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
