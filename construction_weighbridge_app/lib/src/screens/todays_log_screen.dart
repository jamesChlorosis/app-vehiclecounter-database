import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/entry.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/status_chip.dart';
import 'history_search_screen.dart';

class TodaysLogScreen extends StatefulWidget {
  const TodaysLogScreen({super.key, required this.onEdit});

  final void Function(Entry entry) onEdit;

  @override
  State<TodaysLogScreen> createState() => _TodaysLogScreenState();
}

class _TodaysLogScreenState extends State<TodaysLogScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final query = _search.text.trim().toUpperCase();
    final entries = state.todayEntries.where((entry) {
      if (query.isEmpty) return true;
      return entry.vehicleNumber.contains(query) || entry.partyName.toUpperCase().contains(query);
    }).toList();
    return RefreshIndicator(
      onRefresh: state.refresh,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text("Today's Log", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => HistorySearchScreen(onEdit: widget.onEdit),
                        ),
                      ),
                      icon: const Icon(Icons.manage_search),
                      tooltip: 'History search',
                    ),
                    const SizedBox(width: 8),
                    StatusChip(label: '${state.totals.vehicleCount} vehicles', color: AppColors.amber, icon: Icons.local_shipping),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search plate or party',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? const _EmptyLog()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 86),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _EntryCard(
                        entry: entry,
                        onTap: () => widget.onEdit(entry),
                        onDelete: () => _confirmDelete(context, entry),
                      ).animate().fadeIn(duration: 180.ms).slideY(begin: 0.08, end: 0);
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                Expanded(child: Text('Qty ${state.totals.totalQty.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.w800))),
                Expanded(child: Text('Cash Rs ${state.totals.cashTotal.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w800))),
                Expanded(child: Text('Credit Rs ${state.totals.creditTotal.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.amber, fontWeight: FontWeight.w800))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Entry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text('Delete ${entry.vehicleNumber} from today log?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AppState>().deleteEntry(entry);
    }
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  final Entry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isCash = entry.paymentType == PaymentType.cash;
    return InkWell(
      onTap: onTap,
      onLongPress: () => _menu(context),
      borderRadius: BorderRadius.circular(8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.vehicleNumber, style: const TextStyle(fontFamily: 'monospace', fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
                        const SizedBox(height: 4),
                        Text(entry.partyName, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusChip(label: entry.itemType, color: _itemColor(entry.itemType)),
                      const SizedBox(height: 6),
                      Text('${entry.quantity.toStringAsFixed(1)} CFT', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(Entry.timeFormat.format(entry.timeIn))),
                    Expanded(child: Text('Rs ${entry.netAmount.toStringAsFixed(0)}')),
                    StatusChip(
                      label: entry.synced ? 'SYNCED' : 'LOCAL',
                      color: entry.synced ? AppColors.green : AppColors.red,
                    ),
                    const SizedBox(width: 8),
                    StatusChip(
                      label: _paymentLabel(entry),
                      color: isCash ? AppColors.green : entry.paymentType == PaymentType.credit ? AppColors.red : AppColors.amber,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _menu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.edit), title: const Text('Edit'), onTap: () {
              Navigator.pop(context);
              onTap();
            }),
            ListTile(leading: const Icon(Icons.delete), title: const Text('Delete'), onTap: () {
              Navigator.pop(context);
              onDelete();
            }),
          ],
        ),
      ),
    );
  }

  Color _itemColor(String item) {
    return switch (item) {
      '40mm' => const Color(0xFF38BDF8),
      '20mm' => AppColors.amber,
      '6mm' => const Color(0xFF2DD4BF),
      'Dust' => const Color(0xFFF87171),
      'M-Sand' => const Color(0xFFFACC15),
      'P-Sand' => const Color(0xFFFB923C),
      _ => const Color(0xFFE2E8F0),
    };
  }

  String _paymentLabel(Entry entry) {
    return switch (entry.paymentType) {
      PaymentType.cash => 'CASH',
      PaymentType.bank => 'BANK',
      PaymentType.gpay => 'GPAY',
      PaymentType.credit => 'CREDIT',
      PaymentType.mixed => 'MIXED',
    };
  }
}

class _EmptyLog extends StatelessWidget {
  const _EmptyLog();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.inbox_outlined, size: 80, color: AppColors.amber.withOpacity(0.65)),
        const SizedBox(height: 16),
        Text(
          'No entries yet',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'Scanned and manual vehicle entries will appear here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
      ],
    );
  }
}
