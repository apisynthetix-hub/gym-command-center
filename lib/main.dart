// lib/main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';
import 'theme.dart';
import 'theme_controller.dart';
import 'gym_command_center.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('⚠️ Supabase no inicializado: $e');
  }

  await themeController.load();

  runApp(const SynthetixApp());
}

class SynthetixApp extends StatelessWidget {
  const SynthetixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Synthetix Gym OS',
          themeMode: themeController.themeMode,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          home: const GymCommandCenter(),
        );
      },
    );
  }
}
