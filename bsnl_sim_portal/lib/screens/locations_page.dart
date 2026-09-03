import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../state/auth_store.dart';
import '../util/format.dart';
import '../widgets/fade_in.dart';
import 'location_form_page.dart';

class LocationsPage extends StatefulWidget {
  const LocationsPage({super.key, required this.auth, this.onChanged});
  final AuthStore auth;
  final VoidCallback? onChanged;

  @override
  State<LocationsPage> createState() => _LocationsPageState();
}

class _LocationsPageState extends State<LocationsPage> {
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
      final rows = await widget.auth.api.listLocations(widget.auth.apiBase);
      setState(() => _rows = rows);
      widget.onChanged?.call();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(Map<String, dynamic>? existing) async {
    final ok = await Navigator.of(context).push<bool>(
      fadeRoute(LocationFormPage(auth: widget.auth, existing: existing)),
    );
    if (ok == true) _load();
  }

  Future<void> _deactivate(Map<String, dynamic> row) async {
    final id = asInt(row['id']);
    if (id == null) return;
    final active = '${row['status']}' != 'inactive';
    try {
      await widget.auth.api.updateLocation(
        widget.auth.apiBase,
        id,
        name: '${row['name'] ?? ''}',
        code: '${row['code'] ?? ''}',
        address: '${row['address'] ?? ''}',
        status: active ? 'inactive' : 'active',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(active ? 'Location deactivated' : 'Location activated')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final id = asInt(row['id']);
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete location?'),
        content: Text('${row['name']} delete ho jayegi. Records rehte hain.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.auth.api.deleteLocation(widget.auth.apiBase, id);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Har jagah ke apne 3 portals: BSNL Portal, CBC, C-TopUp. Form se nayi jagah add karo.',
                  style: TextStyle(color: BsnlColors.muted, fontWeight: FontWeight.w600),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _edit(null),
                icon: const Icon(Icons.add),
                label: const Text('Add location'),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_error!, style: TextStyle(color: Colors.red.shade800)),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _rows.isEmpty
                  ? const Center(child: Text('No locations yet', style: TextStyle(color: BsnlColors.muted)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _rows.length,
                      itemBuilder: (context, i) {
                        final row = _rows[i];
                        final off = '${row['status']}' == 'inactive';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: off ? Colors.grey : BsnlColors.navy,
                              foregroundColor: Colors.white,
                              child: Text(
                                () {
                                  final code = '${row['code'] ?? row['name'] ?? 'L'}'.trim();
                                  if (code.isEmpty) return 'L';
                                  return code.substring(0, code.length >= 2 ? 2 : 1).toUpperCase();
                                }(),
                              ),
                            ),
                            title: Text('${row['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text(
                              '${row['code'] ?? ''}  •  ${row['address'] ?? ''}\n${off ? 'Inactive' : 'Active'}  •  ${row['createdAt'] ?? ''}',
                            ),
                            isThreeLine: true,
                            trailing: Wrap(
                              children: [
                                IconButton(onPressed: () => _edit(row), icon: const Icon(Icons.edit_outlined)),
                                IconButton(
                                  tooltip: off ? 'Activate' : 'Deactivate',
                                  onPressed: () => _deactivate(row),
                                  icon: Icon(off ? Icons.toggle_off_outlined : Icons.toggle_on_outlined),
                                ),
                                IconButton(
                                  onPressed: () => _delete(row),
                                  icon: const Icon(Icons.delete_outline, color: Color(0xFFC62828)),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
