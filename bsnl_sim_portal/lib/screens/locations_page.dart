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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(active ? 'Deactivate location?' : 'Activate location?'),
        content: Text(
          active
              ? '${row['name']} inactive ho jayegi. BSNL / CBC / C-TopUp records safe rehte hain.'
              : '${row['name']} dubara active ho jayegi.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(active ? 'Deactivate' : 'Activate')),
        ],
      ),
    );
    if (ok != true) return;
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
          SnackBar(content: Text(active ? 'Location deactivated — records safe' : 'Location activated')),
        );
      }
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
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: off
                                  ? Colors.grey
                                  : [
                                      const Color(0xFF0B3D91),
                                      const Color(0xFF0E7490),
                                      const Color(0xFF7C3AED),
                                      const Color(0xFFEA580C),
                                    ][i % 4],
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
