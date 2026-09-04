import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../services/excel_export.dart';
import '../services/pdf_export.dart';
import '../state/sim_store.dart';
import '../widgets/entry_form.dart';
import '../widgets/entry_table.dart';
import '../widgets/fade_in.dart';
import '../widgets/filters.dart';
import 'settings_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.store, this.locationName, this.nested = false});
  final SimStore store;
  final String? locationName;
  final bool nested;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: !nested,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nested ? 'Users / SIM Register' : 'BSNL SIM Portal'),
                Text(
                  locationName == null || locationName!.isEmpty
                      ? 'Register  •  CYMN / MNP / Swap / Postpaid'
                      : '$locationName  •  CYMN / MNP / Swap / Postpaid',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white70),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: store.connected
                          ? const Color(0xFFC8E6C9)
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      store.connected ? 'Server' : 'Local',
                      style: TextStyle(
                        color: store.connected ? BsnlColors.navyDark : Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Import CSV',
                onPressed: !store.canWrite
                    ? null
                    : () async {
                        final ctrl = TextEditingController();
                        final raw = await showDialog<String>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Import Portal CSV'),
                            content: SizedBox(
                              width: 480,
                              child: TextField(
                                controller: ctrl,
                                maxLines: 10,
                                decoration: const InputDecoration(
                                  hintText: 'date,name,mobile,sim,type,frc,status',
                                ),
                              ),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                              FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Import')),
                            ],
                          ),
                        );
                        if (raw == null || raw.trim().isEmpty) return;
                        final lines = raw.trim().split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
                        if (lines.length < 2) return;
                        final headers = lines.first.split(',').map((s) => s.trim()).toList();
                        final rows = <Map<String, dynamic>>[];
                        for (final line in lines.skip(1)) {
                          final cells = line.split(',');
                          final m = <String, dynamic>{};
                          for (var i = 0; i < headers.length && i < cells.length; i++) {
                            m[headers[i]] = cells[i].trim();
                          }
                          rows.add(m);
                        }
                        try {
                          final out = await store.auth.api.importRows(
                            store.auth.apiBase,
                            'sims',
                            rows,
                            locationId: store.auth.effectiveLocationId,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Imported ${out['added'] ?? 0}, failed ${out['failed'] ?? 0}')),
                            );
                          }
                          await store.load();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                          }
                        }
                      },
                icon: const Icon(Icons.upload_file_outlined),
              ),
              IconButton(
                tooltip: 'Download Excel',
                onPressed: store.filtered.isEmpty
                    ? null
                    : () => downloadSimExcel(context, store.filtered),
                icon: const Icon(Icons.table_view_outlined),
              ),
              IconButton(
                tooltip: 'Download colorful PDF',
                onPressed: store.filtered.isEmpty
                    ? null
                    : () => downloadSimPdf(context, store.filtered),
                icon: const Icon(Icons.picture_as_pdf_outlined),
              ),
              IconButton(
                tooltip: 'Share',
                onPressed: store.filtered.isEmpty
                    ? null
                    : () => showSimShareSheet(context, store.filtered),
                icon: const Icon(Icons.share_outlined),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: store.loading ? null : store.load,
                icon: store.loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.refresh),
              ),
              if (store.canWrite && !nested)
                IconButton(
                  tooltip: 'Server setup',
                  onPressed: () {
                    Navigator.of(context).push(fadeRoute(SettingsPage(store: store)));
                  },
                  icon: const Icon(Icons.settings_outlined),
                ),
              const SizedBox(width: 8),
            ],
          ),
          floatingActionButton: store.canWrite
              ? FloatingActionButton.extended(
                  onPressed: () => showEntryForm(context, store),
                  icon: const Icon(Icons.add),
                  label: const Text('Add SIM'),
                )
              : null,
          body: Column(
            children: [
              if (store.statusMessage != null)
                Container(
                  width: double.infinity,
                  color: store.connected ? const Color(0xFFE3F2FD) : const Color(0xFFFFF8E1),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    store.statusMessage!,
                    style: const TextStyle(fontSize: 13, color: BsnlColors.ink),
                  ),
                ),
              if (store.error != null)
                Container(
                  width: double.infinity,
                  color: const Color(0xFFFFEBEE),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(store.error!, style: TextStyle(color: Colors.red.shade900)),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
                  child: Column(
                    children: [
                      FadeIn(child: StatCards(store: store)),
                      const SizedBox(height: 12),
                      FadeIn(
                        delay: const Duration(milliseconds: 80),
                        child: FilterBar(store: store),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: FadeIn(
                          delay: const Duration(milliseconds: 140),
                          child: EntryTable(store: store),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
