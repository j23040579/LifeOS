import 'package:flutter/material.dart';

import 'core/design/app_theme.dart';
import 'features/today/today_screen.dart';
import 'features/today/sample_day.dart';
import 'features/workspace/workspace_shell.dart';

class LifeApp extends StatefulWidget {
  const LifeApp({
    super.key,
    this.initialPreview = DayPreview.ready,
    this.workspaceMode = false,
    this.demoWorkspace = false,
  });

  final DayPreview initialPreview;
  final bool workspaceMode, demoWorkspace;

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
      themeAnimationDuration:
          WidgetsBinding
              .instance
              .platformDispatcher
              .accessibilityFeatures
              .disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 240),
      home: widget.workspaceMode
          ? WorkspaceShell(
              demoMode: widget.demoWorkspace,
              themeMode: _mode,
              onThemeChanged: (mode) => setState(() => _mode = mode),
            )
          : TodayScreen(
              initialPreview: widget.initialPreview,
              themeMode: _mode,
              onThemeChanged: (mode) => setState(() => _mode = mode),
            ),
    );
  }
}
