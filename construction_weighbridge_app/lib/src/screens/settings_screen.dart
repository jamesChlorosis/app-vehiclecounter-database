import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/settings.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/section_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _business;
  late final TextEditingController _sales;
  late final TextEditingController _sheet;
  late final TextEditingController _opening;

  @override
  void initState() {
    super.initState();
    final settings = context.read<AppState>().settings;
    _business = TextEditingController(text: settings.businessName);
    _sales = TextEditingController(text: settings.salesInCharge);
    _sheet = TextEditingController(text: settings.googleSheetId);
    _opening = TextEditingController(text: settings.openingBalance.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _business.dispose();
    _sales.dispose();
    _sheet.dispose();
    _opening.dispose();
    super.dispose();
  }

  Future<void> _save(bool darkMode) async {
    final next = AppSettings(
      businessName: _business.text.trim().isEmpty ? 'Quarry Gate' : _business.text.trim(),
      salesInCharge: _sales.text.trim(),
      googleSheetId: _sheet.text.trim(),
      darkMode: darkMode,
      openingBalance: double.tryParse(_opening.text) ?? 0,
    );
    await context.read<AppState>().saveSettings(next);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved'), backgroundColor: AppColors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Business',
          child: Column(
            children: [
              TextField(controller: _business, decoration: const InputDecoration(labelText: 'Business name')),
              const SizedBox(height: 12),
              TextField(controller: _sales, decoration: const InputDecoration(labelText: 'Sales In Charge name')),
              const SizedBox(height: 12),
              TextField(controller: _opening, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Opening Balance')),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: state.settings.darkMode,
                onChanged: (value) => _save(value),
                title: const Text('Dark mode'),
                subtitle: const Text('Recommended for outdoor use'),
              ),
              FilledButton.icon(
                onPressed: () => _save(state.settings.darkMode),
                icon: const Icon(Icons.save),
                label: const Text('Save Settings'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Google Sheets',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _sheet,
                decoration: const InputDecoration(
                  labelText: 'Google Sheets ID or link',
                  prefixIcon: Icon(Icons.table),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Enable Google Sheets API, create Android OAuth credentials, then paste the spreadsheet link here.',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ManageList(
          title: 'Item Types',
          values: state.itemTypes,
          onAdd: state.addItemType,
          onRemove: state.removeItemType,
        ),
        const SizedBox(height: 12),
        _ManageList(
          title: 'Party Names',
          values: state.partyNames,
          onAdd: state.addPartyName,
          onRemove: state.removePartyName,
        ),
      ],
    );
  }
}

class _ManageList extends StatelessWidget {
  const _ManageList({
    required this.title,
    required this.values,
    required this.onAdd,
    required this.onRemove,
  });

  final String title;
  final List<String> values;
  final Future<void> Function(String value) onAdd;
  final Future<void> Function(String value) onRemove;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      trailing: IconButton.filledTonal(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
      ),
      child: values.isEmpty
          ? const Text('No saved values yet.')
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: values.map((value) {
                return InputChip(
                  label: Text(value),
                  onDeleted: () => onRemove(value),
                );
              }).toList(),
            ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add $title'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Add')),
        ],
      ),
    );
    controller.dispose();
    if (value != null) await onAdd(value);
  }
}
