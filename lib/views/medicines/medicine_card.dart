import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/utils/format_utils.dart';
import '../../core/utils/time_utils.dart';
import '../../models/medicine.dart';
import '../../viewmodels/medicine_viewmodel.dart';
import '../widgets/intake_actions.dart';
import 'medicine_form_screen.dart';

class MedicineCard extends StatelessWidget {
  const MedicineCard({super.key, required this.medicine});

  final Medicine medicine;

  void _edit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MedicineFormScreen(medicine: medicine),
      ),
    );
  }

  /// Opens the Add form pre-filled with this medicine's details. It's a
  /// separate, unsaved copy (blank id, new notification ids, "today" as the
  /// created date) until the user taps Save.
  void _duplicate(BuildContext context) {
    final copy = medicine.copyWith(
      id: '',
      name: '${medicine.name} (Copy)',
      notificationBase: Random().nextInt(1000000) + 1,
      createdAt: DateTime.now(),
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MedicineFormScreen(medicine: copy),
      ),
    );
  }

  Future<void> _refill(BuildContext context) async {
    final amount = await showDialog<double>(
      context: context,
      builder: (_) => _RefillDialog(medicine: medicine),
    );
    if (amount == null || !context.mounted) return;
    final vm = context.read<MedicineViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await vm.refill(medicine, amount);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Added ${formatDose(amount, medicine.unit)} to ${medicine.name}.'
              : (vm.error ?? 'Could not update the stock.'),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${medicine.name}?'),
        content: const Text(
          'Its reminders will be removed. Past entries stay in your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final vm = context.read<MedicineViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await vm.deleteMedicine(medicine);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '${medicine.name} deleted.'
              : (vm.error ?? 'Could not delete this medicine.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final m = medicine;
    final low = m.isLowStock;
    final daysLeft = m.daysRemaining;
    final subtitle = [
      if (m.strength.isNotEmpty) m.strength,
      '${formatDose(m.dosePerIntake, m.unit)} per dose',
    ].join(' • ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _edit(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  m.hasImage
                      ? CircleAvatar(
                          radius: 20,
                          backgroundImage: MemoryImage(
                            base64Decode(m.imageBase64),
                          ),
                        )
                      : CircleAvatar(
                          backgroundColor: low
                              ? scheme.errorContainer
                              : scheme.primaryContainer,
                          foregroundColor: low
                              ? scheme.onErrorContainer
                              : scheme.onPrimaryContainer,
                          child: const Icon(Icons.medication_outlined),
                        ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _edit(context);
                        case 'duplicate':
                          _duplicate(context);
                        case 'refill':
                          _refill(context);
                        case 'delete':
                          _delete(context);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(
                        value: 'duplicate',
                        child: Text('Duplicate'),
                      ),
                      PopupMenuItem(value: 'refill', child: Text('Add stock')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill(
                    icon: low
                        ? Icons.warning_amber_rounded
                        : Icons.inventory_2_outlined,
                    text: m.isOutOfStock
                        ? 'Out of stock'
                        : '${formatDose(m.quantity, m.unit)} left',
                    foreground: low
                        ? scheme.onErrorContainer
                        : scheme.onSurfaceVariant,
                    background: low
                        ? scheme.errorContainer
                        : scheme.surfaceContainerHighest,
                  ),
                  if (daysLeft != null && !m.isOutOfStock)
                    _Pill(
                      icon: Icons.hourglass_bottom,
                      text: daysLeft < 1
                          ? 'Less than a day'
                          : '~${daysLeft.floor()} ${daysLeft.floor() == 1 ? 'day' : 'days'} left',
                      foreground: scheme.onSurfaceVariant,
                      background: scheme.surfaceContainerHighest,
                    ),
                  _Pill(
                    icon: m.remindersEnabled && m.hasSchedule
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                    text: m.hasSchedule ? describeDays(m.days) : 'As needed',
                    foreground: scheme.onSurfaceVariant,
                    background: scheme.surfaceContainerHighest,
                  ),
                ],
              ),
              if (m.hasSchedule) ...[
                const SizedBox(height: 8),
                Text(
                  m.scheduleTimes
                      .map((t) => TimeUtils.formatHm(context, t))
                      .join('  •  '),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => IntakeActions.take(context, m),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Take now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.text,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final String text;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _RefillDialog extends StatefulWidget {
  const _RefillDialog({required this.medicine});

  final Medicine medicine;

  @override
  State<_RefillDialog> createState() => _RefillDialogState();
}

class _RefillDialogState extends State<_RefillDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      double.parse(_controller.text.trim().replaceAll(',', '.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.medicine;
    return AlertDialog(
      title: Text('Add stock to ${m.name}'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Amount to add',
            suffixText: Units.label(m.unit, 2),
          ),
          onFieldSubmitted: (_) => _submit(),
          validator: (v) {
            final value = double.tryParse(
              (v ?? '').trim().replaceAll(',', '.'),
            );
            if (value == null || value <= 0) return 'Enter a number above 0.';
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add stock')),
      ],
    );
  }
}
