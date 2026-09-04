import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../state/auth_store.dart';
import '../util/format.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key, required this.auth});
  final AuthStore auth;

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  final _qty = TextEditingController();
  final _low = TextEditingController(text: '20');
  Map<String, dynamic> _stock = {};
  bool _busy = false;
  String? _error;

  int? get _loc => widget.auth.effectiveLocationId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _qty.dispose();
    _low.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loc == null) {
      setState(() => _error = 'Pehle location choose karo');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final s = await widget.auth.api.stock(widget.auth.apiBase, locationId: _loc);
      setState(() {
        _stock = s;
        _qty.text = '${s['qty'] ?? 0}';
        _low.text = '${s['lowAt'] ?? 20}';
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_loc == null) return;
    setState(() => _busy = true);
    try {
      await widget.auth.api.saveStock(
        widget.auth.apiBase,
        qty: int.tryParse(_qty.text) ?? 0,
        lowAt: int.tryParse(_low.text) ?? 20,
        locationId: _loc,
      );
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final low = _stock['low'] == true;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('SIM Stock', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: BsnlColors.navyDark)),
        const SizedBox(height: 6),
        Text(widget.auth.locationName.isEmpty ? 'Assigned location ka stock' : widget.auth.locationName, style: const TextStyle(color: BsnlColors.muted)),
        const SizedBox(height: 16),
        if (_error != null) Text(_error!, style: const TextStyle(color: BsnlColors.saffron, fontWeight: FontWeight.w700)),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (low)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('Low stock alert', style: TextStyle(color: BsnlColors.saffron, fontWeight: FontWeight.w800)),
                  ),
                TextField(controller: _qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Available SIM quantity')),
                const SizedBox(height: 12),
                TextField(controller: _low, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Alert when below')),
                const SizedBox(height: 14),
                FilledButton(onPressed: _busy ? null : _save, child: const Text('Save stock')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ClosingPage extends StatefulWidget {
  const ClosingPage({super.key, required this.auth});
  final AuthStore auth;

  @override
  State<ClosingPage> createState() => _ClosingPageState();
}

class _ClosingPageState extends State<ClosingPage> {
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic> _today = {};
  bool _busy = false;
  String? _error;

  int? get _loc => widget.auth.effectiveLocationId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loc == null) {
      setState(() => _error = 'Pehle location choose karo');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final today = await widget.auth.api.today(widget.auth.apiBase, locationId: _loc);
      final rows = await widget.auth.api.closing(widget.auth.apiBase, locationId: _loc);
      setState(() {
        _today = today;
        _rows = rows;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_loc == null) return;
    setState(() => _busy = true);
    try {
      await widget.auth.api.submitClosing(widget.auth.apiBase, {
        'date': '${_today['date'] ?? ''}',
        'sims': _today['sims'],
        'cbcCount': _today['cbcCount'],
        'cbcAmount': _today['cbcAmount'],
        'ctopupCount': _today['ctopupCount'],
        'ctopupAmount': _today['ctopupAmount'],
        'cash': (asNum(_today['cbcAmount']) + asNum(_today['ctopupAmount'])),
      }, locationId: _loc);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Closing submitted')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(int id, String status) async {
    try {
      await widget.auth.api.reviewClosing(widget.auth.apiBase, id, status);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Daily Closing', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: BsnlColors.navyDark)),
        const SizedBox(height: 6),
        const Text('Aaj ke Portal / CBC / C-TopUp numbers submit karo. Admin approve karega.', style: TextStyle(color: BsnlColors.muted)),
        const SizedBox(height: 16),
        if (_error != null) Text(_error!, style: const TextStyle(color: BsnlColors.saffron, fontWeight: FontWeight.w700)),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Today  ${_today['date'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Users: ${_today['sims'] ?? 0}'),
                Text('CBC: ${_today['cbcCount'] ?? 0}  ·  ${rupee(asNum(_today['cbcAmount']))}'),
                Text('C-TopUp: ${_today['ctopupCount'] ?? 0}  ·  ${rupee(asNum(_today['ctopupAmount']))}'),
                const SizedBox(height: 12),
                FilledButton(onPressed: _busy ? null : _submit, child: const Text('Submit today closing')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final r in _rows)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text('${r['date']}  ·  ${r['status']}', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${r['createdBy']}  ·  CBC ${rupee(asNum(r['cbcAmount']))}  ·  C-TopUp ${rupee(asNum(r['ctopupAmount']))}'),
              trailing: widget.auth.isAdmin && '${r['status']}' == 'pending'
                  ? Wrap(
                      children: [
                        TextButton(onPressed: () => _review(asInt(r['id']) ?? 0, 'approved'), child: const Text('Approve')),
                        TextButton(onPressed: () => _review(asInt(r['id']) ?? 0, 'rejected'), child: const Text('Reject')),
                      ],
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}
