import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../state/auth_store.dart';
import '../state/sim_store.dart';
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
          appBar: AppBar(
            title: const Text('BSNL Dashboard'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Text(
                    '${auth.email ?? ''}  •  ${auth.isAdmin ? "Admin" : "Employee"}',
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Logout',
                onPressed: auth.logout,
                icon: const Icon(Icons.logout),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (!auth.canWrite)
                Card(
                  color: const Color(0xFFFFF8E1),
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'Employee login: sirf dekh sakte ho. Add / edit / update / delete admin ke liye hai.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              _PortalCard(
                title: '1. BSNL SIM Portal',
                subtitle: 'All SIM details  •  CYMN / MNP / Swap / Postpaid',
                icon: Icons.sim_card_outlined,
                onTap: () {
                  simStore.load();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => HomePage(store: simStore)),
                  );
                },
              ),
              _PortalCard(
                title: '2. CBC List',
                subtitle: 'Name, mobile, landline, amount, transaction ID',
                icon: Icons.receipt_long_outlined,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => CbcPage(auth: auth)),
                  );
                },
              ),
              _PortalCard(
                title: '3. CTopup',
                subtitle: 'Name, number, amount, payment status',
                icon: Icons.payments_outlined,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => CtopupPage(auth: auth)),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PortalCard extends StatelessWidget {
  const _PortalCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: BsnlColors.navy,
          foregroundColor: Colors.white,
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
