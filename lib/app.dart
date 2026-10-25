import 'package:flutter/material.dart';

import 'core/design/app_theme.dart';
import 'features/today/today_screen.dart';
import 'features/today/sample_day.dart';

class LifeApp extends StatefulWidget {
  const LifeApp({super.key, this.initialPreview = DayPreview.ready});

  final DayPreview initialPreview;

  @override
  State<LifeApp> createState() => _LifeAppState();
}

class _LifeAppState extends State<LifeApp> {
  ThemeMode _mode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _mode,
      themeAnimationDuration: WidgetsBinding.instance.platformDispatcher
              .accessibilityFeatures.disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 240),
      home: TodayScreen(
        initialPreview: widget.initialPreview,
        themeMode: _mode,
        onThemeChanged: (mode) => setState(() => _mode = mode),
      ),
    );
  }
}
