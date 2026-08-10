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

  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSettings = ref.watch(themeControllerProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'SMDB',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(themeSettings.color, Brightness.light),
      darkTheme: buildAppTheme(themeSettings.color, Brightness.dark),
      themeMode: themeSettings.mode,
      // Windows mice commonly have a side "Back" button; browsers and most
      // native apps treat it as back-navigation, but Flutter doesn't wire
      // this up on its own. Listening at the root (rather than per-screen)
      // means it works the same way no matter which screen is open.
      builder: (context, child) {
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            if (event.buttons & kBackMouseButton != 0) {
              final nav = navigatorKey.currentState;
              if (nav != null && nav.canPop()) {
                nav.pop();
              }
            }
          },
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AppShell(),
    );
  }
}
