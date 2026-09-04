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

  Map<String, dynamic> _map(String key) =>
      _data[key] is Map ? Map<String, dynamic>.from(_data[key] as Map) : {};

  Map<String, dynamic> get _totals => _map('totals');
  Map<String, dynamic> get _today => _map('today');
  Map<String, dynamic> get _week => _map('week');
  Map<String, dynamic> get _month => _map('month');
  Map<String, dynamic> get _types => _map('portalTypes');
  Map<String, dynamic> get _status => _map('ctopupStatus');

  List<Map<String, dynamic>> get _daily => asMaps(_data['daily']);
  List<Map<String, dynamic>> get _activity => asMaps(_data['activity']);

  Map<String, dynamic> _statusRow(String key) {
    final v = _status[key];
    if (v is Map) return Map<String, dynamic>.from(v);
    return {};
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Dashboard load ho raha hai…', style: TextStyle(color: BsnlColors.muted, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }
    final name = widget.auth.name.isEmpty ? 'Operator' : widget.auth.name;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
        children: [
          _Hero(
            name: name,
            records: asNum(_totals['records']).round(),
            amount: asNum(_totals['combinedAmount']),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: _error!, onRetry: _load),
          ],
          const SizedBox(height: 16),
          _SectionTitle('Overview', 'Khatushyamji totals'),
          const SizedBox(height: 10),
          _Responsive(
            children: [
              _Kpi(
                title: 'BSNL Portal',
                value: '${asNum(_data['sims']).round()}',
                subtitle: 'SIM / new users',
                icon: Icons.sim_card_outlined,
                colors: const [Color(0xFF0B3D91), Color(0xFF3B82F6)],
                onTap: () => widget.onOpenSection?.call('portal'),
              ),
              _Kpi(
                title: 'CBC Collection',
                value: rupee(asNum(_totals['cbcAmount'])),
                subtitle: '${asNum(_data['cbc']).round()} bills  ·  avg ${rupee(asNum(_totals['avgCbc']))}',
                icon: Icons.receipt_long_outlined,
                colors: const [Color(0xFF15803D), Color(0xFF22C55E)],
                onTap: () => widget.onOpenSection?.call('cbc'),
              ),
              _Kpi(
                title: 'CTOPUP Collection',
                value: rupee(asNum(_totals['ctopupAmount'])),
                subtitle: '${asNum(_data['ctopup']).round()} txns  ·  avg ${rupee(asNum(_totals['avgCtopup']))}',
                icon: Icons.payments_outlined,
                colors: const [Color(0xFF7C3AED), Color(0xFFEC4899)],
                onTap: () => widget.onOpenSection?.call('ctopup'),
              ),
              _Kpi(
                title: 'Total Business',
                value: rupee(asNum(_totals['combinedAmount'])),
                subtitle: 'CBC + CTOPUP combined',
                icon: Icons.account_balance_wallet_outlined,
                colors: const [Color(0xFF0E7490), Color(0xFF06B6D4)],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionTitle('Period calculations', 'Today, 7 days, this month'),
          const SizedBox(height: 10),
          _PeriodTable(today: _today, week: _week, month: _month),
          const SizedBox(height: 20),
          _SectionTitle('Last 7 days', 'CBC + CTOPUP amount'),
          const SizedBox(height: 10),
          _DayChart(days: _daily),
          const SizedBox(height: 20),
          _SectionTitle('Portal mix', 'CYMN / MNP / Swap / Postpaid'),
          const SizedBox(height: 10),
          _TypeRow(types: _types, total: asNum(_data['sims'])),
          const SizedBox(height: 20),
          _SectionTitle('CTOPUP payment status', 'Paid, pending, failed'),
          const SizedBox(height: 10),
          _StatusRow(
            paid: _statusRow('Paid'),
            pending: _statusRow('Pending'),
            failed: _statusRow('Failed'),
          ),
          const SizedBox(height: 20),
          _SectionTitle('Quick actions', 'Open a module'),
          const SizedBox(height: 10),
          LocationPortalGrid(
            auth: widget.auth,
            simStore: widget.simStore,
            locationId: widget.auth.locationId,
            locationName: 'Khatushyamji',
            onOpenModule: widget.onOpenSection,
          ),
          const SizedBox(height: 20),
          _SectionTitle('Recent activity', 'Latest Portal / CBC / CTOPUP work'),
          const SizedBox(height: 8),
          if (_activity.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No activity yet', style: TextStyle(color: BsnlColors.muted)),
              ),
            )
          else
            for (final a in _activity.take(10))
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFEEF2FF),
                    child: Icon(_activityIcon('${a['section']}'), color: BsnlColors.navy, size: 18),
                  ),
                  title: Text('${a['detail'] ?? a['action'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${a['name'] ?? ''}  ·  ${a['at'] ?? ''}'),
                ),
              ),
        ],
      ),
    );
  }

  IconData _activityIcon(String section) {
    if (section == 'cbc') return Icons.receipt_long_outlined;
    if (section == 'ctopup') return Icons.payments_outlined;
    if (section == 'auth') return Icons.login;
    return Icons.sim_card_outlined;
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.name, required this.records, required this.amount});
  final String name;
  final int records;
  final num amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF071A44), Color(0xFF0B3D91), Color(0xFF7C3AED)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x330B3D91), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('BSNL Khatushyamji', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Welcome back, $name', style: const TextStyle(color: Color(0xFFD7DEEA), fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _pill('$records records'),
              _pill('${rupee(amount)} business'),
              _pill('Personal management'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFEBEE),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(child: Text(message, style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.w700))),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.subtitle);
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: BsnlColors.navyDark)),
        Text(subtitle, style: const TextStyle(color: BsnlColors.muted, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _Responsive extends StatelessWidget {
  const _Responsive({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth >= 1100 ? 4 : box.maxWidth >= 700 ? 2 : 1;
        final w = (box.maxWidth - (cols - 1) * 12) / cols;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final c in children) SizedBox(width: w, child: c)],
        );
      },
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.colors,
    this.onTap,
  });
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(colors: colors),
            boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.28), blurRadius: 12, offset: const Offset(0, 6))],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(height: 14),
              Text(title, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodTable extends StatelessWidget {
  const _PeriodTable({required this.today, required this.week, required this.month});
  final Map<String, dynamic> today;
  final Map<String, dynamic> week;
  final Map<String, dynamic> month;

  @override
  Widget build(BuildContext context) {
    Widget card(String title, Map<String, dynamic> m, List<Color> colors) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BsnlColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
            const SizedBox(height: 12),
            Text(rupee(asNum(m['combinedAmount'])), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: BsnlColors.navyDark)),
            const SizedBox(height: 8),
            Text('Portal  ${asNum(m['sims']).round()}', style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('CBC  ${asNum(m['cbc']).round()}  ·  ${rupee(asNum(m['cbcAmount']))}', style: const TextStyle(fontWeight: FontWeight.w600, color: BsnlColors.muted)),
            Text('CTOPUP  ${asNum(m['ctopup']).round()}  ·  ${rupee(asNum(m['ctopupAmount']))}', style: const TextStyle(fontWeight: FontWeight.w600, color: BsnlColors.muted)),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, box) {
        final cards = [
          card('Today', today, const [Color(0xFF0B3D91), Color(0xFF3B82F6)]),
          card('7 days', week, const [Color(0xFF15803D), Color(0xFF22C55E)]),
          card('This month', month, const [Color(0xFF7C3AED), Color(0xFFEC4899)]),
        ];
        if (box.maxWidth < 720) {
          return Column(children: [for (final c in cards) ...[c, const SizedBox(height: 10)]]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i < 2) const SizedBox(width: 10),
            ],
          ],
        );
      },
    );
  }
}

class _DayChart extends StatelessWidget {
  const _DayChart({required this.days});
  final List<Map<String, dynamic>> days;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No chart data yet', style: TextStyle(color: BsnlColors.muted))));
    }
    final maxAmt = days.map((d) => asNum(d['amount'])).fold<num>(0, (a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final d in days)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      Text(rupee(asNum(d['amount'])), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: BsnlColors.muted)),
                      const SizedBox(height: 6),
                      Container(
                        height: 110,
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: maxAmt <= 0 ? 0.06 : (asNum(d['amount']) / maxAmt).clamp(0.06, 1),
                          widthFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: const LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Color(0xFF0B3D91), Color(0xFF7C3AED)],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('${d['label']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  const _TypeRow({required this.types, required this.total});
  final Map<String, dynamic> types;
  final num total;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('CYMN', const Color(0xFF0B3D91)),
      ('MNP', const Color(0xFFEA580C)),
      ('Swap', const Color(0xFF7C3AED)),
      ('Postpaid', const Color(0xFFCA8A04)),
    ];
    return _Responsive(
      children: [
        for (final t in items)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.$1, style: TextStyle(color: t.$2, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('${asNum(types[t.$1]).round()}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: BsnlColors.navyDark)),
                  Text(total <= 0 ? '0%' : '${((asNum(types[t.$1]) / total) * 100).toStringAsFixed(0)}% of portal', style: const TextStyle(color: BsnlColors.muted, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.paid, required this.pending, required this.failed});
  final Map<String, dynamic> paid;
  final Map<String, dynamic> pending;
  final Map<String, dynamic> failed;

  @override
  Widget build(BuildContext context) {
    Widget card(String title, Map<String, dynamic> m, Color color) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('${asNum(m['n']).round()} txns', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: BsnlColors.navyDark)),
              Text(rupee(asNum(m['amount'])), style: const TextStyle(fontWeight: FontWeight.w700, color: BsnlColors.muted)),
            ],
          ),
        ),
      );
    }

    return _Responsive(
      children: [
        card('Paid', paid, const Color(0xFF15803D)),
        card('Pending', pending, const Color(0xFFCA8A04)),
        card('Failed', failed, const Color(0xFFB91C1C)),
      ],
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
      ('CBC List', 'Bills, amount, transaction ID', Icons.receipt_long_outlined, const [Color(0xFF0E7490), Color(0xFF22C55E)], 'cbc'),
      ('CTOPUP', 'Recharge, amount, payment status', Icons.payments_outlined, const [Color(0xFF7C3AED), Color(0xFFEC4899)], 'ctopup'),
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
