import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../services/api_service.dart';
import '../state/auth_store.dart';

class RecordField {
  const RecordField(this.key, this.label, {this.keyboard = TextInputType.text});
  final String key;
  final String label;
  final TextInputType keyboard;
}

class RecordsPage extends StatefulWidget {
  const RecordsPage({
    super.key,
    required this.auth,
    required this.title,
    required this.path,
    required this.fields,
  });

  final AuthStore auth;
  final String title;
  final String path;
  final List<RecordField> fields;

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
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
      final rows = await widget.auth.api.listRows(widget.auth.apiBase, widget.path);
      setState(() => _rows = rows);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int? _idOf(Map<String, dynamic> row) {
    final v = row['id'] ?? row['rowIndex'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v');
  }

  Future<void> _save(Map<String, dynamic>? existing) async {
    if (!widget.auth.canWrite) return;
    final ctrls = {
      for (final f in widget.fields)
        f.key: TextEditingController(text: '${existing?[f.key] ?? ''}'),
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add' : 'Update'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final f in widget.fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: ctrls[f.key],
                      keyboardType: f.keyboard,
                      decoration: InputDecoration(labelText: f.label),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(existing == null ? 'Save' : 'Update')),
        ],
      ),
    );
    final body = {for (final f in widget.fields) f.key: ctrls[f.key]!.text.trim()};
    for (final c in ctrls.values) {
      c.dispose();
    }
    if (ok != true || !mounted) return;
    try {
      final id = existing == null ? null : _idOf(existing);
      if (existing == null) {
        await widget.auth.api.addRow(widget.auth.apiBase, widget.path, body);
      } else {
        if (id == null) throw ApiException('Entry id nahi mili');
        await widget.auth.api.updateRow(widget.auth.apiBase, widget.path, id, body);
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    if (!widget.auth.canWrite) return;
    final id = _idOf(row);
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete?'),
        content: Text('${row['name'] ?? id} delete ho jayegi.'),
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
    if (ok != true || !mounted) return;
    try {
      await widget.auth.api.deleteRow(widget.auth.apiBase, widget.path, id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = widget.auth.canWrite;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () => _save(null),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            )
          : null,
      body: Column(
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFEBEE),
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: TextStyle(color: Colors.red.shade900)),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty
                    ? const Center(child: Text('Koi entry nahi', style: TextStyle(color: BsnlColors.muted)))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(BsnlColors.navy),
                            headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            columns: [
                              const DataColumn(label: Text('#')),
                              for (final f in widget.fields) DataColumn(label: Text(f.label)),
                              if (canWrite) const DataColumn(label: Text('Actions')),
                            ],
                            rows: [
                              for (var i = 0; i < _rows.length; i++)
                                DataRow(
                                  cells: [
                                    DataCell(Text('${i + 1}')),
                                    for (final f in widget.fields)
                                      DataCell(Text('${_rows[i][f.key] ?? ''}')),
                                    if (canWrite)
                                      DataCell(
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit_outlined, color: BsnlColors.navy),
                                              onPressed: () => _save(_rows[i]),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Color(0xFFC62828)),
                                              onPressed: () => _delete(_rows[i]),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
