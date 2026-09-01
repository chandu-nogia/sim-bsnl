import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_theme.dart';
import '../models/sim_entry.dart';
import '../state/sim_store.dart';

Future<void> showEntryForm(
  BuildContext context,
  SimStore store, {
  SimEntry? existing,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: _EntryForm(store: store, existing: existing),
      ),
    ),
  );
}

class _EntryForm extends StatefulWidget {
  const _EntryForm({required this.store, this.existing});
  final SimStore store;
  final SimEntry? existing;

  @override
  State<_EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<_EntryForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _alt = TextEditingController();
  final _sim = TextEditingController();
  DateTime _date = DateTime.now();
  SimType _type = SimType.cymn;
  String _frc = '';
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e == null) return;
    _name.text = e.name;
    _mobile.text = e.mobile;
    _alt.text = e.altNumber;
    _sim.text = e.simNo;
    _date = _parseDate(e.date);
    _type = e.type;
    _frc = (e.frc == '1' || e.frc == '2') ? e.frc : '';
  }

  DateTime _parseDate(String raw) {
    final p = raw.split(RegExp(r'[/-]'));
    if (p.length != 3) return DateTime.now();
    final d = int.tryParse(p[0].trim()) ?? 1;
    final m = int.tryParse(p[1].trim()) ?? 1;
    var y = int.tryParse(p[2].trim()) ?? DateTime.now().year;
    if (y < 100) y += 2000;
    return DateTime(y, m, d);
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _alt.dispose();
    _sim.dispose();
    super.dispose();
  }

  String get _dateText => '${_date.day}/${_date.month}/${_date.year % 100}';

  String get _last6 {
    final d = _sim.text.replaceAll(RegExp(r'\D'), '');
    if (d.length >= 6) return d.substring(d.length - 6);
    return d;
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime(2032),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final existing = widget.existing;
    final entry = SimEntry(
      rowIndex: existing?.rowIndex,
      date: _dateText,
      sno: existing?.sno ?? widget.store.nextSno,
      name: _name.text.trim(),
      altNumber: _alt.text.trim(),
      frc: _frc,
      type: _type,
      mobile: _mobile.text.trim(),
      simNo: _sim.text.trim(),
      simLast6: _last6,
      status: existing?.status ?? 'Issued',
    );
    try {
      if (existing != null) {
        await widget.store.updateEntry(existing, entry);
      } else {
        await widget.store.addEntry(entry);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade800),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.sim_card, color: BsnlColors.navy),
                const SizedBox(width: 10),
                Text(
                  _editing ? 'SIM entry edit' : 'Nayi SIM entry',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: BsnlColors.navy,
                      ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _editing
                  ? 'S.No. ${widget.existing!.sno}  •  ${widget.store.connected ? "Server par update" : "Local update"}'
                  : 'S.No. ${widget.store.nextSno}  •  ${widget.store.connected ? "Server par turant save" : "Local save (Settings se server jodo)"}',
              style: const TextStyle(color: BsnlColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _pickDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date',
                                prefixIcon: Icon(Icons.event),
                              ),
                              child: Text(_dateText),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<SimType>(
                            // ignore: deprecated_member_use
                            value: _type,
                            decoration: const InputDecoration(
                              labelText: 'Type *',
                            ),
                            items: [
                              for (final t in SimType.values)
                                DropdownMenuItem(
                                  value: t,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: t.color,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.black26,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(t.label),
                                      const SizedBox(width: 6),
                                      Text(
                                        t.meaning,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: BsnlColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                            onChanged: (v) => setState(() => _type = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Name *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Naam likho' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _mobile,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            decoration: const InputDecoration(
                              labelText: 'Mobile Number *',
                              counterText: '',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            validator: (v) {
                              if (v == null || !RegExp(r'^\d{10}$').hasMatch(v)) {
                                return '10 digit mobile';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _alt,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            decoration: const InputDecoration(
                              labelText: 'Alternate Number',
                              counterText: '',
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return null;
                              if (!RegExp(r'^\d{10}$').hasMatch(v)) {
                                return '10 digit';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _sim,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'SIM No. *',
                              prefixIcon: Icon(Icons.sim_card_outlined),
                            ),
                            validator: (v) => (v == null || v.trim().length < 6)
                                ? 'SIM number likho'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'SIM Last 6',
                            ),
                            child: Text(_last6.isEmpty ? '—' : _last6),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            // ignore: deprecated_member_use
                            value: _frc,
                            decoration: const InputDecoration(labelText: 'FRC'),
                            items: const [
                              DropdownMenuItem(value: '', child: Text('—')),
                              DropdownMenuItem(value: '1', child: Text('1')),
                              DropdownMenuItem(value: '2', child: Text('2')),
                            ],
                            onChanged: (v) => setState(() => _frc = v ?? ''),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  DateFormat('EEE, d MMM yyyy').format(_date),
                  style: const TextStyle(color: BsnlColors.muted),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(_editing ? Icons.save_outlined : Icons.cloud_upload_outlined),
                  label: Text(
                    _saving
                        ? (_editing ? 'Updating…' : 'Saving…')
                        : (_editing ? 'Update' : 'Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
