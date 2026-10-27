// lib/main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';
import 'theme.dart';
import 'theme_controller.dart';
import 'gym_command_center.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SynthetixApp());
}

class SynthetixApp extends StatefulWidget {
  const SynthetixApp({super.key});

  @override
  State<SynthetixApp> createState() => _SynthetixAppState();
}

class _SynthetixAppState extends State<SynthetixApp> {
  late final Future<void> _startup;

  @override
  void initState() {
    super.initState();
    _startup = _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
    } catch (e) {
      debugPrint('⚠️ Supabase no inicializado: $e');
    }

    await themeController.load();
  }

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
          home: FutureBuilder<void>(
            future: _startup,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _StartupError(error: snapshot.error.toString());
              }
              if (snapshot.connectionState != ConnectionState.done) {
                return const _StartupScreen();
              }
              return const GymCommandCenter();
            },
          ),
        );
      },
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded, color: context.colors.green, size: 42),
            const SizedBox(height: 12),
            Text(
              'SYNTHETIX GYM',
              style: TextStyle(
                color: context.colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 24),
            CircularProgressIndicator(color: context.colors.green),
          ],
        ),
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  color: context.colors.red, size: 42),
              const SizedBox(height: 12),
              Text(
                'No se pudo iniciar la aplicación',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
