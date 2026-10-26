import 'package:flutter/material.dart';

import 'dart:convert';

class EntryField {
  const EntryField(
    this.key,
    this.label, {
    this.value = '',
    this.optional = false,
    this.lines = 1,
    this.choices,
    this.multiple = false,
    this.obscure = false,
    this.builder,
  });
  final String key, label, value;
  final bool optional, multiple, obscure;
  final int lines;
  final Map<String, String>? choices;
  final Widget Function(BuildContext, String, ValueChanged<String>)? builder;
}

Future<Map<String, String>?> entryForm(
  BuildContext context,
  String title,
  List<EntryField> fields, {
  String? Function(Map<String, String>)? validate,
  String confirm = 'Save',
  String? notice,
}) async {
  return showDialog<Map<String, String>>(
    context: context,
    builder: (context) =>
        _EntryDialog(title, fields, validate, confirm, notice),
  );
}

class _EntryDialog extends StatefulWidget {
  const _EntryDialog(
    this.title,
    this.fields,
    this.validate,
    this.confirm,
    this.notice,
  );
  final String title, confirm;
  final String? notice;
  final List<EntryField> fields;
  final String? Function(Map<String, String>)? validate;
  @override
  State<_EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<_EntryDialog> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers = {
    for (final f in widget.fields) f.key: TextEditingController(text: f.value),
  };
  String? _error;
  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick(EntryField field) async {
    final input = _controllers[field.key]!.text;
    final initial =
        DateTime.tryParse(input.replaceFirst(' ', 'T')) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(DateTime(1900))
          ? DateTime(1900)
          : initial.isAfter(DateTime(2200))
          ? DateTime(2200)
          : initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (date == null || !mounted) return;
    var value =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    if (field.key != 'date') {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );
      if (time == null || !mounted) return;
      value +=
          ' ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    _controllers[field.key]!.text = value;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.notice != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(widget.notice!),
                ),
              for (final field in widget.fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: field.builder != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(field.label),
                            const SizedBox(height: 8),
                            field.builder!(
                              context,
                              _controllers[field.key]!.text,
                              (value) => setState(
                                () => _controllers[field.key]!.text = value,
                              ),
                            ),
                          ],
                        )
                      : field.multiple
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(field.label),
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final choice
                                    in field.choices!.entries.where(
                                      (e) => e.key.isNotEmpty,
                                    ))
                                  FilterChip(
                                    label: Text(choice.value),
                                    selected: (jsonDecode(
                                      _controllers[field.key]!.text,
                                    ) as List).contains(choice.key),
                                    onSelected: (selected) {
                                      final values = List<String>.from(
                                        jsonDecode(
                                          _controllers[field.key]!.text,
                                        ),
                                      );
                                      if (selected) {
                                        values.add(choice.key);
                                      } else {
                                        values.remove(choice.key);
                                      }
                                      setState(
                                        () => _controllers[field.key]!.text =
                                            jsonEncode(values),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ],
                        )
                      : field.choices == null
                      ? TextFormField(
                          controller: _controllers[field.key],
                          obscureText: field.obscure,
                          enableSuggestions: !field.obscure,
                          autocorrect: !field.obscure,
                          minLines: field.lines,
                          maxLines: field.lines == 1 ? 1 : null,
                          decoration: InputDecoration(
                            labelText: field.label,
                            alignLabelWithHint: true,
                            suffixIcon:
                                const {
                                      'deadline',
                                      'start',
                                      'end',
                                      'date',
                                    }.contains(field.key) &&
                                    !field.label.contains('HH:MM')
                                ? IconButton(
                                    tooltip: 'Choose date/time',
                                    onPressed: () => _pick(field),
                                    icon: const Icon(
                                      Icons.calendar_month_outlined,
                                    ),
                                  )
                                : null,
                          ),
                          validator: (value) =>
                              !field.optional &&
                                  (value == null || value.trim().isEmpty)
                              ? 'This field is required'
                              : null,
                        )
                      : DropdownButtonFormField<String>(
                          initialValue: _controllers[field.key]!.text,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: field.label),
                          items: [
                            for (final entry in field.choices!.entries)
                              DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                          ],
                          onChanged: (value) =>
                              _controllers[field.key]!.text = value ?? '',
                        ),
                ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          final values = {
            for (final c in _controllers.entries) c.key: c.value.text.trim(),
          };
          final error = widget.validate?.call(values);
          if (error != null) {
            setState(() => _error = error);
            return;
          }
          Navigator.pop(context, values);
        },
        child: Text(widget.confirm),
      ),
    ],
  );
}
