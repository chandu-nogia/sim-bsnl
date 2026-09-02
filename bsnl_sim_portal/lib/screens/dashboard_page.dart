import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_theme.dart';
import '../state/auth_store.dart';
import '../state/sim_store.dart';
import '../widgets/fade_in.dart';
import 'cbc_page.dart';
import 'ctopup_page.dart';
import 'home_page.dart';
import 'location_form_page.dart';

String rupee(num n) {
  final f = NumberFormat.decimalPattern('en_IN');
  return '₹${f.format(n.round())}';
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.auth, required this.simStore});
  final AuthStore auth;
  final SimStore simStore;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _totals = {};
  List<Map<String, dynamic>> _locations = [];
  List<Map<String, dynamic>> _activity = [];

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
          _totals = summary['totals'] is Map
              ? Map<String, dynamic>.from(summary['totals'] as Map)
              : {};
          _locations = [
            for (final r in (summary['byLocation'] as List? ?? []))
              Map<String, dynamic>.from(r as Map),
          ];
          _activity = activity;
        });
      } else {
        final rows = await auth.api.listLocations(auth.apiBase);
        setState(() => _locations = rows);
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openLocation(int id, String name) {
    Navigator.of(context).push(
      fadeRoute(
        LocationHubPage(
          auth: auth,
          simStore: widget.simStore,
          locationId: id,
          locationName: name,
        ),
      ),
    );
  }

  Future<void> _addLocation() async {
    final ok = await Navigator.of(context).push<bool>(
      fadeRoute(LocationFormPage(auth: auth)),
    );
    if (ok == true) _load();
  }

  Future<void> _editLocation(Map<String, dynamic> loc) async {
    final ok = await Navigator.of(context).push<bool>(
      fadeRoute(LocationFormPage(auth: auth, existing: loc)),
    );
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: auth,
      builder: (context, _) {
        return Scaffold(
          body: Container(
            decoration: bsnlPageGradient(),
            child: Column(
              children: [
                _DashHeader(auth: auth, onRefresh: _load),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
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
                                FadeIn(child: _AdminTotals(totals: _totals, places: _locations.length)),
                                const SizedBox(height: 16),
                                FadeIn(
                                  delay: const Duration(milliseconds: 80),
                                  child: Row(
                                    children: [
                                      const Text(
                                        'Jagah / Branches',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: BsnlColors.navyDark,
                                        ),
                                      ),
                                      const Spacer(),
                                      FilledButton.icon(
                                        onPressed: _addLocation,
                                        icon: const Icon(Icons.add),
                                        label: const Text('Jagah add'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                for (var i = 0; i < _locations.length; i++)
                                  FadeIn(
                                    delay: Duration(milliseconds: 100 + i * 70),
                                    child: _LocationTile(
                                      row: _locations[i],
                                      admin: true,
                                      onOpen: () => _openLocation(
                                        _asInt(_locations[i]['id']) ?? 0,
                                        '${_locations[i]['name'] ?? ''}',
                                      ),
                                      onEdit: () => _editLocation(_locations[i]),
                                    ),
                                  ),
                                const SizedBox(height: 18),
                                const FadeIn(
                                  child: Text(
                                    'Sabhi activity',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: BsnlColors.navyDark,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (_activity.isEmpty)
                                  const Card(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text('Abhi koi activity nahi', style: TextStyle(color: BsnlColors.muted)),
                                    ),
                                  )
                                else
                                  for (final a in _activity.take(30)) _ActivityTile(row: a),
                              ] else if ((auth.locationId ?? 0) == 0) ...[
                                const Card(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(
                                      'Is account ki jagah nahi mili. Logout karke dubara login karo.',
                                      style: TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ] else ...[
                                FadeIn(
                                  child: Text(
                                    auth.locationName.isEmpty ? 'Aapki jagah' : '${auth.locationName} Dashboard',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: BsnlColors.navyDark,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const FadeIn(
                                  delay: Duration(milliseconds: 60),
                                  child: Text(
                                    'Yahan SIM, CBC aur CTopup — add / edit / delete kar sakte ho.',
                                    style: TextStyle(color: BsnlColors.muted, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                LocationPortalGrid(
                                  auth: auth,
                                  simStore: widget.simStore,
                                  locationId: auth.locationId ?? 0,
                                  locationName: auth.locationName,
                                ),
                              ],
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v');
}

num _num(dynamic v) {
  if (v is num) return v;
  return num.tryParse('$v') ?? 0;
}

class _DashHeader extends StatelessWidget {
  const _DashHeader({required this.auth, required this.onRefresh});
  final AuthStore auth;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
        child: FadeIn(
          offset: const Offset(0, -12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: BsnlColors.gold,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.hub_outlined, color: BsnlColors.navyDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auth.isAdmin ? 'Admin Dashboard' : 'BSNL Dashboard',
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      auth.isAdmin
                          ? '${auth.email ?? ''}  •  Pura control'
                          : '${auth.email ?? ''}  •  ${auth.locationName.isEmpty ? "Employee" : auth.locationName}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh, color: Colors.white)),
              IconButton(
                tooltip: 'Logout',
                onPressed: auth.logout,
                icon: const Icon(Icons.logout, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminTotals extends StatelessWidget {
  const _AdminTotals({required this.totals, required this.places});
  final Map<String, dynamic> totals;
  final int places;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Jagah', '$places', Icons.place_outlined, const Color(0xFF0B3D91)),
      ('Naye users aaj', '${_num(totals['newUsersToday']).round()}', Icons.person_add_alt_1_outlined, const Color(0xFF1A73E8)),
      ('SIM entries', '${_num(totals['sims']).round()}', Icons.sim_card_outlined, const Color(0xFF0E7490)),
      ('CBC amount', rupee(_num(totals['cbcAmount'])), Icons.receipt_long_outlined, const Color(0xFF16A34A)),
      ('CTopup amount', rupee(_num(totals['ctopupAmount'])), Icons.payments_outlined, const Color(0xFF7C3AED)),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth >= 900 ? (box.maxWidth - 40) / 5 : (box.maxWidth - 10) / 2;
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
                        Text(it.$1, style: const TextStyle(color: BsnlColors.muted, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(it.$2, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
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

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.row,
    required this.admin,
    required this.onOpen,
    required this.onEdit,
  });
  final Map<String, dynamic> row;
  final bool admin;
  final VoidCallback onOpen;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: BsnlColors.navy,
                foregroundColor: Colors.white,
                child: Text(
                  (() {
                    final n = '${row['name'] ?? 'J'}'.trim();
                    return n.isEmpty ? 'J' : n.substring(0, 1).toUpperCase();
                  })(),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${row['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('${row['email'] ?? ''}', style: const TextStyle(color: BsnlColors.muted, fontSize: 12)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      children: [
                        _chip('SIM ${_num(row['sims']).round()}'),
                        _chip('CBC ${rupee(_num(row['cbcAmount']))}'),
                        _chip('CTopup ${rupee(_num(row['ctopupAmount']))}'),
                        _chip('Aaj +${_num(row['newUsersToday']).round()} users'),
                      ],
                    ),
                  ],
                ),
              ),
              if (admin)
                IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, color: BsnlColors.navy)),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.row});
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
            _ => Icons.history,
          },
          color: BsnlColors.navy,
        ),
        title: Text('${row['detail'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${row['locationName'] ?? ''}  •  ${row['email'] ?? ''}  •  ${row['section'] ?? ''}\n${row['at'] ?? ''}',
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
  });
  final AuthStore auth;
  final SimStore simStore;
  final int locationId;
  final String locationName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: bsnlPageGradient(),
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    Expanded(
                      child: Text(
                        '$locationName Dashboard',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  const Text(
                    'Teen sections isi jagah ke hisaab se',
                    style: TextStyle(color: BsnlColors.navyDark, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  LocationPortalGrid(
                    auth: auth,
                    simStore: simStore,
                    locationId: locationId,
                    locationName: locationName,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
  final int locationId;
  final String locationName;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _PortalData(
        index: '01',
        title: 'BSNL SIM Portal',
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
        title: 'CTopup',
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
