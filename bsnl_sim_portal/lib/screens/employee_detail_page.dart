import 'package:flutter/material.dart';

import '../state/auth_store.dart';
import '../widgets/kpi_card.dart';

class EmployeeDetailPage extends StatefulWidget {
  const EmployeeDetailPage({super.key, required this.auth, required this.id});
  final AuthStore auth;
  final String id;

  @override
  State<EmployeeDetailPage> createState() => _EmployeeDetailPageState();
}

class _EmployeeDetailPageState extends State<EmployeeDetailPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _emp = {};
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _activity = [];

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
      final json = await widget.auth.api.employeeDetail(widget.auth.apiBase, widget.id);
      setState(() {
        _emp = json['employee'] is Map ? Map<String, dynamic>.from(json['employee'] as Map) : {};
        _summary = json['summary'] is Map ? Map<String, dynamic>.from(json['summary'] as Map) : {};
        _activity = [
          for (final r in (json['activity'] as List? ?? []))
            if (r is Map) Map<String, dynamic>.from(r),
        ];
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${_emp['name'] ?? 'Employee'}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_emp['name']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            Text('${_emp['email']}  ·  ID ${_emp['id'] ?? '—'}'),
                            Text('Location: ${_emp['locationName'] ?? '—'}'),
                            Text('Role: ${_emp['role']}  ·  ${_emp['status']}'),
                            Text('Last login: ${_emp['lastLogin'] ?? '—'}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Modules', style: TextStyle(fontWeight: FontWeight.w800)),
                    const Text('BSNL Portal, CBC, C-TopUp  ·  View / Create / Edit. Delete goes to recycle bin.'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(width: 160, child: KpiCard(label: 'Portal', value: '${_summary['sims'] ?? 0}', icon: Icons.sim_card_outlined)),
                        SizedBox(width: 160, child: KpiCard(label: 'CBC', value: '${_summary['cbc'] ?? 0}', icon: Icons.receipt_long_outlined)),
                        SizedBox(width: 160, child: KpiCard(label: 'C-TopUp', value: '${_summary['ctopup'] ?? 0}', icon: Icons.payments_outlined)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Recent activity', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 8),
                    if (_activity.isEmpty)
                      const EmptyState(message: 'No activity yet.')
                    else
                      for (final a in _activity)
                        ListTile(
                          dense: true,
                          title: Text('${a['detail'] ?? ''}'),
                          subtitle: Text('${a['at'] ?? ''}  ·  ${a['action'] ?? ''}'),
                        ),
                  ],
                ),
    );
  }
}
