import 'package:flutter/material.dart';

import '../state/auth_store.dart';
import '../util/format.dart';

class LocationOption {
  const LocationOption({required this.id, required this.name, this.status = 'active'});
  final int id;
  final String name;
  final String status;
}

Future<List<LocationOption>> loadLocationOptions(AuthStore auth) async {
  final rows = await auth.api.listLocations(auth.apiBase);
  return [
    for (final r in rows)
      if (asInt(r['id']) != null)
        LocationOption(
          id: asInt(r['id'])!,
          name: '${r['name'] ?? ''}',
          status: '${r['status'] ?? 'active'}',
        ),
  ];
}

class JagahField extends StatelessWidget {
  const JagahField({
    super.key,
    required this.locations,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final List<LocationOption> locations;
  final int? value;
  final ValueChanged<int?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (locations.isEmpty) {
      return const InputDecorator(
        decoration: InputDecoration(labelText: 'Jagah *'),
        child: Text('Pehle Locations se jagah add karo'),
      );
    }
    final ids = {for (final l in locations) l.id};
    final selected = value != null && ids.contains(value) ? value : (locations.length == 1 ? locations.first.id : null);
    return DropdownButtonFormField<int>(
      // ignore: deprecated_member_use
      value: selected,
      decoration: const InputDecoration(
        labelText: 'Jagah *',
        prefixIcon: Icon(Icons.place_outlined),
      ),
      items: [
        for (final l in locations)
          DropdownMenuItem(
            value: l.id,
            child: Text(l.status == 'inactive' ? '${l.name} (off)' : l.name),
          ),
      ],
      onChanged: enabled ? onChanged : null,
      validator: (v) => v == null ? 'Jagah choose karo' : null,
    );
  }
}
