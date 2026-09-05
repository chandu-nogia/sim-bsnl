import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../state/sim_store.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.store, this.nested = false});
  final SimStore store;
  final bool nested;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _name;
  final _current = TextEditingController();
  final _next = TextEditingController();
  late final TextEditingController _url;
  final _cbpRate = TextEditingController(text: '1.00');
  final _topRate = TextEditingController(text: '1.00');
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.store.auth.name);
    _url = TextEditingController(text: widget.store.auth.apiUrl ?? widget.store.apiBase);
    _loadRates();
  }

  Future<void> _loadRates() async {
    try {
      final json = await widget.store.auth.api.appConfig(widget.store.auth.apiBase);
      if (!mounted) return;
      _cbpRate.text = '${json['cbpCommissionPercent'] ?? json['commissionPercent'] ?? 1}';
      _topRate.text = '${json['ctopupCommissionPercent'] ?? json['commissionPercent'] ?? 1}';
    } catch (_) {}
  }

  Future<void> _saveRates() async {
    setState(() => _busy = true);
    try {
      await widget.store.auth.api.saveCommissionRates(
        widget.store.auth.apiBase,
        cbpRate: num.tryParse(_cbpRate.text.trim()) ?? 1,
        ctopupRate: num.tryParse(_topRate.text.trim()) ?? 1,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Commission rates saved')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _current.dispose();
    _next.dispose();
    _url.dispose();
    _cbpRate.dispose();
    _topRate.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    setState(() => _busy = true);
    try {
      await widget.store.auth.api.updateProfile(widget.store.auth.apiBase, _name.text.trim());
      await widget.store.auth.loadSaved();
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
      await widget.store.auth.api.changePassword(widget.store.auth.apiBase, _current.text, _next.text);
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
    final auth = widget.store.auth;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        const Text('Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: BsnlColors.navyDark)),
        const SizedBox(height: 6),
        const Text('Personal BSNL Khatushyamji account', style: TextStyle(color: BsnlColors.muted)),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('My Profile', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 12),
                Text('Email: ${auth.email ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Location: Khatushyamji', style: TextStyle(fontWeight: FontWeight.w700)),
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
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Commission rates', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('CBP aur CTOPUP alag rates. Code change ki zaroorat nahi.', style: TextStyle(color: BsnlColors.muted)),
                const SizedBox(height: 12),
                TextField(
                  controller: _cbpRate,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'CBP commission %', suffixText: '%'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _topRate,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'CTOPUP commission %', suffixText: '%'),
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: _busy ? null : _saveRates, child: const Text('Save rates')),
              ],
            ),
          ),
        ),
        if (!kReleaseMode) ...[
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('API URL (dev)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(controller: _url, decoration: const InputDecoration(labelText: 'API URL')),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      await widget.store.saveApiUrl(_url.text);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB91C1C)),
          onPressed: () async {
            await auth.api.logoutAudit(auth.apiBase);
            await auth.logout();
          },
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
        ),
      ],
    );
  }
}
