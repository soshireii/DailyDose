import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../core/utils/time_utils.dart';
import '../../models/dose_slot.dart';
import '../../models/intake_log.dart';
import '../widgets/intake_actions.dart';

class DoseTile extends StatelessWidget {
  const DoseTile({super.key, required this.slot, this.interactive = true});

  final DoseSlot slot;

  /// False for future dates, where a dose can't be taken or skipped yet.
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final medicine = slot.medicine;
    final state = slot.stateAt(DateTime.now());
    final log = slot.log;

    final (label, color, icon) = switch (state) {
      DoseState.upcoming => ('Upcoming', AppColors.neutralGray, Icons.schedule),
      DoseState.due => (
        'Due now',
        AppColors.statusPending,
        Icons.notifications_active_outlined,
      ),
      DoseState.overdue => (
        'Missed',
        AppColors.statusMissed,
        Icons.error_outline,
      ),
      DoseState.taken => ('Taken', AppColors.statusTaken, Icons.check_circle),
      DoseState.skipped => (
        'Skipped',
        AppColors.statusMissed,
        Icons.remove_circle_outline,
      ),
    };

    final strength = medicine.strength.isEmpty ? '' : ' (${medicine.strength})';

    // A dose that's gone unlogged for over an hour is locked: no Take/Skip,
    // so past adherence can't be edited after the fact. Already-logged
    // entries can still be undone (that's fixing a mistake, not backdating).
    final canAct = log == null && interactive && state != DoseState.overdue;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    TimeUtils.format(context, slot.scheduledAt),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicine.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatDose(medicine.dosePerIntake, medicine.unit)}$strength',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 15, color: color),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (log != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      log.status == IntakeStatus.taken
                          ? 'Logged at ${TimeUtils.format(context, log.takenAt)}'
                          : 'Skipped',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (interactive)
                    TextButton(
                      onPressed: () => IntakeActions.undo(context, log),
                      child: const Text('Undo'),
                    ),
                ],
              )
            else if (state == DoseState.overdue)
              Text(
                'This dose went unlogged and can no longer be marked taken or skipped.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else if (canAct)
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => IntakeActions.take(
                        context,
                        medicine,
                        scheduledFor: slot.scheduledAt,
                      ),
                      icon: const Icon(Icons.check),
                      label: const Text('Take'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () =>
                        IntakeActions.skip(context, medicine, slot.scheduledAt),
                    child: const Text('Skip'),
                  ),
                ],
              )
            else
              Text(
                'Scheduled — you can log it once the day arrives.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
