import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/format_utils.dart';
import '../../core/utils/time_utils.dart';
import '../../models/intake_log.dart';
import '../../viewmodels/intake_viewmodel.dart';
import '../widgets/account_button.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_banner.dart';
import '../widgets/intake_actions.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<IntakeViewModel>();
    final theme = Theme.of(context);
    final now = DateTime.now();
    final groups = vm.groupedLogs;
    final options = vm.filterOptions;

    Widget body;
    if (vm.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (options.isEmpty) {
      body = const EmptyState(
        icon: Icons.history,
        title: 'No history yet',
        message:
            'Every dose you take or skip is recorded here, so you always know what you took and when.',
      );
    } else {
      body = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (vm.error != null) ...[
                ErrorBanner(message: vm.error!, onDismiss: vm.clearError),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<String?>(
                key: ValueKey(vm.filterMedicineId),
                initialValue: vm.filterMedicineId,
                decoration: const InputDecoration(
                  labelText: 'Show',
                  prefixIcon: Icon(Icons.filter_list),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All medicines'),
                  ),
                  for (final e in options.entries)
                    DropdownMenuItem<String?>(
                      value: e.key,
                      child: Text(e.value, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: vm.setFilter,
              ),
              for (final group in groups) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                  child: Text(
                    TimeUtils.dayLabel(group.key, now),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                for (final log in group.value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _LogTile(log: log),
                  ),
              ],
              if (groups.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: EmptyState(
                    icon: Icons.search_off,
                    title: 'Nothing to show',
                    message: 'No entries for this medicine yet.',
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: const [AccountButton()],
      ),
      body: body,
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.log});

  final IntakeLog log;

  Future<void> _confirmRemove(BuildContext context) async {
    final taken = log.status == IntakeStatus.taken;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this entry?'),
        content: Text(taken
            ? 'The ${formatDose(log.deducted, log.unit)} will be added back to your stock.'
            : 'The dose will show as pending again on Today.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await IntakeActions.undo(context, log);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final taken = log.status == IntakeStatus.taken;
    final time = TimeUtils.format(context, log.takenAt);
    final scheduled = log.scheduledFor == null
        ? null
        : TimeUtils.format(context, log.scheduledFor!);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              taken ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          foregroundColor:
              taken ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          child: Icon(taken ? Icons.check : Icons.skip_next),
        ),
        title: Text(
          log.medicineName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text([
          taken ? formatDose(log.amount, log.unit) : 'Skipped',
          'at $time',
          if (scheduled != null) 'scheduled $scheduled',
        ].join(' • ')),
        trailing: IconButton(
          tooltip: 'Remove entry',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _confirmRemove(context),
        ),
      ),
    );
  }
}
