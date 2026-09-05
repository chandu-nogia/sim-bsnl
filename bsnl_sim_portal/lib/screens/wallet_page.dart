import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_theme.dart';
import '../services/api_service.dart';
import '../state/auth_store.dart';
import '../util/format.dart';
import '../widgets/fade_in.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key, required this.auth, this.nested = false});
  final AuthStore auth;
  final bool nested;

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  final _search = TextEditingController();
  final _min = TextEditingController();
  final _max = TextEditingController();
  Timer? _debounce;
  int _page = 1;
  int _limit = 50;
  int _total = 0;
  String _type = 'CREDIT';
  final String _sort = 'date';
  final String _order = 'desc';
  DateTime? _from;
  DateTime? _to;
  num _added = 0;
  num _used = 0;
  num _commission = 0;
  num _remaining = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final out = await widget.auth.api.listPage(
        widget.auth.apiBase,
        '/api/wallet/transactions',
        q: _search.text.trim(),
        from: _from == null ? null : DateFormat('yyyy-MM-dd').format(_from!),
        to: _to == null ? null : DateFormat('yyyy-MM-dd').format(_to!),
        txnType: _type == 'All' ? null : _type,
        minAmount: _min.text.trim().isEmpty ? null : _min.text.trim(),
        maxAmount: _max.text.trim().isEmpty ? null : _max.text.trim(),
        sort: _sort,
        order: _order,
        page: _page,
        limit: _limit,
      );
      setState(() {
        _rows = out.rows;
        _total = out.total;
        _page = out.page;
        _limit = out.limit == 0 ? _limit : out.limit;
        _added = out.totalAdded;
        _used = out.totalUsed;
        _commission = out.combinedCommission;
        _remaining = out.remainingBalance;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      _page = 1;
      _load();
    });
  }

  int? _idOf(Map<String, dynamic> row) => asInt(row['id'] ?? row['rowIndex']);

  Future<void> _save(Map<String, dynamic>? existing) async {
    final body = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _WalletForm(initial: existing),
    );
    if (body == null || !mounted) return;
    try {
      if (existing == null) {
        await widget.auth.api.saveWallet(widget.auth.apiBase, body['amount'] ?? '', remark: body['remark'] ?? '');
      } else {
        final id = _idOf(existing);
        if (id == null) throw ApiException('Transaction id nahi mili');
        await widget.auth.api.updateRow(widget.auth.apiBase, '/api/wallet/transactions', id, body);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(existing == null ? 'Amount add ho gaya' : 'Transaction update ho gayi')));
      }
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final id = _idOf(row);
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete wallet transaction?'),
        content: Text('Delete ${row['txnId'] ?? id} of ${rupee(asNum(row['amount']))}? Balance auto recalculate hoga. Agar CBP/CTOPUP is amount ko use kar chuke hain to delete nahi hoga.'),
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
      await widget.auth.api.deleteRow(widget.auth.apiBase, '/api/wallet/transactions', id);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _details(Map<String, dynamic> row) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${row['txnId'] ?? 'Wallet'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount  ${rupee(asNum(row['amount']))}', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Type  ${row['transactionType'] ?? 'CREDIT'}'),
            Text('Date  ${row['date'] ?? ''}'),
            Text('Remark  ${row['remark'] ?? row['note'] ?? '—'}'),
            Text('Created by  ${row['createdBy'] ?? ''}'),
            Text('Created  ${row['createdAt'] ?? ''}'),
            Text('Updated  ${row['updatedAt'] ?? ''}'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.nested,
        title: const Text('Wallet'),
        actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: widget.auth.canWrite
          ? FloatingActionButton.extended(
              onPressed: () => _save(null),
              icon: const Icon(Icons.add),
              label: const Text('Add Amount'),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _Summary(
              added: _added,
              used: _used,
              commission: _commission,
              remaining: _remaining,
              onAdd: widget.auth.canWrite ? () => _save(null) : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 240,
                  child: TextField(
                    controller: _search,
                    onChanged: _onSearch,
                    decoration: const InputDecoration(hintText: 'Search ID / remark', prefixIcon: Icon(Icons.search), isDense: true),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: _type,
                    decoration: const InputDecoration(labelText: 'Type', isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All')),
                      DropdownMenuItem(value: 'CREDIT', child: Text('Credit')),
                    ],
                    onChanged: (v) {
                      _type = v ?? 'CREDIT';
                      _page = 1;
                      _load();
                    },
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _min,
                    onSubmitted: (_) { _page = 1; _load(); },
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Min amount', isDense: true),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _max,
                    onSubmitted: (_) { _page = 1; _load(); },
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Max amount', isDense: true),
                  ),
                ),
                InputChip(
                  label: Text(_from == null ? 'From' : 'From ${DateFormat('dd/MM/yyyy').format(_from!)}'),
                  onPressed: () async {
                    final d = await showDatePicker(context: context, initialDate: _from ?? DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2035));
                    if (d == null) return;
                    setState(() { _from = d; _page = 1; });
                    _load();
                  },
                  onDeleted: _from == null ? null : () { setState(() { _from = null; _page = 1; }); _load(); },
                ),
                InputChip(
                  label: Text(_to == null ? 'To' : 'To ${DateFormat('dd/MM/yyyy').format(_to!)}'),
                  onPressed: () async {
                    final d = await showDatePicker(context: context, initialDate: _to ?? DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2035));
                    if (d == null) return;
                    setState(() { _to = d; _page = 1; });
                    _load();
                  },
                  onDeleted: _to == null ? null : () { setState(() { _to = null; _page = 1; }); _load(); },
                ),
                Text(_total == 0 ? '0 rows' : '$_total credits', style: const TextStyle(color: BsnlColors.muted, fontWeight: FontWeight.w600)),
                IconButton(onPressed: _page <= 1 || _loading ? null : () { _page -= 1; _load(); }, icon: const Icon(Icons.chevron_left)),
                IconButton(onPressed: _loading || (_page * _limit) >= _total ? null : () { _page += 1; _load(); }, icon: const Icon(Icons.chevron_right)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty
                    ? const Center(child: FadeIn(child: Text('Abhi koi wallet credit nahi. + Add Amount dabao.', style: TextStyle(color: BsnlColors.muted))))
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
                                headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                columns: const [
                                  DataColumn(label: Text('Txn ID')),
                                  DataColumn(label: Text('Date')),
                                  DataColumn(label: Text('Type')),
                                  DataColumn(label: Text('Amount'), numeric: true),
                                  DataColumn(label: Text('Remark')),
                                  DataColumn(label: Text('Created by')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: [
                                  for (var i = 0; i < _rows.length; i++)
                                    DataRow(
                                      color: WidgetStateProperty.all(i.isEven ? Colors.white : const Color(0xFFF4F7FB)),
                                      cells: [
                                        DataCell(Text('${_rows[i]['txnId'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800))),
                                        DataCell(Text('${_rows[i]['date'] ?? ''}')),
                                        DataCell(Text('${_rows[i]['transactionType'] ?? 'CREDIT'}')),
                                        DataCell(Text(rupee(asNum(_rows[i]['amount'])), style: const TextStyle(fontWeight: FontWeight.w800))),
                                        DataCell(Text('${_rows[i]['remark'] ?? _rows[i]['note'] ?? ''}')),
                                        DataCell(Text('${_rows[i]['createdBy'] ?? ''}')),
                                        DataCell(Row(
                                          children: [
                                            IconButton(tooltip: 'View', icon: const Icon(Icons.visibility_outlined), onPressed: () => _details(_rows[i])),
                                            if (widget.auth.canWrite) ...[
                                              IconButton(icon: const Icon(Icons.edit_outlined, color: BsnlColors.navy), onPressed: () => _save(_rows[i])),
                                              IconButton(icon: const Icon(Icons.delete_outline, color: Color(0xFFC62828)), onPressed: () => _delete(_rows[i])),
                                            ],
                                          ],
                                        )),
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
}

class _Summary extends StatelessWidget {
  const _Summary({required this.added, required this.used, required this.commission, required this.remaining, this.onAdd});
  final num added;
  final num used;
  final num commission;
  final num remaining;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    Widget card(String title, String value, List<Color> colors) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
        ),
      );
    }

    final row = LayoutBuilder(
      builder: (context, box) {
        final cards = [
          card('Total Added', rupee(added), const [Color(0xFF0B3D91), Color(0xFF3B82F6)]),
          card('Total Used', rupee(used), const [Color(0xFF0E7490), Color(0xFF06B6D4)]),
          card('Total Commission', rupee(commission), const [Color(0xFFB45309), Color(0xFFF59E0B)]),
          card('Current Balance', rupee(remaining), const [Color(0xFF0F766E), Color(0xFF14B8A6)]),
        ];
        if (box.maxWidth < 720) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i += 2)
                Padding(
                  padding: EdgeInsets.only(bottom: i + 2 < cards.length ? 8 : 0),
                  child: Row(children: [cards[i], const SizedBox(width: 8), if (i + 1 < cards.length) cards[i + 1]]),
                ),
            ],
          );
        }
        return Row(children: [for (var i = 0; i < cards.length; i++) ...[cards[i], if (i < 3) const SizedBox(width: 8)]]);
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        if (onAdd != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add Amount')),
          ),
        ],
      ],
    );
  }
}

class _WalletForm extends StatefulWidget {
  const _WalletForm({this.initial});
  final Map<String, dynamic>? initial;

  @override
  State<_WalletForm> createState() => _WalletFormState();
}

class _WalletFormState extends State<_WalletForm> {
  late final TextEditingController _amount;
  late final TextEditingController _remark;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: widget.initial == null ? '' : '${widget.initial?['amount'] ?? ''}');
    _remark = TextEditingController(text: '${widget.initial?['remark'] ?? widget.initial?['note'] ?? ''}');
    final raw = '${widget.initial?['date'] ?? ''}';
    _date = raw.isEmpty ? DateTime.now() : (DateTime.tryParse(raw) ?? DateTime.now());
  }

  @override
  void dispose() {
    _amount.dispose();
    _remark.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final add = widget.initial == null;
    return AlertDialog(
      title: Text(add ? 'Add wallet amount' : 'Edit wallet amount'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
            ),
            const SizedBox(height: 12),
            TextField(controller: _remark, decoration: const InputDecoration(labelText: 'Remark / note')),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Date  ${DateFormat('dd/MM/yyyy').format(_date)}'),
              trailing: const Icon(Icons.calendar_month_outlined),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2024), lastDate: DateTime(2035));
                if (d != null) setState(() => _date = d);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            'amount': _amount.text.trim(),
            'remark': _remark.text.trim(),
            'date': DateFormat('yyyy-MM-dd').format(_date),
          }),
          child: Text(add ? 'Add' : 'Update'),
        ),
      ],
    );
  }
}
