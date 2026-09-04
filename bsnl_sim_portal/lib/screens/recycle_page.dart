import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../state/auth_store.dart';

class RecyclePage extends StatefulWidget {
  const RecyclePage({super.key, required this.auth});
  final AuthStore auth;

  @override
  State<RecyclePage> createState() => _RecyclePageState();
}

class _RecyclePageState extends State<RecyclePage> {
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
      final rows = await widget.auth.api.recycle(
        widget.auth.apiBase,
        locationId: widget.auth.isAdmin ? widget.auth.effectiveLocationId : null,
      );
      setState(() => _rows = rows);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore(Map<String, dynamic> row) async {
    try {
      await widget.auth.api.restoreRecycle(widget.auth.apiBase, '${row['type']}', int.parse('${row['id']}'));
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restored')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _purge(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permanent delete?'),
        content: const Text('This cannot be undone. Audit log will record the delete.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.auth.api.purgeRecycle(widget.auth.apiBase, '${row['type']}', int.parse('${row['id']}'));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Recycle Bin', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: BsnlColors.navyDark)),
        const SizedBox(height: 6),
        const Text('Last 30 days ki deleted entries. Restore karo to wapas aa jayengi.', style: TextStyle(color: BsnlColors.muted)),
        const SizedBox(height: 16),
        if (_rows.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('Recycle bin empty hai.')))
        else
          for (final r in _rows)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text('${r['name'] ?? ''}  ·  ${r['type']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${r['locationName'] ?? ''}  ·  ${r['deletedAt'] ?? ''}'),
                trailing: Wrap(
                  children: [
                    TextButton(onPressed: () => _restore(r), child: const Text('Restore')),
                    if (widget.auth.isAdmin)
                      TextButton(
                        onPressed: () => _purge(r),
                        child: const Text('Delete forever'),
                      ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
