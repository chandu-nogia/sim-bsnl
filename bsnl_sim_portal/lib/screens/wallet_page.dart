import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_theme.dart';
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
  Timer? _debounce;
  int _page = 1;
  int _limit = 50;
  int _total = 0;
  String _service = 'cbp';
  String _tab = 'ledger';
  String _type = 'All';
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
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final from = _from == null ? null : DateFormat('yyyy-MM-dd').format(_from!);
      final to = _to == null ? null : DateFormat('yyyy-MM-dd').format(_to!);
      final out = _tab == 'commission'
          ? await widget.auth.api.serviceCommission(
              widget.auth.apiBase,
              _service,
              q: _search.text.trim(),
              from: from,
              to: to,
              page: _page,
              limit: _limit,
            )
          : await widget.auth.api.serviceLedger(
              widget.auth.apiBase,
              _service,
              q: _search.text.trim(),
              from: from,
              to: to,
              txnType: _type == 'All' ? null : _type,
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
        _commission = out.totalCommission;
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

  Future<void> _money({required bool withdraw}) async {
    final body = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _WalletForm(withdraw: withdraw, service: _service),
    );
    if (body == null || !mounted) return;
    try {
      if (withdraw) {
        await widget.auth.api.withdrawServiceMoney(widget.auth.apiBase, _service, body['amount'] ?? '', reason: body['remark'] ?? '');
      } else {
        await widget.auth.api.addServiceMoney(widget.auth.apiBase, _service, body['amount'] ?? '', remark: body['remark'] ?? '');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(withdraw ? 'Amount withdraw ho gaya' : 'Amount add ho gaya')));
      }
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _details(Map<String, dynamic> row) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${row['txnId'] ?? row['relatedTransactionId'] ?? 'Ledger'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type  ${row['type'] ?? row['transactionType'] ?? ''}'),
            Text('Source  ${row['source'] ?? row['serviceType'] ?? ''}'),
            Text('Amount  ${rupee(asNum(row['amount'] ?? row['rechargeAmount']))}'),
            Text('Commission  ${rupee(asNum(row['commission']))}'),
            Text('Net impact  ${rupee(asNum(row['netImpact']))}'),
            Text('Previous  ${rupee(asNum(row['previousBalance'] ?? row['balanceBefore']))}'),
            Text('Current balance  ${rupee(asNum(row['newBalance'] ?? row['balanceAfter'] ?? row['actualBalance']))}'),
            Text('Reference  ${row['referenceId'] ?? row['relatedTransactionId'] ?? '—'}'),
            Text('Reason  ${row['description'] ?? row['remark'] ?? '—'}'),
            Text('Created by  ${row['createdBy'] ?? ''}'),
            Text('Date  ${row['date'] ?? row['createdAt'] ?? ''}'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = _service == 'ctopup' ? 'CTOPUP' : 'CBP';
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.nested,
        title: Text('$label Wallet'),
        actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: widget.auth.canWrite
          ? FloatingActionButton.extended(
              onPressed: () => _money(withdraw: false),
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
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'cbp', label: Text('CBP'), icon: Icon(Icons.receipt_long_outlined)),
                ButtonSegment(value: 'ctopup', label: Text('CTOPUP'), icon: Icon(Icons.payments_outlined)),
              ],
              selected: {_service},
              onSelectionChanged: (v) {
                setState(() {
                  _service = v.first;
                  _page = 1;
                });
                _load();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _Summary(
              added: _added,
              used: _used,
              commission: _commission,
              remaining: _remaining,
              service: label,
              onAdd: widget.auth.canWrite ? () => _money(withdraw: false) : null,
              onWithdraw: widget.auth.canWrite ? () => _money(withdraw: true) : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'ledger', label: Text('Wallet History')),
                    ButtonSegment(value: 'commission', label: Text('Commission History')),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (v) {
                    setState(() {
                      _tab = v.first;
                      _page = 1;
                    });
                    _load();
                  },
                ),
                SizedBox(
                  width: 240,
                  child: TextField(
                    controller: _search,
                    onChanged: _onSearch,
                    decoration: const InputDecoration(hintText: 'Search ID / mobile / reference', prefixIcon: Icon(Icons.search), isDense: true),
                  ),
                ),
                if (_tab == 'ledger')
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _type,
                      decoration: const InputDecoration(labelText: 'Type', isDense: true),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(value: 'CREDIT', child: Text('Credit')),
                        DropdownMenuItem(value: 'DEBIT', child: Text('Debit')),
                        DropdownMenuItem(value: 'USAGE', child: Text('Transaction')),
                        DropdownMenuItem(value: 'REVERSAL', child: Text('Reversal')),
                        DropdownMenuItem(value: 'COMMISSION', child: Text('Commission')),
                      ],
                      onChanged: (v) {
                        _type = v ?? 'All';
                        _page = 1;
                        _load();
                      },
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
                Text(_total == 0 ? '0 rows' : '$_total entries', style: const TextStyle(color: BsnlColors.muted, fontWeight: FontWeight.w600)),
                IconButton(onPressed: _page <= 1 || _loading ? null : () { _page -= 1; _load(); }, icon: const Icon(Icons.chevron_left)),
                IconButton(onPressed: _loading || (_page * _limit) >= _total ? null : () { _page += 1; _load(); }, icon: const Icon(Icons.chevron_right)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty
                    ? Center(child: FadeIn(child: Text(_tab == 'commission' ? 'Abhi koi commission nahi.' : 'Abhi koi wallet entry nahi. + Add Amount dabao.', style: const TextStyle(color: BsnlColors.muted))))
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
                                columns: _tab == 'commission'
                                    ? const [
                                        DataColumn(label: Text('Date/Time')),
                                        DataColumn(label: Text('Service')),
                                        DataColumn(label: Text('Txn ID')),
                                        DataColumn(label: Text('Recharge'), numeric: true),
                                        DataColumn(label: Text('Previous'), numeric: true),
                                        DataColumn(label: Text('Expected'), numeric: true),
                                        DataColumn(label: Text('Actual'), numeric: true),
                                        DataColumn(label: Text('Commission'), numeric: true),
                                        DataColumn(label: Text('Status')),
                                      ]
                                    : const [
                                        DataColumn(label: Text('Date')),
                                        DataColumn(label: Text('Service')),
                                        DataColumn(label: Text('Type')),
                                        DataColumn(label: Text('Amount'), numeric: true),
                                        DataColumn(label: Text('Commission'), numeric: true),
                                        DataColumn(label: Text('Net Impact'), numeric: true),
                                        DataColumn(label: Text('Balance'), numeric: true),
                                        DataColumn(label: Text('Reference')),
                                        DataColumn(label: Text('View')),
                                      ],
                                rows: [
                                  for (var i = 0; i < _rows.length; i++)
                                    DataRow(
                                      color: WidgetStateProperty.all(i.isEven ? Colors.white : const Color(0xFFF4F7FB)),
                                      cells: _tab == 'commission' ? _commissionCells(_rows[i]) : _ledgerCells(_rows[i]),
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

  List<DataCell> _commissionCells(Map<String, dynamic> row) {
    return [
      DataCell(Text('${row['createdAt'] ?? row['date'] ?? ''}')),
      DataCell(Text('${row['service'] ?? row['serviceType'] ?? _service.toUpperCase()}')),
      DataCell(Text('${row['relatedTransactionId'] ?? row['txnId'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800))),
      DataCell(Text(rupee(asNum(row['rechargeAmount'] ?? row['amount'])))),
      DataCell(Text(rupee(asNum(row['previousBalance'])))),
      DataCell(Text(rupee(asNum(row['expectedBalance'])))),
      DataCell(Text(rupee(asNum(row['actualBalance'] ?? row['newBalance'])))),
      DataCell(Text(rupee(asNum(row['commission'])), style: const TextStyle(fontWeight: FontWeight.w800))),
      DataCell(Text('${row['status'] ?? row['transactionType'] ?? ''}')),
    ];
  }

  List<DataCell> _ledgerCells(Map<String, dynamic> row) {
    final type = '${row['type'] ?? row['transactionType'] ?? ''}';
    return [
      DataCell(Text('${row['date'] ?? row['createdAt'] ?? ''}')),
      DataCell(Text('${row['service'] ?? row['serviceType'] ?? _service.toUpperCase()}')),
      DataCell(Text(type, style: const TextStyle(fontWeight: FontWeight.w800))),
      DataCell(Text(rupee(asNum(row['amount'])), style: const TextStyle(fontWeight: FontWeight.w800))),
      DataCell(Text(rupee(asNum(row['commission'])))),
      DataCell(Text(rupee(asNum(row['netImpact'])))),
      DataCell(Text(rupee(asNum(row['newBalance'] ?? row['balanceAfter'])))),
      DataCell(Text('${row['referenceId'] ?? row['relatedTransactionId'] ?? row['txnId'] ?? ''}')),
      DataCell(IconButton(tooltip: 'View', icon: const Icon(Icons.visibility_outlined), onPressed: () => _details(row))),
    ];
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.added,
    required this.used,
    required this.commission,
    required this.remaining,
    required this.service,
    this.onAdd,
    this.onWithdraw,
  });
  final num added;
  final num used;
  final num commission;
  final num remaining;
  final String service;
  final VoidCallback? onAdd;
  final VoidCallback? onWithdraw;

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
          card('Current Wallet Balance', rupee(remaining), const [Color(0xFF0F766E), Color(0xFF14B8A6)]),
          card('Total Added', rupee(added), const [Color(0xFF0B3D91), Color(0xFF3B82F6)]),
          card('Total Used', rupee(used), const [Color(0xFF0E7490), Color(0xFF06B6D4)]),
          card('Total Commission Earned', rupee(commission), const [Color(0xFFB45309), Color(0xFFF59E0B)]),
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
        if (onAdd != null || onWithdraw != null) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              if (onAdd != null) FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add Amount')),
              if (onWithdraw != null) OutlinedButton.icon(onPressed: onWithdraw, icon: const Icon(Icons.remove), label: const Text('Withdraw')),
            ],
          ),
        ],
      ],
    );
  }
}

class _WalletForm extends StatefulWidget {
  const _WalletForm({required this.withdraw, required this.service});
  final bool withdraw;
  final String service;

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
    _amount = TextEditingController();
    _remark = TextEditingController();
    _date = DateTime.now();
  }

  @override
  void dispose() {
    _amount.dispose();
    _remark.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.service == 'ctopup' ? 'CTOPUP' : 'CBP';
    return AlertDialog(
      title: Text(widget.withdraw ? 'Withdraw $label amount' : 'Add $label amount'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.withdraw)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final n in const [500, 1000, 5000, 10000])
                    ActionChip(
                      label: Text('+₹$n'),
                      onPressed: () => setState(() => _amount.text = '$n'),
                    ),
                ],
              ),
            if (!widget.withdraw) const SizedBox(height: 12),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Custom amount', prefixText: '₹ '),
            ),
            const SizedBox(height: 12),
            TextField(controller: _remark, decoration: InputDecoration(labelText: widget.withdraw ? 'Reason' : 'Remark / source')),
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
          child: Text(widget.withdraw ? 'Withdraw' : 'Add'),
        ),
      ],
    );
  }
}
