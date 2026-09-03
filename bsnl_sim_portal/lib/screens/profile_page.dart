import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../state/auth_store.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.auth});
  final AuthStore auth;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const Text(
          'Profile',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: BsnlColors.navyDark),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('Name', auth.name.isEmpty ? '—' : auth.name),
                _row('Email / Login ID', auth.email ?? '—'),
                _row('Role', auth.isAdmin ? 'Admin' : 'Employee'),
                _row('Assigned Location', auth.locationName.isEmpty ? '—' : auth.locationName),
                const SizedBox(height: 8),
                const Text(
                  'Location change nahi ho sakti. Admin hi assigned location set karta hai.',
                  style: TextStyle(color: BsnlColors.muted, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: BsnlColors.muted, fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ],
      ),
    );
  }
}
