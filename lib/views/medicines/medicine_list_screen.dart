import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/medicine.dart';
import '../../viewmodels/medicine_viewmodel.dart';
import '../widgets/account_button.dart';
import '../widgets/adaptive_list.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_banner.dart';
import 'medicine_card.dart';
import 'medicine_form_screen.dart';

class MedicineListScreen extends StatelessWidget {
  const MedicineListScreen({super.key});

  void _add(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MedicineFormScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MedicineViewModel>();
    final hasAny = vm.medicines.isNotEmpty;

    Widget body;
    if (vm.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (!hasAny) {
      body = EmptyState(
        icon: Icons.medication_outlined,
        title: 'No medicines yet',
        message:
            'Add a medicine with its dose, stock and reminder times. The stock counter updates every time you log a dose.',
        actionLabel: 'Add medicine',
        onAction: () => _add(context),
      );
    } else {
      body = AdaptiveList<Medicine>(
        items: vm.filtered,
        itemBuilder: (context, medicine) =>
            MedicineCard(key: ValueKey(medicine.id), medicine: medicine),
        header: Column(
          children: [
            if (vm.error != null) ...[
              ErrorBanner(message: vm.error!, onDismiss: vm.clearError),
              const SizedBox(height: 12),
            ],
            TextField(
              onChanged: vm.setQuery,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search medicines',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ],
        ),
        emptyState: const Padding(
          padding: EdgeInsets.only(top: 24),
          child: EmptyState(
            icon: Icons.search_off,
            title: 'No matches',
            message: 'Try a different name.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicines'),
        actions: const [AccountButton()],
      ),
      body: body,
      floatingActionButton: hasAny
          ? FloatingActionButton.extended(
              onPressed: () => _add(context),
              icon: const Icon(Icons.add),
              label: const Text('Add medicine'),
            )
          : null,
    );
  }
}
