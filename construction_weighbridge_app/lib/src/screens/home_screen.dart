import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/status_chip.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onScan,
    required this.onManual,
  });

  final VoidCallback onScan;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final date = DateFormat('dd MMM yyyy').format(DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(date, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      state.settings.businessName,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: '${state.totals.vehicleCount} vehicles',
                color: AppColors.amber,
                icon: Icons.local_shipping,
              ),
            ],
          ),
          const Spacer(),
          StatusChip(
            label: '${state.totals.vehicleCount} vehicles today | Rs ${state.totals.cashTotal.toStringAsFixed(0)} cash',
            color: AppColors.green,
            icon: Icons.sync,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.36,
            child: FilledButton.icon(
              onPressed: onScan,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              icon: const Icon(Icons.photo_camera, size: 44),
              label: const Text('SCAN PLATE'),
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onManual,
            icon: const Icon(Icons.keyboard),
            label: const Text('Enter Manually', style: TextStyle(fontSize: 18)),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: StatusChip(
                  label: state.unsyncedCount == 0 ? 'Synced' : '${state.unsyncedCount} unsynced',
                  color: state.unsyncedCount == 0 ? AppColors.green : AppColors.red,
                  icon: state.unsyncedCount == 0 ? Icons.check_circle : Icons.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatusChip(
                  label: state.syncing ? 'Syncing' : 'Ready',
                  color: state.syncing ? AppColors.amber : AppColors.green,
                  icon: state.syncing ? Icons.sync : Icons.check_circle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
