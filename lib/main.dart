import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'config/providers/firebase_providers.dart';
import 'config/router/app_router.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Must happen before anything schedules a notification or extracts a
  // free gap — both resolve local wall-clock times through this database.
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation(AppConstants.fallbackTimeZone));

  final container = ProviderContainer();
  await container.read(slotNotificationSchedulerProvider).init();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const TempoApp(),
    ),
  );
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
      // infrastructure is merged and tested, but the planner screens still
      // reference light-only AppColors.* tokens unconditionally (worst case
      // ~1.3:1 text contrast in dark mode). The v2 strip cut this surface
      // down a lot; revisit once those call sites use dark-safe tokens.
      themeMode: ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
