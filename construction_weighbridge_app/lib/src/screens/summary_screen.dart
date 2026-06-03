import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account_row.dart';
import '../models/daily_totals.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/section_card.dart';

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addAccount(context),
        icon: const Icon(Icons.add),
        label: const Text('Account Row'),
      ),
      body: RefreshIndicator(
        onRefresh: state.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Summary', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                ),
                IconButton.filledTonal(
                  onPressed: state.syncing ? null : () => _sync(context),
                  icon: state.syncing ? const _SmallSpinner() : const Icon(Icons.sync),
                  tooltip: 'Sync to Sheets',
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.ios_share),
                  tooltip: 'Export',
                  onSelected: (value) => _export(context, value),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'excel', child: Text('Export Excel')),
                    PopupMenuItem(value: 'pdf', child: Text('Export PDF')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            _StatsGrid(totals: state.totals),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Item Breakdown',
              child: SizedBox(
                height: 220,
                child: state.totals.itemQty.isEmpty ? const Center(child: Text('No material entries yet')) : _ItemChart(totals: state.totals),
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Accounts',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Closing Rs ${state.closingBalance.toStringAsFixed(0)}',
                    style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w900),
                  ),
                  IconButton(
                    onPressed: () => _editOpeningBalance(context),
                    icon: const Icon(Icons.edit),
                    tooltip: 'Edit opening balance',
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Opening Rs ${state.settings.openingBalance.toStringAsFixed(0)}')),
                      Expanded(child: Text('Expenses Rs ${state.accountDebitTotal.toStringAsFixed(0)}')),
                    ],
                  ),
                  const Divider(height: 24),
                  if (state.accounts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('No account rows added today.'),
                    )
                  else
                    ...state.accounts.map(
                      (row) => _AccountTile(
                        row: row,
                        onEdit: () => _editAccount(context, row),
                        onDelete: () => _deleteAccount(context, row),
                      ),
                    ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(child: Text('Debit Rs ${state.accountDebitTotal.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w800))),
                      Expanded(child: Text('Credit Rs ${state.accountCreditTotal.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w800))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sync(BuildContext context) async {
    try {
      final count = await context.read<AppState>().syncToSheets();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Synced $count rows to Google Sheets'), backgroundColor: AppColors.green));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error'), backgroundColor: AppColors.red));
    }
  }

  Future<void> _export(BuildContext context, String value) async {
    final state = context.read<AppState>();
    final file = value == 'excel' ? await state.exportExcel() : await state.exportPdf();
    await state.exportService.share(file);
  }

  Future<void> _addAccount(BuildContext context) async {
    final state = context.read<AppState>();
    final row = await _accountDialog(context, state.today);
    if (row != null) await state.addAccount(row);
  }

  Future<void> _editOpeningBalance(BuildContext context) async {
    final state = context.read<AppState>();
    final controller = TextEditingController(text: state.settings.openingBalance.toStringAsFixed(0));
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Opening Balance'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, double.tryParse(controller.text) ?? 0),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && context.mounted) {
      await state.saveSettings(state.settings.copyWith(openingBalance: value));
    }
  }

  Future<void> _editAccount(BuildContext context, AccountRow row) async {
    final next = await _accountDialog(context, row.date, existing: row);
    if (next != null && context.mounted) {
      await context.read<AppState>().updateAccount(next);
    }
  }

  Future<void> _deleteAccount(BuildContext context, AccountRow row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account row?'),
        content: Text(row.partyName.isEmpty ? row.category : row.partyName),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AppState>().deleteAccount(row);
    }
  }

  Future<AccountRow?> _accountDialog(
    BuildContext context,
    String date, {
    AccountRow? existing,
  }) async {
    final party = TextEditingController(text: existing?.partyName ?? '');
    final debit = TextEditingController(text: existing?.debit.toStringAsFixed(0) ?? '');
    final credit = TextEditingController(text: existing?.credit.toStringAsFixed(0) ?? '');
    String category = existing?.category ?? 'Expenses';
    final row = await showDialog<AccountRow>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add Account Row' : 'Edit Account Row'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: party, decoration: const InputDecoration(labelText: 'Party name')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: const ['Alc', 'Cash sale', 'Expenses'].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: (value) => category = value ?? category,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: debit, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Debit'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: credit, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Credit'))),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(
                context,
                AccountRow(
                  id: existing?.id,
                  date: date,
                  partyName: party.text.trim(),
                  category: category,
                  debit: double.tryParse(debit.text) ?? 0,
                  credit: double.tryParse(credit.text) ?? 0,
                ),
              );
            },
            child: Text(existing == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
    party.dispose();
    debit.dispose();
    credit.dispose();
    return row;
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.totals});

  final DailyTotals totals;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.65,
      children: [
        _StatCard(icon: Icons.local_shipping, label: 'Total Vehicles', value: '${totals.vehicleCount}', color: AppColors.amber),
        _StatCard(icon: Icons.scale, label: 'Total CFT', value: totals.totalQty.toStringAsFixed(1), color: const Color(0xFF38BDF8)),
        _StatCard(icon: Icons.payments, label: 'Cash Collected', value: 'Rs ${totals.cashTotal.toStringAsFixed(0)}', color: AppColors.green),
        _StatCard(icon: Icons.receipt_long, label: 'Credit Pending', value: 'Rs ${totals.creditTotal.toStringAsFixed(0)}', color: AppColors.red),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.13),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color),
            Text(label, style: const TextStyle(color: Colors.white70)),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _ItemChart extends StatelessWidget {
  const _ItemChart({required this.totals});

  final DailyTotals totals;

  @override
  Widget build(BuildContext context) {
    final entries = totals.itemQty.entries.toList();
    final maxQty = entries.map((e) => e.value).fold<double>(0, (max, value) => value > max ? value : max);
    return BarChart(
      BarChartData(
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(entries[index].key, style: const TextStyle(fontSize: 12)),
                );
              },
            ),
          ),
        ),
        maxY: maxQty == 0 ? 1 : maxQty * 1.25,
        barGroups: entries.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.value,
                color: AppColors.amber,
                width: 22,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.row,
    required this.onEdit,
    required this.onDelete,
  });

  final AccountRow row;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(row.partyName.isEmpty ? row.category : row.partyName),
      subtitle: Text(row.category),
      onTap: onEdit,
      onLongPress: onDelete,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('Dr Rs ${row.debit.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.red)),
          Text('Cr Rs ${row.credit.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.green)),
        ],
      ),
    );
  }
}

class _SmallSpinner extends StatelessWidget {
  const _SmallSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
