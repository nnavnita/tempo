import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: TempoApp()));
}

class TempoApp extends ConsumerWidget {
  const TempoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Tempo',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      // Deliberately not ThemeMode.system yet: the dark AppTheme/AppColors
      // infrastructure is merged and tested, but ~50 existing screens across
      // 15 files still reference light-only AppColors.* tokens unconditionally
      // (worst case ~1.3:1 text contrast in dark mode). Revisit once a
      // follow-up spec migrates those call sites to dark-mode-safe tokens.
      themeMode: ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
