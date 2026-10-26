import 'package:flutter/material.dart';

import '../../core/design/event_colors.dart';

class EventColorPicker extends StatelessWidget {
  const EventColorPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final color in EventColors.choices)
          ChoiceChip(
            label: Text(color.name),
            selected: value == color.id,
            onSelected: (_) => onChanged(color.id),
            labelStyle: TextStyle(color: color.foreground(brightness)),
            backgroundColor: color.surface(brightness),
            selectedColor: color.surface(brightness),
            checkmarkColor: color.foreground(brightness),
            side: BorderSide(
              color: color.foreground(brightness),
              width: value == color.id ? 2 : 1,
            ),
            avatar: value == color.id
                ? null
                : Icon(
                    Icons.circle,
                    size: 16,
                    color: color.foreground(brightness),
                  ),
            materialTapTargetSize: MaterialTapTargetSize.padded,
          ),
      ],
    );
  }
}
