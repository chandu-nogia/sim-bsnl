import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../state/auth_store.dart';
import '../util/format.dart';
import 'dashboard_page.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key, required this.auth});
  final AuthStore auth;

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _locations = [];
  int _page = 1;
  int _total = 0;
  final _q = TextEditingController();
  String? _action;
  int? _locationId;
  String? _from;
  String? _to;
  String? _employee;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    try {
      _locations = await widget.auth.api.listLocations(widget.auth.apiBase);
    } catch (_) {}
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final json = await widget.auth.api.activityPage(
        widget.auth.apiBase,
        locationId: _locationId,
        employee: _employee,
        action: _action,
        q: _q.text.trim(),
        from: _from,
        to: _to,
        page: _page,
        limit: 40,
      );
      setState(() {
        _rows = asMaps(json['rows']);
        _total = asInt(json['total']) ?? _rows.length;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate({required bool from}) async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2032),
    );
    if (d == null) return;
    final v = d.toIso8601String().sliceDate;
    setState(() {
      if (from) {
        _from = v;
      } else {
        _to = v;
      }
      _page = 1;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final pages = (_total / 40).ceil().clamp(1, 999);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _q,
                  decoration: const InputDecoration(labelText: 'Search', prefixIcon: Icon(Icons.search)),
                  onSubmitted: (_) {
                    _page = 1;
                    _load();
                  },
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<int?>(
                  // ignore: deprecated_member_use
                  value: _locationId,
                  decoration: const InputDecoration(labelText: 'Location'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    for (final l in _locations)
                      DropdownMenuItem(value: asInt(l['id']), child: Text('${l['name']}')),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _locationId = v;
                      _page = 1;
                    });
                    _load();
                  },
                ),
              ),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String?>(
                  // ignore: deprecated_member_use
                  value: _action,
                  decoration: const InputDecoration(labelText: 'Action'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All')),
                    DropdownMenuItem(value: 'login', child: Text('Login')),
                    DropdownMenuItem(value: 'add', child: Text('Add')),
                    DropdownMenuItem(value: 'update', child: Text('Update')),
                    DropdownMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _action = v;
                      _page = 1;
                    });
                    _load();
                  },
                ),
              ),
              SizedBox(
                width: 180,
                child: TextField(
                  decoration: const InputDecoration(labelText: 'Employee email'),
                  onSubmitted: (v) {
                    _employee = v.trim().isEmpty ? null : v.trim();
                    _page = 1;
                    _load();
                  },
                ),
              ),
              TextButton(onPressed: () => _pickDate(from: true), child: Text(_from == null ? 'From' : 'From $_from')),
              TextButton(onPressed: () => _pickDate(from: false), child: Text(_to == null ? 'To' : 'To $_to')),
              FilledButton(onPressed: _load, child: const Text('Apply')),
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
                  ? const Center(child: Text('No activity', style: TextStyle(color: BsnlColors.muted)))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      children: [for (final a in _rows) ActivityTile(row: a)],
                    ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Text('$_total records  •  page $_page / $pages'),
              const Spacer(),
              IconButton(
                onPressed: _page <= 1
                    ? null
                    : () {
                        setState(() => _page -= 1);
                        _load();
                      },
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                onPressed: _page >= pages
                    ? null
                    : () {
                        setState(() => _page += 1);
                        _load();
                      },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

extension on String {
  String get sliceDate => length >= 10 ? substring(0, 10) : this;
}
