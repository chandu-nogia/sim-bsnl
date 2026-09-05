import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_theme.dart';
import '../services/api_service.dart';
import '../services/pdf_export.dart';
import '../state/auth_store.dart';
import '../util/format.dart';
import '../widgets/fade_in.dart';

enum RecordFieldKind { text, date, choice, computed, commission, actualBalance }

class RecordField {
  const RecordField(
    this.key,
    this.label, {
    this.keyboard = TextInputType.text,
    this.kind = RecordFieldKind.text,
    this.options = const [],
  });
  final String key;
  final String label;
  final TextInputType keyboard;
  final RecordFieldKind kind;
  final List<String> options;
}

class RecordsPage extends StatefulWidget {
  const RecordsPage({
    super.key,
    required this.auth,
    required this.title,
    required this.path,
    required this.fields,
    this.locationId,
    this.locationName,
    this.nested = false,
    this.commissionModule,
  });

  final AuthStore auth;
  final String title;
  final String path;
  final List<RecordField> fields;
  final int? locationId;
  final String? locationName;
  final bool nested;
  final String? commissionModule;

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  final _search = TextEditingController();
  Timer? _debounce;
  int _page = 1;
  int _limit = 50;
  int _total = 0;
  String _status = 'All';
  String _type = 'All';
  String _sort = 'date';
  String _order = 'desc';
  DateTime? _from;
  DateTime? _to;
  num _wallet = 0;
  num _remaining = 0;
  num _used = 0;
  num _commission = 0;

  bool get _hasStatus {
    for (final f in widget.fields) {
      if (f.key == 'status' && f.kind == RecordFieldKind.choice) return true;
    }
    return false;
  }

  List<String> get _statusOptions {
    for (final f in widget.fields) {
      if (f.key == 'status') return f.options;
    }
    return const [];
  }

  bool get _hasType {
    for (final f in widget.fields) {
      if (f.key == 'type' && f.kind == RecordFieldKind.choice) return true;
    }
    return false;
  }

  List<String> get _typeOptions {
    for (final f in widget.fields) {
      if (f.key == 'type') return f.options;
    }
    return const [];
  }

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

  int? get _scopeLocationId => widget.auth.effectiveLocationId;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final loc = _scopeLocationId;
      final out = await widget.auth.api.listPage(
        widget.auth.apiBase,
        widget.path,
        locationId: loc,
        q: _search.text.trim(),
        from: _from == null ? null : DateFormat('yyyy-MM-dd').format(_from!),
        to: _to == null ? null : DateFormat('yyyy-MM-dd').format(_to!),
        status: _status == 'All' ? null : _status,
        type: _type == 'All' ? null : _type,
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
        _wallet = out.totalAdded > 0 ? out.totalAdded : out.walletAmount;
        _remaining = out.remainingBalance;
        _used = out.totalUsed;
        _commission = out.totalCommission;
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

  int? _idOf(Map<String, dynamic> row) {
    final v = row['id'] ?? row['rowIndex'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v');
  }

  Future<void> _save(Map<String, dynamic>? existing) async {
    if (!widget.auth.canWrite) return;
    final body = await Navigator.of(context).push<Map<String, String>>(
      fadeRoute(
        RecordFormPage(
          title: existing == null ? 'Add ${widget.title}' : 'Update ${widget.title}',
          fields: widget.fields,
          initial: existing,
          auth: widget.auth,
          locationId: asInt(existing?['locationId']) ?? _scopeLocationId,
          commissionModule: widget.commissionModule,
        ),
      ),
    );
    if (body == null || !mounted) return;
    try {
      final id = existing == null ? null : _idOf(existing);
      final loc = widget.auth.effectiveLocationId;
      if (existing == null) {
        final saved = await widget.auth.api.addRow(widget.auth.apiBase, widget.path, body, locationId: loc);
        if (mounted && saved['newBalance'] != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              'Amount ${rupee(asNum(saved['amount']))}  ·  Commission +${rupee(asNum(saved['commission']))}  ·  Net ${rupee(asNum(saved['netImpact']))}  ·  Balance ${rupee(asNum(saved['newBalance']))}',
            ),
          ));
        }
      } else {
        if (id == null) throw ApiException('Entry id nahi mili');
        await widget.auth.api.updateRow(widget.auth.apiBase, widget.path, id, body, locationId: loc);
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
        title: const Text('Reverse transaction?'),
        content: Text('Reverse ${row['name'] ?? row['transactionId'] ?? id}? Original row rahegi. Wallet aur commission restore honge. History delete nahi hogi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reverse'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.auth.api.deleteRow(
        widget.auth.apiBase,
        widget.path,
        id,
        locationId: widget.auth.effectiveLocationId,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _pdf({required bool share}) async {
    await downloadRecordsPdf(
      context,
      title: widget.title,
      headers: ['S.No.', ...widget.fields.map((f) => f.label)],
      rows: [
        for (var i = 0; i < _rows.length; i++)
          [
            '${((_page - 1) * _limit) + i + 1}',
            for (final f in widget.fields) '${_rows[i][f.key] ?? ''}',
          ],
      ],
      share: share,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = widget.auth.canWrite;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.nested,
        title: Text(
          widget.locationName == null || widget.locationName!.isEmpty
              ? widget.title
              : '${widget.title}  •  ${widget.locationName}',
        ),
        actions: [
          IconButton(
            tooltip: 'Download colorful PDF',
            onPressed: _loading || _rows.isEmpty ? null : () => _pdf(share: false),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'Share PDF',
            onPressed: _loading || _rows.isEmpty ? null : () => _pdf(share: true),
            icon: const Icon(Icons.share_outlined),
          ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF6EE7B7)),
                  ),
                  child: Text(
                    widget.commissionModule == null
                        ? 'Balance ${rupee(_remaining)}   ·   Extra commission ${rupee(_commission)}   ·   Added ${rupee(_wallet)}'
                        : 'Balance ${rupee(_remaining)}   ·   Added ${rupee(_wallet)}   ·   Used ${rupee(_used)}   ·   Commission ${rupee(_commission)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: BsnlColors.navyDark),
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _search,
                    onChanged: _onSearch,
                    decoration: const InputDecoration(
                      hintText: 'Search name / number / ID',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                  ),
                ),
                if (_hasStatus)
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _status,
                      decoration: const InputDecoration(labelText: 'Status', isDense: true),
                      items: [
                        const DropdownMenuItem(value: 'All', child: Text('All')),
                        for (final o in _statusOptions) DropdownMenuItem(value: o, child: Text(o)),
                      ],
                      onChanged: (v) {
                        _status = v ?? 'All';
                        _page = 1;
                        _load();
                      },
                    ),
                  ),
                if (_hasType)
                  SizedBox(
                    width: 170,
                    child: DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _type,
                      decoration: const InputDecoration(labelText: 'Type', isDense: true),
                      items: [
                        const DropdownMenuItem(value: 'All', child: Text('All types')),
                        for (final o in _typeOptions) DropdownMenuItem(value: o, child: Text(o)),
                      ],
                      onChanged: (v) {
                        _type = v ?? 'All';
                        _page = 1;
                        _load();
                      },
                    ),
                  ),
                _DateChip(
                  label: 'From',
                  value: _from,
                  onPick: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _from ?? DateTime.now(),
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2035),
                    );
                    if (d == null) return;
                    setState(() {
                      _from = d;
                      _page = 1;
                    });
                    _load();
                  },
                  onClear: _from == null
                      ? null
                      : () {
                          setState(() {
                            _from = null;
                            _page = 1;
                          });
                          _load();
                        },
                ),
                _DateChip(
                  label: 'To',
                  value: _to,
                  onPick: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _to ?? DateTime.now(),
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2035),
                    );
                    if (d == null) return;
                    setState(() {
                      _to = d;
                      _page = 1;
                    });
                    _load();
                  },
                  onClear: _to == null
                      ? null
                      : () {
                          setState(() {
                            _to = null;
                            _page = 1;
                          });
                          _load();
                        },
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: '$_sort|$_order',
                    decoration: const InputDecoration(labelText: 'Sort', isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'date|desc', child: Text('Date · newest')),
                      DropdownMenuItem(value: 'date|asc', child: Text('Date · oldest')),
                      DropdownMenuItem(value: 'amount|desc', child: Text('Amount · high')),
                      DropdownMenuItem(value: 'amount|asc', child: Text('Amount · low')),
                      DropdownMenuItem(value: 'commission|desc', child: Text('Commission · high')),
                      DropdownMenuItem(value: 'balance|desc', child: Text('Balance · high')),
                      DropdownMenuItem(value: 'name|asc', child: Text('Name A–Z')),
                    ],
                    onChanged: (v) {
                      final p = (v ?? 'date|desc').split('|');
                      _sort = p[0];
                      _order = p.length > 1 ? p[1] : 'desc';
                      _page = 1;
                      _load();
                    },
                  ),
                ),
                Text(
                  _total == 0 ? '0 rows' : '${((_page - 1) * _limit) + 1}–${(((_page - 1) * _limit) + _rows.length).clamp(0, _total)} of $_total',
                  style: const TextStyle(color: BsnlColors.muted, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  tooltip: 'Previous',
                  onPressed: _page <= 1 || _loading ? null : () { _page -= 1; _load(); },
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  tooltip: 'Next',
                  onPressed: _loading || (_page * _limit) >= _total ? null : () { _page += 1; _load(); },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
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
                                            '${((_page - 1) * _limit) + i + 1}',
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
    if (f.key == 'amount' || f.key == 'commission' || f.key == 'balance' || f.key == 'actualBalance' || f.key == 'previousBalance') {
      final reversed = '${row['transactionStatus'] ?? ''}' == 'REVERSED';
      return Text(
        rupee(asNum(row[f.key] ?? row['${f.key}Num'])),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          decoration: reversed && f.key == 'amount' ? TextDecoration.lineThrough : null,
          color: reversed ? BsnlColors.muted : null,
        ),
      );
    }
    return Text(text);
  }
}

class RecordFormPage extends StatefulWidget {
  const RecordFormPage({
    super.key,
    required this.title,
    required this.fields,
    this.initial,
    this.auth,
    this.locationId,
    this.commissionModule,
  });
  final String title;
  final List<RecordField> fields;
  final Map<String, dynamic>? initial;
  final AuthStore? auth;
  final int? locationId;
  final String? commissionModule;

  @override
  State<RecordFormPage> createState() => _RecordFormPageState();
}

class _RecordFormPageState extends State<RecordFormPage> {
  late final Map<String, TextEditingController> _ctrls;
  late final Map<String, DateTime> _dates;
  late final Map<String, String> _choices;
  num _previous = 0;
  Map<String, dynamic>? _preview;
  Timer? _previewDebounce;
  bool get _moneyLocked {
    final status = '${widget.initial?['transactionStatus'] ?? ''}';
    return widget.initial != null && status == 'SUCCESS';
  }

  @override
  void initState() {
    super.initState();
    _ctrls = {
      for (final f in widget.fields)
        if (f.kind == RecordFieldKind.text || f.kind == RecordFieldKind.actualBalance)
          f.key: TextEditingController(text: '${widget.initial?[f.key] ?? widget.initial?['actualBalance'] ?? ''}'),
    };
    _dates = {
      for (final f in widget.fields)
        if (f.kind == RecordFieldKind.date) f.key: parseRecordDate('${widget.initial?[f.key] ?? ''}'),
    };
    _choices = {
      for (final f in widget.fields)
        if (f.kind == RecordFieldKind.choice)
          f.key: _choiceValue(f, '${widget.initial?[f.key] ?? ''}'),
    };
    _ctrls['amount']?.addListener(_onMoneyChanged);
    _previous = asNum(widget.initial?['previousBalance']);
    _loadWallet();
  }

  void _onMoneyChanged() {
    if (!mounted) return;
    setState(() {});
    _queuePreview();
  }

  void _queuePreview() {
    if (widget.commissionModule == null || _moneyLocked) return;
    _previewDebounce?.cancel();
    _previewDebounce = Timer(const Duration(milliseconds: 350), _loadPreview);
  }

  Future<void> _loadWallet() async {
    final auth = widget.auth;
    if (auth == null || widget.commissionModule == null) return;
    try {
      final json = await auth.api.serviceWallet(auth.apiBase, widget.commissionModule!);
      if (!mounted) return;
      setState(() => _previous = asNum(json['currentBalance'] ?? json['currentBalanceNum']));
      _queuePreview();
    } catch (_) {}
  }

  Future<void> _loadPreview() async {
    final auth = widget.auth;
    if (auth == null || widget.commissionModule == null || _amount <= 0) return;
    try {
      final json = await auth.api.previewUsage(
        auth.apiBase,
        widget.commissionModule!,
        amount: _ctrls['amount']?.text.trim() ?? '',
      );
      if (!mounted) return;
      setState(() => _preview = json);
    } catch (_) {}
  }

  num get _amount => asNum(_ctrls['amount']?.text);
  num get _previewCommission {
    if (_preview != null) return asNum(_preview?['commission']);
    if (_moneyLocked) return asNum(widget.initial?['commission'] ?? widget.initial?['commissionNum']);
    return 0;
  }
  num get _previewNew {
    if (_preview != null) return asNum(_preview?['newBalance']);
    if (_moneyLocked) return asNum(widget.initial?['actualBalance'] ?? widget.initial?['balance']);
    return _previous - _amount + _previewCommission;
  }
  num get _previewNet {
    if (_preview != null) return asNum(_preview?['netImpact']);
    return -_amount + _previewCommission;
  }
  num get _previewPrev {
    if (_preview != null) return asNum(_preview?['previousBalance']);
    if (_moneyLocked) return asNum(widget.initial?['previousBalance']);
    return _previous;
  }

  String _choiceValue(RecordField f, String raw) {
    if (f.options.contains(raw)) return raw;
    return f.options.isEmpty ? raw : f.options.first;
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> _body() {
    final out = <String, String>{
      for (final f in widget.fields)
        if (f.kind != RecordFieldKind.computed && f.kind != RecordFieldKind.commission)
          f.key: switch (f.kind) {
            RecordFieldKind.date => DateFormat('dd/MM/yyyy').format(_dates[f.key]!),
            RecordFieldKind.choice => _choices[f.key] ?? '',
            RecordFieldKind.text => _ctrls[f.key]!.text.trim(),
            RecordFieldKind.actualBalance => _ctrls[f.key]!.text.trim(),
            RecordFieldKind.computed => '',
            RecordFieldKind.commission => '',
          },
    };
    out.remove('balance');
    out.remove('actualBalance');
    out.remove('commission');
    return out;
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
    final adding = widget.initial == null;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FadeIn(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
          children: [
            Text(
              adding
                  ? 'Koi field required nahi. Text, dash (-) aur decimal / minus amount bhi chalega.'
                  : 'Koi field required nahi. Jo chaho update karo.',
              style: const TextStyle(color: BsnlColors.muted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            if (widget.commissionModule != null) ...[
              Text(
                'New wallet = Current − Amount + 1% commission. Balance type mat karo — usse wallet nahi badhega.',
                style: const TextStyle(color: BsnlColors.navy, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              _CalcBox(
                previous: _previewPrev,
                amount: _amount,
                commission: _previewCommission,
                net: _previewNet,
                next: _preview == null ? (_previous - _amount + _previewCommission) : _previewNew,
              ),
              if (_moneyLocked) ...[
                const SizedBox(height: 8),
                const Text(
                  'Successful transaction ki amount/commission lock hai. Correction ke liye Reverse use karo.',
                  style: TextStyle(color: BsnlColors.muted, fontWeight: FontWeight.w700),
                ),
              ],
              const SizedBox(height: 12),
            ],
            for (final f in widget.fields)
              if (f.kind != RecordFieldKind.computed)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: switch (f.kind) {
                  RecordFieldKind.date => InkWell(
                      onTap: () => _pick(f.key),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: f.label,
                          suffixIcon: const Icon(Icons.calendar_month_outlined),
                        ),
                        child: Text(DateFormat('EEE, d MMM yyyy').format(_dates[f.key]!)),
                      ),
                    ),
                  RecordFieldKind.choice => DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _choices[f.key],
                      decoration: InputDecoration(labelText: f.label),
                      items: [
                        for (final o in f.options) DropdownMenuItem(value: o, child: Text(o)),
                      ],
                      onChanged: (v) => setState(() => _choices[f.key] = v ?? f.options.first),
                    ),
                  RecordFieldKind.text => TextField(
                      controller: _ctrls[f.key],
                      readOnly: _moneyLocked && f.key == 'amount',
                      keyboardType: f.keyboard,
                      decoration: InputDecoration(
                        labelText: f.label,
                        helperText: f.key == 'amount' && widget.commissionModule != null ? 'Wallet se jo amount kata' : null,
                      ),
                    ),
                  RecordFieldKind.actualBalance => TextField(
                      controller: _ctrls[f.key],
                      readOnly: _moneyLocked,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: f.label,
                        helperText: 'Optional. BSNL remaining likho to commission usse nikalegi, warna 1% automatic.',
                        prefixText: '₹ ',
                      ),
                    ),
                  RecordFieldKind.commission => InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Commission (automatic)',
                        suffixText: 'Auto',
                        helperText: 'Backend se aati hai. Type / delete nahi kar sakte.',
                        filled: true,
                        fillColor: Color(0xFFF8FAFC),
                      ),
                      child: Text(
                        rupee(_previewCommission),
                        style: const TextStyle(fontWeight: FontWeight.w800, color: BsnlColors.navyDark),
                      ),
                    ),
                  RecordFieldKind.computed => const SizedBox.shrink(),
                },
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, _body()),
              icon: Icon(adding ? Icons.add : Icons.save_outlined),
              label: Text(adding ? 'Save' : 'Update'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalcBox extends StatelessWidget {
  const _CalcBox({
    required this.previous,
    required this.amount,
    required this.commission,
    required this.net,
    required this.next,
  });
  final num previous;
  final num amount;
  final num commission;
  final num net;
  final num next;

  @override
  Widget build(BuildContext context) {
    Widget line(String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, color: BsnlColors.navyDark)),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line('Current wallet', rupee(previous)),
          line('Transaction amount', rupee(amount)),
          line('Commission', '+${rupee(commission)}'),
          line('Net wallet change', rupee(net)),
          line('New balance', rupee(next)),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label, required this.value, required this.onPick, this.onClear});
  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final text = value == null ? label : '$label ${DateFormat('dd/MM/yyyy').format(value!)}';
    return InputChip(
      label: Text(text),
      avatar: const Icon(Icons.calendar_month_outlined, size: 18),
      onPressed: onPick,
      onDeleted: onClear,
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
