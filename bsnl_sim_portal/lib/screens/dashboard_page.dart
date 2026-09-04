import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../state/auth_store.dart';
import '../state/sim_store.dart';
import '../util/format.dart';
import 'cbc_page.dart';
import 'ctopup_page.dart';
import 'home_page.dart';

class DashboardHome extends StatefulWidget {
  const DashboardHome({
    super.key,
    required this.auth,
    required this.simStore,
    this.onOpenSection,
  });
  final AuthStore auth;
  final SimStore simStore;
  final ValueChanged<String>? onOpenSection;

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};

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
      final json = await widget.auth.api.dashboard(widget.auth.apiBase);
      setState(() => _data = json);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> get _today =>
      _data['today'] is Map ? Map<String, dynamic>.from(_data['today'] as Map) : {};

  List<Map<String, dynamic>> get _activity => [
        for (final r in (_data['activity'] as List? ?? []))
          if (r is Map) Map<String, dynamic>.from(r),
      ];

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const Text(
            'BSNL Khatushyamji',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: BsnlColors.navyDark),
          ),
          const SizedBox(height: 4),
          const Text(
            'Khatushyamji Management Dashboard',
            style: TextStyle(color: BsnlColors.muted, fontWeight: FontWeight.w700),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, box) {
              final cols = box.maxWidth >= 900 ? 3 : box.maxWidth >= 600 ? 2 : 1;
              final w = (box.maxWidth - (cols - 1) * 12) / cols;
              final cards = [
                ('BSNL Portal Records', '${asNum(_data['sims']).round()}', Icons.sim_card_outlined, const Color(0xFF0B3D91), const Color(0xFF3B82F6), 'portal'),
                ('CBC Records', '${asNum(_data['cbc']).round()}', Icons.receipt_long_outlined, const Color(0xFF15803D), const Color(0xFF4ADE80), 'cbc'),
                ('CTOPUP Records', '${asNum(_data['ctopup']).round()}', Icons.payments_outlined, const Color(0xFF7C3AED), const Color(0xFFF472B6), 'ctopup'),
              ];
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final c in cards)
                    SizedBox(
                      width: w,
                      child: InkWell(
                        onTap: () => widget.onOpenSection?.call(c.$6),
                        borderRadius: BorderRadius.circular(18),
                        child: Ink(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: LinearGradient(colors: [c.$4, c.$5]),
                          ),
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(c.$3, color: Colors.white),
                              const SizedBox(height: 12),
                              Text(c.$1, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(c.$2, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          const Text('Today', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: BsnlColors.navyDark)),
          const SizedBox(height: 8),
          Text(
            'Portal ${asNum(_today['sims']).round()}  ·  CBC ${asNum(_today['cbc']).round()}  ·  CTOPUP ${asNum(_today['ctopup']).round()}',
            style: const TextStyle(fontWeight: FontWeight.w700, color: BsnlColors.muted),
          ),
          const SizedBox(height: 18),
          const Text('Quick actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: BsnlColors.navyDark)),
          const SizedBox(height: 10),
          LocationPortalGrid(
            auth: widget.auth,
            simStore: widget.simStore,
            locationId: widget.auth.locationId,
            locationName: 'Khatushyamji',
            onOpenModule: widget.onOpenSection,
          ),
          const SizedBox(height: 18),
          const Text('Recent activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: BsnlColors.navyDark)),
          const SizedBox(height: 8),
          if (_activity.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No activity yet', style: TextStyle(color: BsnlColors.muted))))
          else
            for (final a in _activity.take(8))
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text('${a['detail'] ?? a['action'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${a['name'] ?? ''}  ·  ${a['at'] ?? ''}'),
                ),
              ),
        ],
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
    this.onOpenModule,
  });
  final AuthStore auth;
  final SimStore simStore;
  final int? locationId;
  final String locationName;
  final void Function(String section)? onOpenModule;

  void _open(BuildContext context, String section) {
    if (onOpenModule != null) {
      onOpenModule!(section);
      return;
    }
    if (section == 'portal') {
      simStore.setLocation(locationId);
      simStore.load();
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => HomePage(store: simStore, locationName: locationName)));
      return;
    }
    if (section == 'cbc') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => CbcPage(auth: auth, locationId: locationId, locationName: locationName)));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CtopupPage(auth: auth, locationId: locationId, locationName: locationName)));
  }

  @override
  Widget build(BuildContext context) {
    final cards = [
      ('BSNL Portal', 'CYMN / MNP / Swap / Postpaid', Icons.sim_card_outlined, const [Color(0xFF0B3D91), Color(0xFF1A73E8)], 'portal'),
      ('CBC List', 'Date, amount, transaction ID', Icons.receipt_long_outlined, const [Color(0xFF0E7490), Color(0xFF22C55E)], 'cbc'),
      ('CTOPUP', 'Number, amount, payment status', Icons.payments_outlined, const [Color(0xFF7C3AED), Color(0xFFEC4899)], 'ctopup'),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 900;
        Widget card((String, String, IconData, List<Color>, String) c) {
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _open(context, c.$5),
              child: Container(
                height: 140,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(gradient: LinearGradient(colors: c.$4)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(c.$3, color: Colors.white),
                    const Spacer(),
                    Text(c.$1, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    Text(c.$2, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          );
        }

        if (!wide) {
          return Column(children: [for (final c in cards) ...[card(c), const SizedBox(height: 12)]]);
        }
        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: card(cards[i])),
              if (i < cards.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.auth, required this.simStore});
  final AuthStore auth;
  final SimStore simStore;

  @override
  Widget build(BuildContext context) {
    return DashboardHome(auth: auth, simStore: simStore);
  }
}
