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
    this.onLocationsChanged,
  });
  final AuthStore auth;
  final SimStore simStore;
  final ValueChanged<String>? onOpenSection;
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
                'Organization overview',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: BsnlColors.navyDark),
              ),
            ),
            const SizedBox(height: 12),
            _StatGrid(
              items: [
                ('Locations', '$_locationsCount', Icons.place_outlined, const Color(0xFF0B3D91)),
                ('Employees', '$_employeesCount', Icons.badge_outlined, const Color(0xFF1A73E8)),
                ('Total users', '${asNum(_totals['sims']).round()}', Icons.people_outline, const Color(0xFF0E7490)),
                ('CBC amount', rupee(asNum(_totals['cbcAmount'])), Icons.receipt_long_outlined, const Color(0xFF16A34A)),
                ('C-TopUp amount', rupee(asNum(_totals['ctopupAmount'])), Icons.payments_outlined, const Color(0xFF7C3AED)),
                ('Today CBC', rupee(asNum(_totals['cbcAmountToday'])), Icons.today_outlined, const Color(0xFF059669)),
                ('Today C-TopUp', rupee(asNum(_totals['ctopupAmountToday'])), Icons.today, const Color(0xFF9333EA)),
                ('Monthly CBC', rupee(asNum(_totals['cbcAmountMonth'])), Icons.calendar_month, const Color(0xFF0F766E)),
                ('Monthly C-TopUp', rupee(asNum(_totals['ctopupAmountMonth'])), Icons.calendar_today, const Color(0xFF6D28D9)),
                ('Transactions', '${asNum(_totals['transactions']).round()}', Icons.swap_horiz, const Color(0xFF1D4ED8)),
                ('New users today', '${asNum(_totals['newUsersToday']).round()}', Icons.person_add_alt, const Color(0xFF0369A1)),
                ('New users month', '${asNum(_totals['newUsersMonth']).round()}', Icons.group_add_outlined, const Color(0xFFB45309)),
              ],
            ),
            const SizedBox(height: 16),
            FadeIn(
              child: Text(
                'New users  •  today ${asNum(_totals['newUsersToday']).round()}  •  week ${asNum(_totals['newUsersWeek']).round()}  •  month ${asNum(_totals['newUsersMonth']).round()}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: BsnlColors.muted),
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, box) {
                final wide = box.maxWidth >= 900;
                final charts = [
                  SimpleBarChart(title: 'New users by location', points: _pts('usersByLocation')),
                  SimpleBarChart(title: 'CBC amount by location', points: _pts('cbcByLocation')),
                  SimpleBarChart(title: 'C-TopUp by location', points: _pts('ctopupByLocation')),
                  SimpleBarChart(title: 'Daily transactions', points: _pts('dailyTxns')),
                  SimpleBarChart(title: 'Monthly amounts', points: _pts('monthlyAmounts')),
                  SimpleBarChart(title: 'Employee activity', points: _pts('employeeActivity')),
                ];
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
                const Text('Locations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: BsnlColors.navyDark)),
                const Spacer(),
                TextButton(
                  onPressed: () => widget.onOpenSection?.call('locations'),
                  child: const Text('Manage'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final row in _locations)
              _LocationCard(
                row: row,
                onOpen: () async {
                  final id = asInt(row['id']) ?? 0;
                  await auth.selectLocation(id, name: '${row['name'] ?? ''}');
                  widget.onOpenSection?.call('mylocation');
                },
              ),
            const SizedBox(height: 16),
            const Text('Recent activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: BsnlColors.navyDark)),
            const SizedBox(height: 8),
            if (_activity.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No activity yet', style: TextStyle(color: BsnlColors.muted))))
            else
              for (final a in _activity.take(12)) ActivityTile(row: a),
          ] else ...[
            Text(
              _locTitle(),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: BsnlColors.navyDark),
            ),
            const SizedBox(height: 10),
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
            ),
          ],
        ],
      ),
    );
  }

  String _locTitle() {
    if (auth.locationName.isNotEmpty) return '${auth.locationName} dashboard';
    return 'My location';
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

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.row, required this.onOpen});
  final Map<String, dynamic> row;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: BsnlColors.navy,
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
                        Text('${row['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        Text(
                          '${row['code'] ?? ''}  •  ${row['status'] ?? 'active'}',
                          style: const TextStyle(color: BsnlColors.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip('Employees ${asNum(row['employees']).round()}'),
                  _chip('New users ${asNum(row['newUsers']).round()}'),
                  _chip('CBC ${rupee(asNum(row['cbcAmount']))}'),
                  _chip('C-TopUp ${rupee(asNum(row['ctopupAmount']))}'),
                  _chip('Txns ${asNum(row['transactions']).round()}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
      child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
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
  });
  final AuthStore auth;
  final SimStore simStore;
  final int locationId;
  final String locationName;
  final bool embedded;

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
  });
  final AuthStore auth;
  final SimStore simStore;
  final int? locationId;
  final String locationName;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _PortalData(
        index: '01',
        title: 'BSNL Portal',
        subtitle: 'CYMN / MNP / Swap / Postpaid',
        icon: Icons.sim_card_outlined,
        colors: const [Color(0xFF0B3D91), Color(0xFF1A73E8)],
        onTap: () {
          simStore.setLocation(locationId);
          simStore.load();
          Navigator.of(context).push(
            fadeRoute(HomePage(store: simStore, locationName: locationName)),
          );
        },
      ),
      _PortalData(
        index: '02',
        title: 'CBC List',
        subtitle: 'Date, amount, transaction ID',
        icon: Icons.receipt_long_outlined,
        colors: const [Color(0xFF0E7490), Color(0xFF22C55E)],
        onTap: () {
          Navigator.of(context).push(
            fadeRoute(CbcPage(auth: auth, locationId: locationId, locationName: locationName)),
          );
        },
      ),
      _PortalData(
        index: '03',
        title: 'C-TopUp',
        subtitle: 'Number, amount, payment status',
        icon: Icons.payments_outlined,
        colors: const [Color(0xFF7C3AED), Color(0xFFEC4899)],
        onTap: () {
          Navigator.of(context).push(
            fadeRoute(CtopupPage(auth: auth, locationId: locationId, locationName: locationName)),
          );
        },
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
