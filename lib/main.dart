import 'package:flutter/material.dart';

import 'app.dart';
import 'features/today/sample_day.dart';

void main() {
  const name = String.fromEnvironment('DAY_PREVIEW', defaultValue: 'ready');
  final preview = DayPreview.values.firstWhere(
    (value) => value.name == name,
    orElse: () => DayPreview.ready,
  );
  runApp(LifeApp(initialPreview: preview));
}
