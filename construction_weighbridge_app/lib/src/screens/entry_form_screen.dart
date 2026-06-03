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
  late final TextEditingController _driver;
  late final TextEditingController _rate;
  late final TextEditingController _amount;
  late final TextEditingController _discount;
  late final TextEditingController _cash;
  late final TextEditingController _bank;
  late final TextEditingController _gpay;
  late final TextEditingController _credit;
  late final TextEditingController _slip;
  late final TextEditingController _extra;
  late final TextEditingController _bodyRemarks;

  String _item = '20mm';
  double _qty = 1;
  DateTime _timeIn = DateTime.now();
  DateTime? _timeOut;
  PaymentType _payment = PaymentType.cash;
  DiscountType _discountType = DiscountType.none;
  bool _companyBody = false;
  bool _extraBody = false;
  bool _isPickup = false;
  bool _historyHit = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.existing;
    _plate = TextEditingController(text: entry?.vehicleNumber ?? widget.initialPlate);
    _party = TextEditingController(text: entry?.partyName ?? '');
    _remarks = TextEditingController(text: entry?.remarks ?? '');
    _driver = TextEditingController(text: entry?.driverName ?? '');
    _rate = TextEditingController(text: entry?.unitRate?.toStringAsFixed(0) ?? '');
    _amount = TextEditingController(text: entry?.netAmount.toStringAsFixed(0) ?? '');
    _discount = TextEditingController(text: entry?.discountValue?.toStringAsFixed(0) ?? '');
    _cash = TextEditingController(text: entry?.cashAmount.toStringAsFixed(0) ?? '');
    _bank = TextEditingController(text: entry?.bankAmount.toStringAsFixed(0) ?? '');
    _gpay = TextEditingController(text: entry?.gpayAmount.toStringAsFixed(0) ?? '');
    _credit = TextEditingController(text: entry?.creditAmount.toStringAsFixed(0) ?? '');
    _slip = TextEditingController(text: entry?.pageSlipNo.toString() ?? '');
    _extra = TextEditingController(text: entry?.extraInfo ?? '');
    _bodyRemarks = TextEditingController(text: entry?.bodyRemarks ?? '');
    if (entry != null) {
      _item = entry.itemType;
      _qty = entry.quantity;
      _timeIn = entry.timeIn;
      _timeOut = entry.timeOut;
      _payment = entry.paymentType;
      _discountType = entry.discountType;
      _companyBody = entry.companyBody;
      _extraBody = entry.extraBody;
      _isPickup = entry.isPickup;
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
      if (vehicle.currentRate > 0) _rate.text = vehicle.currentRate.toStringAsFixed(0);
      _companyBody = vehicle.companyBody;
      _extraBody = vehicle.extraBody;
      _isPickup = vehicle.isPickup;
      _bodyRemarks.text = vehicle.bodyRemarks;
      _historyHit = true;
    }
    if (_rate.text.isEmpty && (state.materialRates[_item] ?? 0) > 0) {
      _rate.text = state.materialRates[_item]!.toStringAsFixed(0);
    }
    _slip.text = slip.toString();
    _recalculate();
    setState(() => _loaded = true);
  }

  void _recalculate() {
    final gross = _grossAmount;
    final discount = _discountAmount(gross);
    final net = (gross - discount).clamp(0, double.infinity);
    _amount.text = net == 0 ? '' : net.toStringAsFixed(0);
    if (_payment == PaymentType.mixed) return;
    _cash.text = _payment == PaymentType.cash && net > 0 ? net.toStringAsFixed(0) : '0';
    _bank.text = _payment == PaymentType.bank && net > 0 ? net.toStringAsFixed(0) : '0';
    _gpay.text = _payment == PaymentType.gpay && net > 0 ? net.toStringAsFixed(0) : '0';
    _credit.text = _payment == PaymentType.credit && net > 0 ? net.toStringAsFixed(0) : '0';
  }

  double get _grossAmount => (double.tryParse(_rate.text) ?? 0) * _qty;

  double _discountAmount(double gross) {
    final value = double.tryParse(_discount.text) ?? 0;
    return switch (_discountType) {
      DiscountType.none => 0,
      DiscountType.percentage => (gross * value / 100).clamp(0, gross).toDouble(),
      DiscountType.fixedAmount => value.clamp(0, gross).toDouble(),
    };
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
    final gross = _grossAmount;
    final discountAmount = _discountAmount(gross);
    final netAmount = (gross - discountAmount).clamp(0, double.infinity).toDouble();
    final cash = double.tryParse(_cash.text) ?? 0;
    final bank = double.tryParse(_bank.text) ?? 0;
    final gpay = double.tryParse(_gpay.text) ?? 0;
    final credit = double.tryParse(_credit.text) ?? 0;
    final paidTotal = cash + bank + gpay + credit;
    if (_qty <= 0) {
      _showError('Quantity must be greater than 0.');
      return;
    }
    if ((double.tryParse(_rate.text) ?? 0) <= 0) {
      _showError('Rate must be greater than 0.');
      return;
    }
    if ((paidTotal - netAmount).abs() > 0.01) {
      _showError('Payment total Rs ${paidTotal.toStringAsFixed(0)} does not match Net Amount Rs ${netAmount.toStringAsFixed(0)}.');
      return;
    }
    final now = DateTime.now();
    final slipNo = int.tryParse(_slip.text) ?? await state.nextSlipNo();
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
      amount: netAmount,
      grossAmount: gross,
      discountType: _discountType,
      discountValue: _discountType == DiscountType.none ? null : double.tryParse(_discount.text),
      discountAmount: discountAmount,
      netAmount: netAmount,
      paymentType: _payment,
      cashAmount: cash,
      bankAmount: bank,
      gpayAmount: gpay,
      creditAmount: credit,
      pageSlipNo: slipNo,
      slipNumber: _slipNumber(_timeIn, slipNo),
      driverName: _driver.text.trim(),
      companyBody: _companyBody,
      extraBody: _extraBody,
      isPickup: _isPickup,
      bodyRemarks: _bodyRemarks.text.trim(),
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.red),
    );
  }

  String _slipNumber(DateTime date, int serial) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return 'DS-$y$m$d-${serial.toString().padLeft(4, '0')}';
  }

  @override
  void dispose() {
    for (final controller in [_plate, _party, _remarks, _driver, _rate, _amount, _discount, _cash, _bank, _gpay, _credit, _slip, _extra, _bodyRemarks]) {
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
                              onSelected: (_) {
                                setState(() {
                                  _item = item;
                                  final rate = state.materialRates[item] ?? 0;
                                  if (rate > 0) _rate.text = rate.toStringAsFixed(0);
                                });
                                _recalculate();
                              },
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
                          child: Text('${_qty.toStringAsFixed(_qty.truncateToDouble() == _qty ? 0 : 1)} CFT',
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
                  DropdownButtonFormField<PaymentType>(
                    value: _payment,
                    decoration: const InputDecoration(labelText: 'Payment Type'),
                    items: const [
                      DropdownMenuItem(value: PaymentType.cash, child: Text('Cash')),
                      DropdownMenuItem(value: PaymentType.bank, child: Text('Bank')),
                      DropdownMenuItem(value: PaymentType.gpay, child: Text('GPay')),
                      DropdownMenuItem(value: PaymentType.credit, child: Text('Credit')),
                      DropdownMenuItem(value: PaymentType.mixed, child: Text('Mixed')),
                    ],
                    onChanged: (value) {
                      setState(() => _payment = value ?? PaymentType.cash);
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
                          decoration: const InputDecoration(labelText: 'Rate / CFT'),
                          onChanged: (_) => _recalculate(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _amount,
                          keyboardType: TextInputType.number,
                          readOnly: true,
                          decoration: const InputDecoration(labelText: 'Net Amount'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<DiscountType>(
                          value: _discountType,
                          decoration: const InputDecoration(labelText: 'Discount'),
                          items: const [
                            DropdownMenuItem(value: DiscountType.none, child: Text('None')),
                            DropdownMenuItem(value: DiscountType.percentage, child: Text('%')),
                            DropdownMenuItem(value: DiscountType.fixedAmount, child: Text('Rs')),
                          ],
                          onChanged: (value) {
                            setState(() => _discountType = value ?? DiscountType.none);
                            _recalculate();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: TextFormField(controller: _discount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Discount Value'), onChanged: (_) => _recalculate())),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: _cash, readOnly: _payment != PaymentType.mixed, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cash'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextFormField(controller: _bank, readOnly: _payment != PaymentType.mixed, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bank'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: _gpay, readOnly: _payment != PaymentType.mixed, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'GPay'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextFormField(controller: _credit, readOnly: _payment != PaymentType.mixed, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Credit'))),
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
                  TextFormField(controller: _driver, decoration: const InputDecoration(labelText: 'Driver Name')),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: SwitchListTile.adaptive(value: _companyBody, onChanged: (value) => setState(() => _companyBody = value), title: const Text('Company Body'))),
                      Expanded(child: SwitchListTile.adaptive(value: _extraBody, onChanged: (value) => setState(() => _extraBody = value), title: const Text('Extra Body'))),
                    ],
                  ),
                  SwitchListTile.adaptive(value: _isPickup, onChanged: (value) => setState(() => _isPickup = value), title: const Text('Pickup Truck')),
                  TextFormField(controller: _bodyRemarks, decoration: const InputDecoration(labelText: 'Body Remarks')),
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
