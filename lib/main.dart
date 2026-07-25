import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/providers.dart';
import 'screens/app_shell.dart';
import 'services/app_config_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load once, before the first frame — otherwise the app would flash the
  // default theme for a moment while smdb_config.json loads.
  final initialConfig = await AppConfigService.load();

  runApp(
    ProviderScope(
      overrides: [
        initialAppConfigProvider.overrideWithValue(initialConfig),
      ],
      child: const SmdbApp(),
    ),
  );
}

class SmdbApp extends ConsumerWidget {
  const SmdbApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSettings = ref.watch(themeControllerProvider);

    return MaterialApp(
      title: 'SMDB',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(themeSettings.color, Brightness.light),
      darkTheme: buildAppTheme(themeSettings.color, Brightness.dark),
      themeMode: themeSettings.mode,
      home: const AppShell(),
    );
  }
}
