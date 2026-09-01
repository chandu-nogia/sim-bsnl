import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../services/excel_export.dart';
import '../state/sim_store.dart';
import '../widgets/entry_form.dart';
import '../widgets/entry_table.dart';
import '../widgets/filters.dart';
import 'settings_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.store});
  final SimStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BSNL SIM Portal'),
                Text(
                  'Register  •  CYMN / MNP / Swap / Postpaid',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white70),
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
                tooltip: 'Download Excel',
                onPressed: store.filtered.isEmpty
                    ? null
                    : () => downloadSimExcel(context, store.filtered),
                icon: const Icon(Icons.download_outlined),
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
              if (store.canWrite)
                IconButton(
                  tooltip: 'Server setup',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => SettingsPage(store: store)),
                    );
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
                      StatCards(store: store),
                      const SizedBox(height: 12),
                      FilterBar(store: store),
                      const SizedBox(height: 12),
                      Expanded(child: EntryTable(store: store)),
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
