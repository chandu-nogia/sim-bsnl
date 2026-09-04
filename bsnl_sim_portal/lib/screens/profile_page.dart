import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../state/auth_store.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.auth});
  final AuthStore auth;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController _name;
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _busy = false;

  AuthStore get auth => widget.auth;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: auth.name);
  }

  @override
  void dispose() {
    _name.dispose();
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    setState(() => _busy = true);
    try {
      await auth.api.updateProfile(auth.apiBase, _name.text.trim());
      await auth.loadSaved();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name saved')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _savePassword() async {
    setState(() => _busy = true);
    try {
      await auth.api.changePassword(auth.apiBase, _current.text, _next.text);
      _current.clear();
      _next.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        const Text('Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: BsnlColors.navyDark)),
        const SizedBox(height: 6),
        const Text('Assigned location admin set karta hai. Ye change nahi ho sakti.', style: TextStyle(color: BsnlColors.muted)),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _read('Email / Login ID', auth.email ?? '—'),
                _read('Role', auth.isAdmin ? 'Admin' : 'Employee'),
                _read('Assigned Location', auth.locationName.isEmpty ? '—' : auth.locationName),
                const SizedBox(height: 12),
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'Display name')),
                const SizedBox(height: 12),
                FilledButton(onPressed: _busy ? null : _saveName, child: const Text('Save name')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Change password', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('Kam se kam 8 character, number ya symbol ke saath.', style: TextStyle(color: BsnlColors.muted)),
                const SizedBox(height: 12),
                TextField(controller: _current, obscureText: true, decoration: const InputDecoration(labelText: 'Current password')),
                const SizedBox(height: 12),
                TextField(controller: _next, obscureText: true, decoration: const InputDecoration(labelText: 'New password')),
                const SizedBox(height: 12),
                FilledButton(onPressed: _busy ? null : _savePassword, child: const Text('Update password')),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _read(String label, String value) {
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
