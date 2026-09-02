import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../state/auth_store.dart';
import '../util/format.dart';
import '../widgets/fade_in.dart';

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key, required this.auth});
  final AuthStore auth;

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _locations = [];

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
      final rows = await widget.auth.api.listEmployees(widget.auth.apiBase);
      final locs = await widget.auth.api.listLocations(widget.auth.apiBase);
      setState(() {
        _rows = rows;
        _locations = locs;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(Map<String, dynamic>? existing) async {
    final ok = await Navigator.of(context).push<bool>(
      fadeRoute(EmployeeFormPage(auth: widget.auth, locations: _locations, existing: existing)),
    );
    if (ok == true) _load();
  }

  Future<void> _reset(Map<String, dynamic> row) async {
    final ctrl = TextEditingController();
    final pw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset password'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'New password'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Reset')),
        ],
      ),
    );
    if (pw == null || pw.length < 4) return;
    try {
      await widget.auth.api.resetEmployeePassword(widget.auth.apiBase, '${row['email']}', pw);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _toggle(Map<String, dynamic> row) async {
    if ('${row['role']}' == 'admin') return;
    final inactive = '${row['status']}' == 'inactive';
    try {
      await widget.auth.api.saveEmployee(
        widget.auth.apiBase,
        id: '${row['email']}',
        name: '${row['name'] ?? ''}',
        email: '${row['email'] ?? ''}',
        assignedLocations: [
          for (final x in (row['assignedLocations'] as List? ?? []) )
            if (asInt(x) != null) asInt(x)!,
        ],
        status: inactive ? 'active' : 'inactive',
      );
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    if ('${row['role']}' == 'admin') return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete employee?'),
        content: Text('${row['name'] ?? row['email']} delete ho jayega.'),
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
    if (ok != true) return;
    try {
      await widget.auth.api.deleteEmployee(widget.auth.apiBase, '${row['email']}');
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
                  'Assign one or more locations. Employee sirf unhi jagahon ka data dekhega.',
                  style: TextStyle(color: BsnlColors.muted, fontWeight: FontWeight.w600),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _edit(null),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Add employee'),
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
                  ? const Center(child: Text('No employees', style: TextStyle(color: BsnlColors.muted)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(BsnlColors.navy),
                            headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            columns: const [
                              DataColumn(label: Text('Name')),
                              DataColumn(label: Text('Email')),
                              DataColumn(label: Text('Locations')),
                              DataColumn(label: Text('Role')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Created')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: [
                              for (final row in _rows)
                                DataRow(
                                  cells: [
                                    DataCell(Text('${row['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700))),
                                    DataCell(Text('${row['email'] ?? ''}')),
                                    DataCell(Text(((row['assignedLocationNames'] as List?) ?? []).join(', '))),
                                    DataCell(Text('${row['role'] ?? ''}')),
                                    DataCell(Text('${row['status'] ?? 'active'}')),
                                    DataCell(Text('${row['createdAt'] ?? ''}'.split('T').first)),
                                    DataCell(
                                      Row(
                                        children: [
                                          IconButton(
                                            tooltip: 'Edit / assign',
                                            onPressed: '${row['role']}' == 'admin' ? null : () => _edit(row),
                                            icon: const Icon(Icons.edit_outlined),
                                          ),
                                          IconButton(
                                            tooltip: 'Reset password',
                                            onPressed: () => _reset(row),
                                            icon: const Icon(Icons.lock_reset_outlined),
                                          ),
                                          IconButton(
                                            tooltip: 'Activate / deactivate',
                                            onPressed: '${row['role']}' == 'admin' ? null : () => _toggle(row),
                                            icon: Icon(
                                              '${row['status']}' == 'inactive'
                                                  ? Icons.toggle_off_outlined
                                                  : Icons.toggle_on_outlined,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Delete',
                                            onPressed: '${row['role']}' == 'admin' ? null : () => _delete(row),
                                            icon: const Icon(Icons.delete_outline, color: Color(0xFFC62828)),
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
      ],
    );
  }
}

class EmployeeFormPage extends StatefulWidget {
  const EmployeeFormPage({
    super.key,
    required this.auth,
    required this.locations,
    this.existing,
  });
  final AuthStore auth;
  final List<Map<String, dynamic>> locations;
  final Map<String, dynamic>? existing;

  @override
  State<EmployeeFormPage> createState() => _EmployeeFormPageState();
}

class _EmployeeFormPageState extends State<EmployeeFormPage> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _password;
  late Set<int> _assigned;
  String _status = 'active';
  bool _busy = false;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: '${widget.existing?['name'] ?? ''}');
    _email = TextEditingController(text: '${widget.existing?['email'] ?? ''}');
    _password = TextEditingController();
    _assigned = {
      for (final x in (widget.existing?['assignedLocations'] as List? ?? []))
        if (asInt(x) != null) asInt(x)!,
    };
    _status = '${widget.existing?['status'] ?? 'active'}';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.api.saveEmployee(
        widget.auth.apiBase,
        id: _editing ? '${widget.existing?['email']}' : null,
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text.trim(),
        assignedLocations: _assigned.toList(),
        status: _status,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit employee' : 'Add employee')),
      body: FadeIn(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name *')),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(labelText: _editing ? 'New password (optional)' : 'Password *'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'active'),
            ),
            const SizedBox(height: 16),
            const Text('Assigned locations', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final loc in widget.locations)
                  FilterChip(
                    label: Text('${loc['name']}'),
                    selected: _assigned.contains(asInt(loc['id'])),
                    onSelected: (on) {
                      final id = asInt(loc['id']);
                      if (id == null) return;
                      setState(() {
                        if (on) {
                          _assigned.add(id);
                        } else {
                          _assigned.remove(id);
                        }
                      });
                    },
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_editing ? 'Update' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
