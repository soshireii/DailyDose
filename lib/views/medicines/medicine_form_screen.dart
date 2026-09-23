import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../core/utils/time_utils.dart';
import '../../models/medicine.dart';
import '../../viewmodels/medicine_form_viewmodel.dart';
import '../../viewmodels/medicine_viewmodel.dart';

/// Add a new medicine, or edit [medicine] when provided (also used, with a
/// blank id, when duplicating an existing medicine).
class MedicineFormScreen extends StatelessWidget {
  const MedicineFormScreen({super.key, this.medicine});

  final Medicine? medicine;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MedicineFormViewModel(initial: medicine),
      child: const _MedicineFormBody(),
    );
  }
}

class _MedicineFormBody extends StatefulWidget {
  const _MedicineFormBody();

  @override
  State<_MedicineFormBody> createState() => _MedicineFormBodyState();
}

class _MedicineFormBodyState extends State<_MedicineFormBody> {
  static const int _maxImageBytes =
      700 * 1024; // stay well under Firestore's 1 MiB doc limit

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _strength;
  late final TextEditingController _dose;
  late final TextEditingController _quantity;
  late final TextEditingController _lowStock;
  late final TextEditingController _notes;
  bool _saving = false;
  bool _pickingImage = false;

  @override
  void initState() {
    super.initState();
    final m = context.read<MedicineFormViewModel>().initial;
    _name = TextEditingController(text: m?.name ?? '');
    _strength = TextEditingController(text: m?.strength ?? '');
    _dose = TextEditingController(text: formatAmount(m?.dosePerIntake ?? 1));
    _quantity = TextEditingController(text: formatAmount(m?.quantity ?? 30));
    _lowStock = TextEditingController(
      text: formatAmount(m?.lowStockThreshold ?? 5),
    );
    _notes = TextEditingController(text: m?.notes ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _strength.dispose();
    _dose.dispose();
    _quantity.dispose();
    _lowStock.dispose();
    _notes.dispose();
    super.dispose();
  }

  double? _number(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  String? _positive(String? v, String label) {
    final n = _number(v ?? '');
    if (n == null || n <= 0) return '$label must be more than 0.';
    return null;
  }

  String? _nonNegative(String? v, String label) {
    final n = _number(v ?? '');
    if (n == null || n < 0) return 'Enter $label (0 or more).';
    return null;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addTime() async {
    final form = context.read<MedicineFormViewModel>();
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: 'Reminder time',
    );
    if (picked == null || !mounted) return;
    if (!form.addTime(TimeUtils.encode(picked))) {
      _toast(
        'That time is already added, or you reached the limit of '
        '${MedicineFormViewModel.maxTimes} times.',
      );
    }
  }

  Future<void> _pickImage() async {
    final form = context.read<MedicineFormViewModel>();
    setState(() => _pickingImage = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 480,
        maxHeight: 480,
        imageQuality: 70,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes > _maxImageBytes) {
        if (mounted) _toast('That photo is too large. Try a smaller image.');
        return;
      }
      form.setImage(base64Encode(bytes));
    } catch (_) {
      if (mounted) _toast('Could not open the photo picker.');
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final form = context.read<MedicineFormViewModel>();
    final scheduleError = form.scheduleError;
    if (scheduleError != null) {
      _toast(scheduleError);
      return;
    }

    setState(() => _saving = true);
    final medicine = form.buildMedicine(
      name: _name.text.trim(),
      strength: _strength.text.trim(),
      dose: _number(_dose.text)!,
      quantity: _number(_quantity.text)!,
      lowStock: _number(_lowStock.text)!,
      notes: _notes.text.trim(),
    );

    final vm = context.read<MedicineViewModel>();
    final ok = await vm.saveMedicine(medicine);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
      _toast(vm.error ?? 'Could not save this medicine.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = context.watch<MedicineFormViewModel>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget section(String title, List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(form.isEditing ? 'Edit medicine' : 'Add medicine'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  section('Photo (optional)', [
                    Center(
                      child: GestureDetector(
                        onTap: _pickingImage ? null : _pickImage,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: scheme.surfaceContainerHighest,
                                border: Border.all(
                                  color: scheme.outlineVariant,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: _pickingImage
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : (form.imageBase64.isEmpty
                                        ? Icon(
                                            Icons.add_a_photo_outlined,
                                            color: scheme.onSurfaceVariant,
                                            size: 30,
                                          )
                                        : ClipOval(
                                            child: Image.memory(
                                              base64Decode(form.imageBase64),
                                              width: 96,
                                              height: 96,
                                              fit: BoxFit.cover,
                                            ),
                                          )),
                            ),
                            if (form.imageBase64.isNotEmpty)
                              Positioned(
                                right: -4,
                                top: -4,
                                child: GestureDetector(
                                  onTap: form.clearImage,
                                  child: const CircleAvatar(
                                    radius: 14,
                                    backgroundColor: AppColors.statusMissed,
                                    child: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        'Helps you recognize the medicine or pill at a glance.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ]),
                  section('Medicine', [
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter the medicine name.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _strength,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Strength (optional)',
                        hintText: 'e.g. 500 mg',
                      ),
                    ),
                  ]),
                  section('Dose and stock', [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _dose,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Dose per intake',
                            ),
                            validator: (v) => _positive(v, 'Dose'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: form.unit,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                            ),
                            items: [
                              for (final u in Units.all)
                                DropdownMenuItem(value: u, child: Text(u)),
                            ],
                            onChanged: (u) {
                              if (u != null) form.setUnit(u);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _quantity,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Amount in stock',
                            ),
                            validator: (v) => _nonNegative(v, 'the stock'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _lowStock,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Warn me at',
                              helperText: 'Low stock level',
                            ),
                            validator: (v) => _nonNegative(v, 'a level'),
                          ),
                        ),
                      ],
                    ),
                  ]),
                  section('Schedule', [
                    Text(
                      'Add the times you take it. Leave empty for a medicine you take as needed.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in form.times)
                          InputChip(
                            label: Text(TimeUtils.formatHm(context, t)),
                            onDeleted: () => form.removeTime(t),
                          ),
                        ActionChip(
                          avatar: const Icon(Icons.add_alarm, size: 18),
                          label: const Text('Add time'),
                          onPressed: _addTime,
                        ),
                      ],
                    ),
                    if (form.times.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('Repeat on', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var d = 1; d <= 7; d++)
                            FilterChip(
                              label: Text(weekdayShort[d - 1]),
                              selected: form.days.contains(d),
                              onSelected: (s) => form.toggleDay(d, s),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Remind me'),
                      subtitle: const Text('Send a notification at each time'),
                      value: form.remindersEnabled && form.times.isNotEmpty,
                      onChanged: form.times.isEmpty
                          ? null
                          : form.setRemindersEnabled,
                    ),
                  ]),
                  section('Notes', [
                    TextFormField(
                      controller: _notes,
                      minLines: 2,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        hintText: 'e.g. take with food',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Align(
          heightFactor: 1,
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : Text(form.isEditing ? 'Save changes' : 'Add medicine'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
