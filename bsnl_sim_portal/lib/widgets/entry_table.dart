import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../models/sim_entry.dart';
import '../state/sim_store.dart';
import 'entry_form.dart';

class EntryTable extends StatelessWidget {
  const EntryTable({super.key, required this.store});
  final SimStore store;

  @override
  Widget build(BuildContext context) {
    final rows = store.filtered;
    if (rows.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Text(
              'Koi entry nahi — filter hatao${store.canWrite ? " ya Add SIM dabao" : ""}',
              style: const TextStyle(color: BsnlColors.muted),
            ),
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, box) {
          if (box.maxWidth < 700) {
            return ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => _MobileTile(
                index: i + 1,
                e: rows[i],
                store: store,
              ),
            );
          }
          return SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: box.maxWidth),
                child: DataTable(
                  border: TableBorder.all(color: const Color(0xFF94A3B8), width: 1),
                  headingRowColor: WidgetStateProperty.all(BsnlColors.navy),
                  headingTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 56,
                  columns: [
                    const DataColumn(label: Text('#'), numeric: true),
                    const DataColumn(label: Text('Date')),
                    const DataColumn(label: Text('Name')),
                    const DataColumn(label: Text('Type')),
                    const DataColumn(label: Text('Mobile')),
                    const DataColumn(label: Text('Alt. No.')),
                    const DataColumn(label: Text('FRC')),
                    const DataColumn(label: Text('SIM No.')),
                    const DataColumn(label: Text('Last 6')),
                    const DataColumn(label: Text('Status')),
                    if (store.canWrite) const DataColumn(label: Text('Actions')),
                  ],
                  rows: [
                    for (var i = 0; i < rows.length; i++)
                      _row(context, rows[i], i + 1, i.isEven),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  DataRow _row(BuildContext context, SimEntry e, int index, bool even) {
    return DataRow(
      color: WidgetStateProperty.all(
        even ? Colors.white : const Color(0xFFF4F7FB),
      ),
      cells: [
        DataCell(
          Text(
            '$index',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        DataCell(Text(e.date)),
        DataCell(Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600))),
        DataCell(_TypeChip(type: e.type)),
        DataCell(_Copyable(e.mobile)),
        DataCell(Text(e.altNumber.isEmpty ? '—' : e.altNumber)),
        DataCell(_FrcChip(frc: e.frc)),
        DataCell(_Copyable(e.simNo)),
        DataCell(Text(e.last6, style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]))),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: BsnlColors.issued,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(e.status, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ),
        if (store.canWrite) DataCell(_RowActions(store: store, entry: e)),
      ],
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({required this.store, required this.entry});
  final SimStore store;
  final SimEntry entry;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Edit',
          visualDensity: VisualDensity.compact,
          onPressed: () => showEntryForm(context, store, existing: entry),
          icon: const Icon(Icons.edit_outlined, size: 20, color: BsnlColors.navy),
        ),
        IconButton(
          tooltip: 'Delete',
          visualDensity: VisualDensity.compact,
          onPressed: () => confirmDeleteEntry(context, store, entry),
          icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFC62828)),
        ),
      ],
    );
  }
}

Future<void> confirmDeleteEntry(
  BuildContext context,
  SimStore store,
  SimEntry entry,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete entry?'),
      content: Text('${entry.name} (${entry.mobile}) delete ho jayegi. Wapas nahi aayegi.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    await store.deleteEntry(entry);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${entry.name} delete ho gayi')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade800),
      );
    }
  }
}

class _FrcChip extends StatelessWidget {
  const _FrcChip({required this.frc});
  final String frc;

  @override
  Widget build(BuildContext context) {
    if (frc.isEmpty) return const Text('—');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: frcChipColor(frc),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(frc, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});
  final SimType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: type.color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        type.label,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

class _Copyable extends StatelessWidget {
  const _Copyable(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Copied $text'), duration: const Duration(seconds: 1)),
        );
      },
      child: Text(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
    );
  }
}

class _MobileTile extends StatelessWidget {
  const _MobileTile({required this.index, required this.e, required this.store});
  final int index;
  final SimEntry e;
  final SimStore store;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: BsnlColors.navy,
        foregroundColor: Colors.white,
        radius: 16,
        child: Text(
          '$index',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
      title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('${e.mobile}  •  FRC ${e.frc.isEmpty ? "—" : e.frc}\n${e.date}  •  ${e.simNo}'),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TypeChip(type: e.type),
          if (store.canWrite)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') {
                  showEntryForm(context, store, existing: e);
                } else if (v == 'delete') {
                  confirmDeleteEntry(context, store, e);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
    );
  }
}
