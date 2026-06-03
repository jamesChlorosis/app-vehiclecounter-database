import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/entry.dart';
import '../models/vehicle.dart';
import '../services/database_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/section_card.dart';

class EntryFormScreen extends StatefulWidget {
  const EntryFormScreen({
    super.key,
    required this.initialPlate,
    this.existing,
  });

  final String initialPlate;
  final Entry? existing;

  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends State<EntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _plate;
  late final TextEditingController _party;
  late final TextEditingController _remarks;
  late final TextEditingController _rate;
  late final TextEditingController _amount;
  late final TextEditingController _cash;
  late final TextEditingController _credit;
  late final TextEditingController _slip;
  late final TextEditingController _extra;

  String _item = '20mm';
  double _qty = 1;
  DateTime _timeIn = DateTime.now();
  DateTime? _timeOut;
  PaymentType _payment = PaymentType.cash;
  bool _historyHit = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.existing;
    _plate = TextEditingController(text: entry?.vehicleNumber ?? widget.initialPlate);
    _party = TextEditingController(text: entry?.partyName ?? '');
    _remarks = TextEditingController(text: entry?.remarks ?? '');
    _rate = TextEditingController(text: entry?.unitRate?.toStringAsFixed(0) ?? '');
    _amount = TextEditingController(text: entry?.amount.toStringAsFixed(0) ?? '');
    _cash = TextEditingController(text: entry?.cashAmount.toStringAsFixed(0) ?? '');
    _credit = TextEditingController(text: entry?.creditAmount.toStringAsFixed(0) ?? '');
    _slip = TextEditingController(text: entry?.pageSlipNo.toString() ?? '');
    _extra = TextEditingController(text: entry?.extraInfo ?? '');
    if (entry != null) {
      _item = entry.itemType;
      _qty = entry.quantity;
      _timeIn = entry.timeIn;
      _timeOut = entry.timeOut;
      _payment = entry.paymentType;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDefaults());
  }

  Future<void> _loadDefaults() async {
    final state = context.read<AppState>();
    if (widget.existing != null) {
      setState(() => _loaded = true);
      return;
    }
    final slip = await state.nextSlipNo();
    Vehicle? vehicle;
    if (_plate.text.trim().isNotEmpty) {
      vehicle = await state.findVehicle(_plate.text);
    }
    if (!mounted) return;
    if (vehicle != null) {
      _party.text = vehicle.partyName;
      _item = vehicle.defaultItem;
      _qty = vehicle.lastQty;
      _historyHit = true;
    }
    _slip.text = slip.toString();
    _recalculate();
    setState(() => _loaded = true);
  }

  void _recalculate() {
    final rate = double.tryParse(_rate.text);
    final computed = rate == null ? double.tryParse(_amount.text) ?? 0 : rate * _qty;
    _amount.text = computed == 0 ? '' : computed.toStringAsFixed(0);
    if (_payment == PaymentType.cash) {
      _cash.text = computed == 0 ? '' : computed.toStringAsFixed(0);
      _credit.text = '0';
    } else {
      _cash.text = '0';
      _credit.text = computed == 0 ? '' : computed.toStringAsFixed(0);
    }
  }

  Future<void> _pickTime({required bool out}) async {
    final base = out ? (_timeOut ?? DateTime.now()) : _timeIn;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (picked == null) return;
    final next = DateTime(base.year, base.month, base.day, picked.hour, picked.minute);
    setState(() {
      if (out) {
        _timeOut = next;
      } else {
        _timeIn = next;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final state = context.read<AppState>();
    final amount = double.tryParse(_amount.text) ?? 0;
    final now = DateTime.now();
    final entry = Entry(
      id: widget.existing?.id,
      vehicleNumber: DatabaseService.normalizePlate(_plate.text),
      partyName: _party.text.trim(),
      remarks: _remarks.text.trim(),
      itemType: _item,
      quantity: _qty,
      timeIn: _timeIn,
      timeOut: _timeOut,
      unitRate: double.tryParse(_rate.text),
      amount: amount,
      paymentType: _payment,
      cashAmount: double.tryParse(_cash.text) ?? (_payment == PaymentType.cash ? amount : 0),
      creditAmount: double.tryParse(_credit.text) ?? (_payment == PaymentType.credit ? amount : 0),
      pageSlipNo: int.tryParse(_slip.text) ?? await state.nextSlipNo(),
      extraInfo: _extra.text.trim(),
      date: Entry.dateFormat.format(_timeIn),
      createdAt: widget.existing?.createdAt ?? now,
      synced: false,
    );
    await state.saveEntry(entry);
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entry saved'), backgroundColor: AppColors.green),
    );
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    for (final controller in [_plate, _party, _remarks, _rate, _amount, _cash, _credit, _slip, _extra]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'New Entry' : 'Edit Entry')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(
              title: 'Vehicle',
              trailing: _historyHit
                  ? const Icon(Icons.check_circle, color: AppColors.green)
                  : const Icon(Icons.edit, color: AppColors.amber),
              child: Column(
                children: [
                  TextFormField(
                    controller: _plate,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9 -]')),
                      TextInputFormatter.withFunction((oldValue, newValue) => newValue.copyWith(text: newValue.text.toUpperCase())),
                    ],
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 28, letterSpacing: 2, fontWeight: FontWeight.w900),
                    decoration: const InputDecoration(labelText: 'Vehicle Number'),
                    validator: (value) => DatabaseService.normalizePlate(value ?? '').isEmpty ? 'Enter vehicle number' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _party,
                    decoration: const InputDecoration(labelText: 'Party Name', suffixIcon: Icon(Icons.edit)),
                    validator: (value) => (value ?? '').trim().isEmpty ? 'Enter party name' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Material',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ...state.itemTypes.map((item) {
                          final selected = item == _item;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              selected: selected,
                              selectedColor: AppColors.amber,
                              checkmarkColor: Colors.black,
                              label: Text(item, style: TextStyle(color: selected ? Colors.black : Colors.white)),
                              onSelected: (_) => setState(() => _item = item),
                            ),
                          );
                        }),
                        ActionChip(
                          avatar: const Icon(Icons.add),
                          label: const Text('Custom'),
                          onPressed: _addCustomItem,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _StepperButton(
                        icon: Icons.remove,
                        onTap: () {
                          setState(() => _qty = (_qty - 0.5).clamp(0, 9999).toDouble());
                          _recalculate();
                        },
                      ),
                      Expanded(
                        child: Center(
                          child: Text('${_qty.toStringAsFixed(_qty.truncateToDouble() == _qty ? 0 : 1)} tons',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                        ),
                      ),
                      _StepperButton(
                        icon: Icons.add,
                        onTap: () {
                          setState(() => _qty += 0.5);
                          _recalculate();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Payment',
              child: Column(
                children: [
                  SegmentedButton<PaymentType>(
                    segments: const [
                      ButtonSegment(value: PaymentType.cash, label: Text('CASH'), icon: Icon(Icons.payments)),
                      ButtonSegment(value: PaymentType.credit, label: Text('CREDIT'), icon: Icon(Icons.receipt_long)),
                    ],
                    selected: {_payment},
                    onSelectionChanged: (value) {
                      setState(() => _payment = value.first);
                      _recalculate();
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _rate,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Unit Rate'),
                          onChanged: (_) => _recalculate(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _amount,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Amount'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: _cash, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cash Amount'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextFormField(controller: _credit, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Credit Amount'))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Time and Notes',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickTime(out: false),
                          icon: const Icon(Icons.schedule),
                          label: Text('Time In ${Entry.timeFormat.format(_timeIn)}'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickTime(out: true),
                          icon: const Icon(Icons.logout),
                          label: Text(_timeOut == null ? 'Set on exit' : 'Out ${Entry.timeFormat.format(_timeOut!)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(controller: _remarks, decoration: const InputDecoration(labelText: 'Remarks / Notes')),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: _slip, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Page / Slip No'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextFormField(controller: _extra, decoration: const InputDecoration(labelText: 'Extra info'))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: state.busy ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(60),
                backgroundColor: AppColors.green,
                foregroundColor: Colors.black,
                textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              icon: const Icon(Icons.check_circle),
              label: Text(state.busy ? 'Saving...' : 'SAVE ENTRY'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addCustomItem() async {
    final controller = TextEditingController();
    final item = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Material'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Material name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Add')),
        ],
      ),
    );
    controller.dispose();
    final cleaned = item?.trim();
    if (cleaned == null || cleaned.isEmpty || !mounted) return;
    await context.read<AppState>().addItemType(cleaned);
    setState(() => _item = cleaned);
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: onTap,
      icon: Icon(icon),
      style: IconButton.styleFrom(minimumSize: const Size(56, 56), backgroundColor: AppColors.amber, foregroundColor: Colors.black),
    );
  }
}
