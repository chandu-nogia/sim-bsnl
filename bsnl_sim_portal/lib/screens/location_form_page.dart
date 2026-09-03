import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../state/auth_store.dart';
import '../util/format.dart';
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
  late final TextEditingController _code;
  late final TextEditingController _address;
  String _status = 'active';
  bool _busy = false;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: '${widget.existing?['name'] ?? ''}');
    _code = TextEditingController(text: '${widget.existing?['code'] ?? ''}');
    _address = TextEditingController(text: '${widget.existing?['address'] ?? ''}');
    _status = '${widget.existing?['status'] ?? 'active'}';
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_editing) {
        final id = asInt(widget.existing?['id']);
        if (id == null) throw Exception('Jagah id nahi mili');
        await widget.auth.api.updateLocation(
          widget.auth.apiBase,
          id,
          name: _name.text.trim(),
          code: _code.text.trim(),
          address: _address.text.trim(),
          status: _status,
        );
      } else {
        await widget.auth.api.addLocation(
          widget.auth.apiBase,
          name: _name.text.trim(),
          code: _code.text.trim(),
          address: _address.text.trim(),
          status: _status,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_editing ? 'Location updated' : 'Location added — Portal, CBC, C-TopUp ready')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit location' : 'Add location')),
      body: FadeIn(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
          children: [
            const Text(
              'Nayi jagah add karo (Jaipur, Sikar, …). Us jagah ke apne 3 portals automatically milenge: BSNL Portal, CBC List, C-TopUp. Khatu ka data dusri jagah mein nahi dikhega.',
              style: TextStyle(color: BsnlColors.muted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Jagah ka naam *', hintText: 'Jaipur'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Jagah code', hintText: 'JPR'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Address'),
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
