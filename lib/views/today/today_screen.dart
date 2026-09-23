import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../core/utils/time_utils.dart';
import '../../models/dose_slot.dart';
import '../../models/medicine.dart';
import '../../viewmodels/intake_viewmodel.dart';
import '../../viewmodels/medicine_viewmodel.dart';
import '../medicines/medicine_form_screen.dart';
import '../widgets/account_button.dart';
import '../widgets/adaptive_list.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_banner.dart';
import 'dose_tile.dart';
import 'week_strip.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  Timer? _ticker;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = TimeUtils.dateOnly(DateTime.now());
    // Re-evaluate "due" / "overdue" as time passes.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _addMedicine() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const MedicineFormScreen()));
  }

  void _selectDate(DateTime date) => setState(() => _selectedDate = date);

  @override
  Widget build(BuildContext context) {
    final medicines = context.watch<MedicineViewModel>();
    final intake = context.watch<IntakeViewModel>();
    final now = DateTime.now();
    final today = TimeUtils.dateOnly(now);
    final isToday = _selectedDate.isAtSameMomentAs(today);
    final isFuture = _selectedDate.isAfter(today);
    final doses = intake.dosesForDate(_selectedDate, now: now);
    final lowStock = isToday ? medicines.lowStock : const <Medicine>[];
    final streak = intake.currentStreak(now: now);
    final error = medicines.error ?? intake.error;

    final weekStrip = Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: WeekStrip(
        selectedDate: _selectedDate,
        onSelect: _selectDate,
        statusFor: (d) => intake.statusForDate(d, now: now),
      ),
    );

    Widget body;
    if (medicines.isLoading || intake.isLoading) {
      body = Column(
        children: [
          weekStrip,
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    } else if (medicines.medicines.isEmpty) {
      body = Column(
        children: [
          weekStrip,
          Expanded(
            child: EmptyState(
              icon: Icons.medication_outlined,
              title: 'No medicines yet',
              message: 'Add your first medicine to get reminders and keep track of your stock.',
              actionLabel: 'Add medicine',
              onAction: _addMedicine,
            ),
          ),
        ],
      );
    } else {
      body = AdaptiveList<DoseSlot>(
        items: doses,
        itemBuilder: (context, slot) => DoseTile(
          key: ValueKey('${slot.medicine.id}-${slot.scheduledAt}'),
          slot: slot,
          interactive: !isFuture,
        ),
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            weekStrip,
            const SizedBox(height: 12),
            if (error != null) ...[
              ErrorBanner(
                message: error,
                onDismiss: () {
                  medicines.clearError();
                  intake.clearError();
                },
              ),
              const SizedBox(height: 12),
            ],
            _SummaryCard(
              doses: doses,
              date: _selectedDate,
              now: now,
              streak: streak,
            ),
            if (lowStock.isNotEmpty) ...[
              const SizedBox(height: 12),
              _LowStockCard(medicines: lowStock),
            ],
          ],
        ),
        emptyState: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: EmptyState(
            icon: Icons.event_available_outlined,
            title: 'Nothing scheduled',
            message: isToday
                ? 'Medicines without a schedule are taken as needed. Use "Take now" on the Medicines tab.'
                : 'No doses were scheduled on this day.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('DailyDose'),
        actions: const [AccountButton()],
      ),
      body: body,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.doses,
    required this.date,
    required this.now,
    required this.streak,
  });

  final List<DoseSlot> doses;
  final DateTime date;
  final DateTime now;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = doses.length;
    final taken = doses.where((d) => d.stateAt(now) == DoseState.taken).length;
    final missed = doses
        .where(
          (d) => const [
            DoseState.overdue,
            DoseState.skipped,
          ].contains(d.stateAt(now)),
        )
        .length;
    final progress = total == 0 ? 0.0 : taken / total;
    final today = TimeUtils.dateOnly(now);
    final dayLabel = date.isAtSameMomentAs(today)
        ? 'Today'
        : DateFormat('EEEE, MMMM d').format(date);

    return Card(
      color: AppColors.secondary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    dayLabel,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.primarySoft,
                    ),
                  ),
                ),
                if (streak > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_fire_department,
                          size: 16,
                          color: AppColors.statusPending,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$streak-day streak',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              total == 0
                  ? 'No doses scheduled'
                  : '$taken of $total ${total == 1 ? 'dose' : 'doses'} taken',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            if (total > 0) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation(
                    AppColors.statusTaken,
                  ),
                ),
              ),
              if (missed > 0) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 16,
                      color: AppColors.statusMissed,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$missed ${missed == 1 ? 'dose was' : 'doses were'} missed',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _LowStockCard extends StatelessWidget {
  const _LowStockCard({required this.medicines});

  final List<Medicine> medicines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: AppColors.statusMissed.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.statusMissed),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.statusMissed,
                ),
                const SizedBox(width: 8),
                Text(
                  'Running low',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.statusMissed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final m in medicines)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  m.isOutOfStock
                      ? '${m.name}: out of stock'
                      : '${m.name}: ${formatDose(m.quantity, m.unit)} left',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
