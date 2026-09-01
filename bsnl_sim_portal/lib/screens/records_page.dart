import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_theme.dart';
import '../services/api_service.dart';
import '../state/auth_store.dart';
import '../widgets/fade_in.dart';

enum RecordFieldKind { text, date }

class RecordField {
  const RecordField(
    this.key,
    this.label, {
    this.keyboard = TextInputType.text,
    this.kind = RecordFieldKind.text,
  });
  final String key;
  final String label;
  final TextInputType keyboard;
  final RecordFieldKind kind;
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
    final body = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _RecordEditor(
        title: existing == null ? 'Add' : 'Update',
        fields: widget.fields,
        initial: existing,
      ),
    );
    if (body == null || !mounted) return;
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
                    ? const Center(
                        child: FadeIn(
                          child: Text('Koi entry nahi', style: TextStyle(color: BsnlColors.muted)),
                        ),
                      )
                    : FadeIn(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                border: TableBorder.all(color: const Color(0xFF94A3B8), width: 1),
                                headingRowColor: WidgetStateProperty.all(BsnlColors.navy),
                                headingTextStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                                dataRowMinHeight: 48,
                                dataRowMaxHeight: 58,
                                columns: [
                                  const DataColumn(label: Text('S.No.'), numeric: true),
                                  for (final f in widget.fields) DataColumn(label: Text(f.label)),
                                  if (canWrite) const DataColumn(label: Text('Actions')),
                                ],
                                rows: [
                                  for (var i = 0; i < _rows.length; i++)
                                    DataRow(
                                      color: WidgetStateProperty.all(
                                        i.isEven ? Colors.white : const Color(0xFFF4F7FB),
                                      ),
                                      cells: [
                                        DataCell(
                                          Text(
                                            '${i + 1}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontFeatures: [FontFeature.tabularFigures()],
                                            ),
                                          ),
                                        ),
                                        for (final f in widget.fields)
                                          DataCell(_cellValue(_rows[i], f)),
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
                      ),
          ),
        ],
      ),
    );
  }

  Widget _cellValue(Map<String, dynamic> row, RecordField f) {
    final text = '${row[f.key] ?? ''}';
    if (f.key == 'status' && text.isNotEmpty) {
      final paid = text.toLowerCase().contains('paid') || text.toLowerCase() == 'done';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: paid ? BsnlColors.issued : const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
      );
    }
    return Text(text);
  }
}

class _RecordEditor extends StatefulWidget {
  const _RecordEditor({
    required this.title,
    required this.fields,
    this.initial,
  });
  final String title;
  final List<RecordField> fields;
  final Map<String, dynamic>? initial;

  @override
  State<_RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<_RecordEditor> {
  late final Map<String, TextEditingController> _ctrls;
  late final Map<String, DateTime> _dates;

  @override
  void initState() {
    super.initState();
    _ctrls = {
      for (final f in widget.fields)
        if (f.kind != RecordFieldKind.date)
          f.key: TextEditingController(text: '${widget.initial?[f.key] ?? ''}'),
    };
    _dates = {
      for (final f in widget.fields)
        if (f.kind == RecordFieldKind.date) f.key: parseRecordDate('${widget.initial?[f.key] ?? ''}'),
    };
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> _body() {
    return {
      for (final f in widget.fields)
        f.key: f.kind == RecordFieldKind.date
            ? DateFormat('dd/MM/yyyy').format(_dates[f.key]!)
            : _ctrls[f.key]!.text.trim(),
    };
  }

  Future<void> _pick(String key) async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dates[key] ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2032),
    );
    if (d != null) setState(() => _dates[key] = d);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final f in widget.fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: f.kind == RecordFieldKind.date
                      ? InkWell(
                          onTap: () => _pick(f.key),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: f.label,
                              suffixIcon: const Icon(Icons.calendar_month_outlined),
                            ),
                            child: Text(DateFormat('EEE, d MMM yyyy').format(_dates[f.key]!)),
                          ),
                        )
                      : TextField(
                          controller: _ctrls[f.key],
                          keyboardType: f.keyboard,
                          decoration: InputDecoration(labelText: f.label),
                        ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _body()),
          child: Text(widget.initial == null ? 'Save' : 'Update'),
        ),
      ],
    );
  }
}

DateTime parseRecordDate(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return DateTime.now();
  final iso = DateTime.tryParse(t);
  if (iso != null) return iso;
  final p = t.split(RegExp(r'[/-]'));
  if (p.length != 3) return DateTime.now();
  final a = int.tryParse(p[0].trim());
  final b = int.tryParse(p[1].trim());
  var y = int.tryParse(p[2].trim());
  if (a == null || b == null || y == null) return DateTime.now();
  if (y < 100) y += 2000;
  if (p[0].trim().length == 4) return DateTime(a, b, y);
  return DateTime(y, b, a);
}
