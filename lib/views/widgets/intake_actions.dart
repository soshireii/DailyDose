import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/format_utils.dart';
import '../../models/intake_log.dart';
import '../../models/medicine.dart';
import '../../viewmodels/intake_viewmodel.dart';

/// UI glue shared by several screens: call the view-model, then tell the user
/// what happened (with Undo where it makes sense).
class IntakeActions {
  static Future<void> take(
    BuildContext context,
    Medicine medicine, {
    DateTime? scheduledFor,
  }) async {
    final vm = context.read<IntakeViewModel>();
    final messenger = ScaffoldMessenger.of(context);

    final log = await vm.takeDose(medicine, scheduledFor: scheduledFor);
    messenger.hideCurrentSnackBar();
    if (log == null) {
      messenger.showSnackBar(SnackBar(
        content: Text(vm.error ?? 'Could not log this dose.'),
      ));
      return;
    }

    final stockNote =
        log.deducted < log.amount ? ' Stock is empty, so refill soon.' : '';
    messenger.showSnackBar(SnackBar(
      content: Text(
        'Logged ${formatDose(log.amount, log.unit)} of ${log.medicineName}.$stockNote',
      ),
      action: SnackBarAction(label: 'Undo', onPressed: () => vm.deleteLog(log)),
    ));
  }

  static Future<void> skip(
    BuildContext context,
    Medicine medicine,
    DateTime scheduledFor,
  ) async {
    final vm = context.read<IntakeViewModel>();
    final messenger = ScaffoldMessenger.of(context);

    final log = await vm.skipDose(medicine, scheduledFor);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(log == null
          ? (vm.error ?? 'Could not skip this dose.')
          : 'Skipped ${medicine.name}.'),
      action: log == null
          ? null
          : SnackBarAction(label: 'Undo', onPressed: () => vm.deleteLog(log)),
    ));
  }

  static Future<void> undo(BuildContext context, IntakeLog log) async {
    final vm = context.read<IntakeViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await vm.deleteLog(log);
    if (!ok) {
      messenger.showSnackBar(SnackBar(
        content: Text(vm.error ?? 'Could not undo this entry.'),
      ));
    }
  }
}
