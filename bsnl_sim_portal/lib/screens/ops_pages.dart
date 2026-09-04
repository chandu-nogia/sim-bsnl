import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../state/auth_store.dart';
import '../widgets/kpi_card.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, required this.auth});
  final AuthStore auth;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

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
      _rows = await widget.auth.api.notifications(widget.auth.apiBase);
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_rows.isEmpty) return const EmptyState(message: 'No alerts right now.');
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Notifications', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: BsnlColors.navyDark)),
        const SizedBox(height: 6),
        const Text('Only items that need attention.', style: TextStyle(color: BsnlColors.muted)),
        const SizedBox(height: 16),
        for (final r in _rows)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                '${r['tone']}' == 'danger' ? Icons.error_outline : Icons.info_outline,
                color: '${r['tone']}' == 'danger' ? BsnlColors.saffron : BsnlColors.navy,
              ),
              title: Text('${r['title'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
      ],
    );
  }
}

class HealthPage extends StatefulWidget {
  const HealthPage({super.key, required this.auth});
  final AuthStore auth;

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
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
      _data = await widget.auth.api.system(widget.auth.apiBase);
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    final counts = _data['counts'] is Map ? Map<String, dynamic>.from(_data['counts'] as Map) : <String, dynamic>{};
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('System Health', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: BsnlColors.navyDark)),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            title: Text('MongoDB  ${_data['mongo'] ?? ''}'),
            subtitle: Text('Ping ${_data['pingMs'] ?? '—'} ms  ·  API ${_data['version'] ?? ''}'),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            title: const Text('Live counts'),
            subtitle: Text(
              'Users ${counts['users'] ?? 0}  ·  Locations ${counts['locations'] ?? 0}  ·  Portal ${counts['sims'] ?? 0}  ·  CBC ${counts['cbc'] ?? 0}  ·  C-TopUp ${counts['ctopup'] ?? 0}',
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(child: ListTile(title: const Text('Last activity'), subtitle: Text('${_data['lastActivity'] ?? '—'}'))),
      ],
    );
  }
}
