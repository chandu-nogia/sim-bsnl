import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../state/auth_store.dart';
import '../widgets/fade_in.dart';

class LocationFormPage extends StatefulWidget {
  const LocationFormPage({super.key, required this.auth, this.existing});
  final AuthStore auth;
  final Map<String, dynamic>? existing;

  @override
  State<LocationFormPage> createState() => _LocationFormPageState();
}

class _LocationFormPageState extends State<LocationFormPage> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _password;
  bool _busy = false;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: '${widget.existing?['name'] ?? ''}');
    _email = TextEditingController(text: '${widget.existing?['email'] ?? ''}');
    _password = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  int? _idOf() {
    final v = widget.existing?['id'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v');
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_editing) {
        final id = _idOf();
        if (id == null) throw Exception('Jagah id nahi mili');
        await widget.auth.api.updateLocation(
          widget.auth.apiBase,
          id,
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text.trim(),
        );
      } else {
        await widget.auth.api.addLocation(
          widget.auth.apiBase,
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final id = _idOf();
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Jagah delete?'),
        content: const Text('Login band ho jayega. Data rehta hai.'),
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
      await widget.auth.api.deleteLocation(widget.auth.apiBase, id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Jagah update' : 'Nayi jagah add'),
        actions: [
          if (_editing)
            IconButton(
              tooltip: 'Delete',
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: FadeIn(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
          children: [
            const Text(
              'Har jagah ka apna email/password hoga. Us login pe SIM, CBC aur CTopup milenge.',
              style: TextStyle(color: BsnlColors.muted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Jagah ka naam *', hintText: 'Khatu'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'ID / Email *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: _editing ? 'Naya password (optional)' : 'Password *',
              ),
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
