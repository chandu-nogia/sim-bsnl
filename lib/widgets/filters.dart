import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/sim_entry.dart';
import '../services/excel_export.dart';
import '../state/sim_store.dart';

class StatCards extends StatelessWidget {
  const StatCards({super.key, required this.store});
  final SimStore store;

  @override
  Widget build(BuildContext context) {
    final c = store.counts;
    final total = store.entries.length;
    final items = [
      _Stat('TOTAL', total, BsnlColors.navy, Colors.white, 'All'),
      for (final t in SimType.values)
        _Stat(t.label, c[t.label] ?? 0, t.color, BsnlColors.ink, t.label),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth > 720;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final s in items)
              SizedBox(
                width: wide ? (box.maxWidth - 40) / 5 : (box.maxWidth - 10) / 2,
                child: _Card(stat: s, selected: store.typeFilter == s.filter, onTap: () => store.setTypeFilter(s.filter)),
              ),
          ],
        );
      },
    );
  }
}

class _Stat {
  _Stat(this.label, this.count, this.bg, this.fg, this.filter);
  final String label;
  final int count;
  final Color bg;
  final Color fg;
  final String filter;
}

class _Card extends StatelessWidget {
  const _Card({required this.stat, required this.selected, required this.onTap});
  final _Stat stat;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: stat.bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? BsnlColors.navy : Colors.black12,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stat.label,
                style: TextStyle(
                  color: stat.fg.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${stat.count}',
                style: TextStyle(
                  color: stat.fg,
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FilterBar extends StatelessWidget {
  const FilterBar({super.key, required this.store});
  final SimStore store;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                onChanged: store.setSearch,
                decoration: const InputDecoration(
                  hintText: 'Search name / mobile / SIM',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: store.typeFilter,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(value: 'All', child: Text('All types')),
                  for (final t in SimType.values)
                    DropdownMenuItem(
                      value: t.label,
                      child: Text(t.label),
                    ),
                ],
                onChanged: (v) => store.setTypeFilter(v ?? 'All'),
              ),
            ),
            SizedBox(
              width: 120,
              child: DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: store.frcFilter,
                decoration: const InputDecoration(
                  labelText: 'FRC',
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All')),
                  DropdownMenuItem(value: '1', child: Text('1')),
                  DropdownMenuItem(value: '2', child: Text('2')),
                ],
                onChanged: (v) => store.setFrcFilter(v ?? 'All'),
              ),
            ),
            TextButton.icon(
              onPressed: store.clearFilters,
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Clear'),
            ),
            OutlinedButton.icon(
              onPressed: store.filtered.isEmpty
                  ? null
                  : () => downloadSimExcel(context, store.filtered),
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Excel'),
            ),
            Text(
              '${store.filtered.length} / ${store.entries.length} rows',
              style: const TextStyle(color: BsnlColors.muted, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
