import 'dart:async';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../state/auth_store.dart';

class GlobalSearchButton extends StatelessWidget {
  const GlobalSearchButton({
    super.key,
    required this.auth,
    required this.onOpen,
  });
  final AuthStore auth;
  final void Function(String section, {int? locationId, String locationName, String? employeeEmail}) onOpen;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Search',
      onPressed: () {
        showSearch(
          context: context,
          delegate: _PortalSearch(auth: auth, onOpen: onOpen),
        );
      },
      icon: const Icon(Icons.search),
    );
  }
}

class _PortalSearch extends SearchDelegate<void> {
  _PortalSearch({required this.auth, required this.onOpen});
  final AuthStore auth;
  final void Function(String section, {int? locationId, String locationName, String? employeeEmail}) onOpen;
  Timer? _debounce;
  Map<String, List<Map<String, dynamic>>> _groups = {};
  bool _loading = false;
  String _last = '';

  @override
  String get searchFieldLabel => 'Search name, mobile, email, ID, Txn…';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(onPressed: () => query = '', icon: const Icon(Icons.close)),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(onPressed: () => close(context, null), icon: const Icon(Icons.arrow_back));
  }

  Future<void> _run(String q) async {
    if (q.trim().length < 2) {
      _groups = {};
      _loading = false;
      return;
    }
    _loading = true;
    try {
      final json = await auth.api.search(auth.apiBase, q.trim());
      _groups = {
        for (final e in json.entries)
          e.key: [
            for (final r in (e.value as List? ?? []))
              if (r is Map) Map<String, dynamic>.from(r),
          ],
      };
    } catch (_) {
      _groups = {};
    } finally {
      _loading = false;
    }
  }

  @override
  Widget buildResults(BuildContext context) => buildSuggestions(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    final q = query.trim();
    if (q != _last) {
      _last = q;
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 320), () async {
        await _run(q);
        if (!context.mounted) return;
        if (query.trim() == q) {
          showSuggestions(context);
        }
      });
    }
    if (q.length < 2) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Type at least 2 characters. Search employees, locations, Portal, CBC, C-TopUp.', style: TextStyle(color: BsnlColors.muted)),
      );
    }
    if (_loading && _groups.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final sections = [
      ('employees', 'Employees'),
      ('locations', 'Locations'),
      ('sims', 'BSNL Portal'),
      ('cbc', 'CBC'),
      ('ctopup', 'C-TopUp'),
    ];
    final has = sections.any((s) => (_groups[s.$1] ?? []).isNotEmpty);
    if (!has) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('No records found for the selected filters.', style: TextStyle(color: BsnlColors.muted)),
      );
    }
    return ListView(
      children: [
        for (final s in sections)
          if ((_groups[s.$1] ?? []).isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Text(s.$2, style: const TextStyle(fontWeight: FontWeight.w800, color: BsnlColors.navyDark)),
            ),
            for (final r in _groups[s.$1]!)
              ListTile(
                title: Text('${r['title'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${r['subtitle'] ?? ''}'),
                onTap: () {
                  close(context, null);
                  final section = '${r['section'] ?? s.$1}';
                  onOpen(
                    section == 'sims' ? 'portal' : section,
                    locationId: int.tryParse('${r['locationId'] ?? ''}'),
                    locationName: '${r['locationName'] ?? ''}',
                    employeeEmail: '${r['email'] ?? ''}',
                  );
                },
              ),
          ],
      ],
    );
  }
}
