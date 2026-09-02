import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../services/excel_export.dart';
import '../state/auth_store.dart';
import '../util/format.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, required this.auth});
  final AuthStore auth;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String _type = 'location';
  String? _from;
  String? _to;
  int? _locationId;
  String? _employee;
  bool _loading = false;
  String? _error;
  String _title = 'Reports';
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _locations = [];

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      _locations = await widget.auth.api.listLocations(widget.auth.apiBase);
      setState(() {});
    } catch (_) {}
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final json = await widget.auth.api.reports(
        widget.auth.apiBase,
        type: _type,
        from: _from,
        to: _to,
        locationId: _locationId,
        employee: _employee,
      );
      setState(() {
        _title = '${json['title'] ?? 'Report'}';
        _rows = asMaps(json['rows']);
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick({required bool from}) async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2032),
    );
    if (d == null) return;
    setState(() {
      final v = d.toIso8601String().substring(0, 10);
      if (from) {
        _from = v;
      } else {
        _to = v;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
                width: 200,
                child: DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: _type,
                  decoration: const InputDecoration(labelText: 'Report'),
                  items: const [
                    DropdownMenuItem(value: 'location', child: Text('Location-wise')),
                    DropdownMenuItem(value: 'employee', child: Text('Employee-wise')),
                    DropdownMenuItem(value: 'cbc', child: Text('CBC amount')),
                    DropdownMenuItem(value: 'ctopup', child: Text('C-TopUp amount')),
                    DropdownMenuItem(value: 'users', child: Text('New users')),
                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    DropdownMenuItem(value: 'activity', child: Text('Activity')),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? 'location'),
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
                  onChanged: (v) => setState(() => _locationId = v),
                ),
              ),
              SizedBox(
                width: 180,
                child: TextField(
                  decoration: const InputDecoration(labelText: 'Employee email'),
                  onChanged: (v) => _employee = v.trim().isEmpty ? null : v.trim(),
                ),
              ),
              TextButton(onPressed: () => _pick(from: true), child: Text(_from == null ? 'From date' : 'From $_from')),
              TextButton(onPressed: () => _pick(from: false), child: Text(_to == null ? 'To date' : 'To $_to')),
              FilledButton.icon(onPressed: _loading ? null : _run, icon: const Icon(Icons.play_arrow), label: const Text('Run')),
              OutlinedButton.icon(
                onPressed: _rows.isEmpty ? null : () => downloadMapExcel(context, _title, _rows),
                icon: const Icon(Icons.table_view_outlined),
                label: const Text('Export Excel'),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_error!, style: TextStyle(color: Colors.red.shade800)),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(_title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: BsnlColors.navyDark)),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _rows.isEmpty
                  ? const Center(child: Text('No rows', style: TextStyle(color: BsnlColors.muted)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(BsnlColors.navy),
                            headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            columns: [
                              for (final k in _rows.first.keys) DataColumn(label: Text('$k')),
                            ],
                            rows: [
                              for (final row in _rows)
                                DataRow(
                                  cells: [
                                    for (final k in _rows.first.keys) DataCell(Text('${row[k] ?? ''}')),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}
