import 'package:flutter/material.dart';

import '../models/entry.dart';
import 'entry_form_screen.dart';
import 'home_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';
import 'boulder_purchase_screen.dart';
import 'summary_screen.dart';
import 'todays_log_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  Future<void> _scan() async {
    final plate = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (!mounted) return;
    if (plate != null && plate.isNotEmpty) {
      await _openEntryForm(plate);
    }
  }

  Future<void> _openEntryForm(String plate, {Entry? entry}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EntryFormScreen(initialPlate: plate, existing: entry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onScan: _scan, onManual: () => _openEntryForm('')),
      TodaysLogScreen(onEdit: (entry) => _openEntryForm(entry.vehicleNumber, entry: entry)),
      const BoulderPurchaseScreen(),
      const SummaryScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: SafeArea(child: screens[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.move_to_inbox_outlined), selectedIcon: Icon(Icons.move_to_inbox), label: 'Boulder'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Summary'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
