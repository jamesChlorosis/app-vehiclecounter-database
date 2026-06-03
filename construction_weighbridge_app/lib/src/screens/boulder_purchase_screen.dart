import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/entry.dart';
import '../models/purchase_entry.dart';
import '../services/database_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/section_card.dart';

class BoulderPurchaseScreen extends StatefulWidget {
  const BoulderPurchaseScreen({super.key});

  @override
  State<BoulderPurchaseScreen> createState() => _BoulderPurchaseScreenState();
}

class _BoulderPurchaseScreenState extends State<BoulderPurchaseScreen> {
  final _vehicle = TextEditingController();
  final _supplier = TextEditingController();
  final _material = TextEditingController(text: 'Boulder');
  final _qty = TextEditingController();
  final _rate = TextEditingController();
  final _amount = TextEditingController();
  final _remarks = TextEditingController();
  DateTime _time = DateTime.now();

  @override
  void dispose() {
    for (final controller in [_vehicle, _supplier, _material, _qty, _rate, _amount, _remarks]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _compute() {
    final qty = double.tryParse(_qty.text) ?? 0;
    final rate = double.tryParse(_rate.text) ?? 0;
    if (qty > 0 && rate > 0) {
      _amount.text = (qty * rate).toStringAsFixed(0);
    }
  }

  Future<void> _save() async {
    final vehicle = DatabaseService.normalizePlate(_vehicle.text);
    final supplier = _supplier.text.trim();
    final qty = double.tryParse(_qty.text) ?? 0;
    final rate = double.tryParse(_rate.text) ?? 0;
    final amount = double.tryParse(_amount.text) ?? 0;
    if (vehicle.isEmpty) {
      _error('Vehicle Number is required.');
      return;
    }
    if (supplier.isEmpty) {
      _error('Supplier Name is required.');
      return;
    }
    if (qty <= 0 || rate <= 0) {
      _error('Quantity and Rate must be greater than 0.');
      return;
    }
    if ((qty * rate - amount).abs() > 0.01) {
      _error('Amount must equal Quantity x Rate.');
      return;
    }
    await context.read<AppState>().savePurchaseEntry(
          PurchaseEntry(
            date: Entry.dateFormat.format(_time),
            time: _time,
            vehicleNumber: vehicle,
            supplierName: supplier,
            material: _material.text.trim().isEmpty ? 'Boulder' : _material.text.trim(),
            quantity: qty,
            rate: rate,
            amount: amount,
            remarks: _remarks.text.trim(),
            createdAt: DateTime.now(),
          ),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Boulder purchase saved'), backgroundColor: AppColors.green),
    );
    _vehicle.clear();
    _qty.clear();
    _amount.clear();
    _remarks.clear();
    setState(() => _time = DateTime.now());
  }

  void _error(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final totalQty = state.todayPurchases.fold<double>(0, (sum, row) => sum + row.quantity);
    final totalAmount = state.todayPurchases.fold<double>(0, (sum, row) => sum + row.amount);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      children: [
        Text('OUR PURCHASE (BOULDER)', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Boulder Purchase Entry',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: TextField(controller: _vehicle, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Vehicle Number'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _supplier, decoration: const InputDecoration(labelText: 'Supplier Name'))),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: _material, decoration: const InputDecoration(labelText: 'Material'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity (CFT)'), onChanged: (_) => _compute())),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: _rate, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rate'), onChanged: (_) => _compute())),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount'))),
                ],
              ),
              const SizedBox(height: 10),
              TextField(controller: _remarks, decoration: const InputDecoration(labelText: 'Remarks')),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _save,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), backgroundColor: AppColors.red),
                icon: const Icon(Icons.save),
                label: const Text('Save Boulder Purchase'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Today Boulder Register',
          trailing: Text('${totalQty.toStringAsFixed(1)} CFT | Rs ${totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.red)),
          child: Column(
            children: state.todayPurchases.isEmpty
                ? [const Padding(padding: EdgeInsets.all(18), child: Text('No boulder purchases today.'))]
                : state.todayPurchases.map((row) {
                    return Card(
                      color: AppColors.red.withOpacity(0.12),
                      child: ListTile(
                        title: Text(row.vehicleNumber, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900)),
                        subtitle: Text('${row.supplierName} | ${row.material} | ${row.quantity.toStringAsFixed(1)} CFT'),
                        trailing: Text('Rs ${row.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    );
                  }).toList(),
          ),
        ),
      ],
    );
  }
}
