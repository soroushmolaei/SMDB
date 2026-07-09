import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/library_screen.dart';

void main() {
  runApp(const ProviderScope(child: SmdbApp()));
}

class SmdbApp extends StatelessWidget {
  const SmdbApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SMDB',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C5CE7),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const LibraryScreen(),
    );
  }
}
