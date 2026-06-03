import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/entry.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class HistorySearchScreen extends StatefulWidget {
  const HistorySearchScreen({super.key, required this.onEdit});

  final void Function(Entry entry) onEdit;

  @override
  State<HistorySearchScreen> createState() => _HistorySearchScreenState();
}

class _HistorySearchScreenState extends State<HistorySearchScreen> {
  final _query = TextEditingController();
  DateTime? _from;
  DateTime? _to;
  List<Entry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    final results = await context.read<AppState>().database.searchEntries(
          query: _query.text,
          from: _from,
          to: _to == null ? null : DateTime(_to!.year, _to!.month, _to!.day, 23, 59, 59),
        );
    if (!mounted) return;
    setState(() {
      _entries = results;
      _loading = false;
    });
  }

  Future<void> _pick({required bool from}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? (_from ?? now) : (_to ?? now),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
    await _search();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _query,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Vehicle no or party name',
                    suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.arrow_forward)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pick(from: true),
                        icon: const Icon(Icons.date_range),
                        label: Text(_from == null ? 'From date' : Entry.dateFormat.format(_from!)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pick(from: false),
                        icon: const Icon(Icons.event),
                        label: Text(_to == null ? 'To date' : Entry.dateFormat.format(_to!)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                    ? const Center(child: Text('No matching entries'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: _entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final entry = _entries[index];
                          return Card(
                            child: ListTile(
                              minVerticalPadding: 14,
                              title: Text(entry.vehicleNumber, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: 20)),
                              subtitle: Text('${entry.date} | ${entry.partyName} | ${entry.itemType} ${entry.quantity} CFT'),
                              trailing: Text(
                                _paymentLabel(entry.paymentType),
                                style: TextStyle(color: entry.paymentType == PaymentType.credit ? AppColors.red : AppColors.green, fontWeight: FontWeight.w900),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                widget.onEdit(entry);
                              },
                              onLongPress: () => _delete(entry),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _paymentLabel(PaymentType type) {
    return switch (type) {
      PaymentType.cash => 'CASH',
      PaymentType.bank => 'BANK',
      PaymentType.gpay => 'GPAY',
      PaymentType.credit => 'CREDIT',
      PaymentType.mixed => 'MIXED',
    };
  }

  Future<void> _delete(Entry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text('Delete ${entry.vehicleNumber} from ${entry.date}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<AppState>().deleteEntry(entry);
      await _search();
    }
  }
}
