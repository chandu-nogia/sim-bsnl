import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../state/auth_store.dart';
import '../state/sim_store.dart';
import '../widgets/fade_in.dart';
import 'cbc_page.dart';
import 'ctopup_page.dart';
import 'home_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.auth, required this.simStore});
  final AuthStore auth;
  final SimStore simStore;

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
                _DashHeader(auth: auth),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final wide = box.maxWidth >= 900;
                      return ListView(
                        padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 20, wide ? 28 : 16, 28),
                        children: [
                          FadeIn(
                            child: Text(
                              'Portals',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: BsnlColors.navyDark,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const FadeIn(
                            delay: Duration(milliseconds: 80),
                            child: Text(
                              'Teen lists — SIM, CBC, CTopup. Card pe click karke kholo.',
                              style: TextStyle(color: BsnlColors.muted, fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (!auth.canWrite) ...[
                            const SizedBox(height: 14),
                            FadeIn(
                              delay: const Duration(milliseconds: 120),
                              child: Card(
                                color: const Color(0xFFFFF8E1),
                                child: const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: Text(
                                    'Employee login: sirf dekh sakte ho. Add / edit / update / delete admin ke liye hai.',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          _PortalGrid(
                            wide: wide,
                            cards: [
                              _PortalData(
                                index: '01',
                                title: 'BSNL SIM Portal',
                                subtitle: 'All SIM details  •  CYMN / MNP / Swap / Postpaid',
                                icon: Icons.sim_card_outlined,
                                colors: const [Color(0xFF0B3D91), Color(0xFF1A73E8)],
                                onTap: () {
                                  simStore.load();
                                  Navigator.of(context).push(fadeRoute(HomePage(store: simStore)));
                                },
                              ),
                              _PortalData(
                                index: '02',
                                title: 'CBC List',
                                subtitle: 'Date, name, mobile, landline, amount, txn ID',
                                icon: Icons.receipt_long_outlined,
                                colors: const [Color(0xFF0E7490), Color(0xFF22C55E)],
                                onTap: () {
                                  Navigator.of(context).push(fadeRoute(CbcPage(auth: auth)));
                                },
                              ),
                              _PortalData(
                                index: '03',
                                title: 'CTopup',
                                subtitle: 'Date, name, number, amount, payment status',
                                icon: Icons.payments_outlined,
                                colors: const [Color(0xFF7C3AED), Color(0xFFEC4899)],
                                onTap: () {
                                  Navigator.of(context).push(fadeRoute(CtopupPage(auth: auth)));
                                },
                              ),
                            ],
                          ),
                        ],
                      );
                    },
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

class _DashHeader extends StatelessWidget {
  const _DashHeader({required this.auth});
  final AuthStore auth;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
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
                    const Text(
                      'BSNL Dashboard',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${auth.email ?? ''}  •  ${auth.isAdmin ? "Admin" : "Employee"}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
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

class _PortalGrid extends StatelessWidget {
  const _PortalGrid({required this.wide, required this.cards});
  final bool wide;
  final List<_PortalData> cards;

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return Column(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            FadeIn(
              delay: Duration(milliseconds: 140 + i * 110),
              child: HoverLift(child: _PortalCard(data: cards[i], tall: true)),
            ),
            if (i < cards.length - 1) const SizedBox(height: 14),
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          Expanded(
            child: FadeIn(
              delay: Duration(milliseconds: 140 + i * 110),
              child: HoverLift(child: _PortalCard(data: cards[i], tall: true)),
            ),
          ),
          if (i < cards.length - 1) const SizedBox(width: 16),
        ],
      ],
    );
  }
}

class _PortalCard extends StatelessWidget {
  const _PortalCard({required this.data, required this.tall});
  final _PortalData data;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: data.onTap,
        child: SizedBox(
          height: tall ? 220 : 180,
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
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
