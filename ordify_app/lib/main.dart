import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/network/error_handler.dart';
import 'core/router/router.dart';

const String _supabaseUrl = 'https://fqgqomkkblbjoqjvwdln.supabase.co';

const String _supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZxZ3FvbWtrYmxiam9xanZ3ZGxuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA5MzE4OTgsImV4cCI6MjA5NjUwNzg5OH0.J-6yIi_pN48woSb43n48-apDP3o5vgTJpqKZDKDSEYs';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: OrdiFyApp(),
    ),
  );
}

class OrdiFyApp extends ConsumerWidget {
  const OrdiFyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'OrdiFy',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: ErrorHandler.messengerKey,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A120F),
        primaryColor: const Color(0xFF61D7A7),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF61D7A7),
          secondary: Color(0xFFF4C96C),
          surface: Color(0xFF121B18),
          surfaceContainerHighest: Color(0xFF1A2A25),
          onSurface: Color(0xFFEAF5F1),
          onPrimary: Color(0xFF09140F),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ).copyWith(
          displayLarge: const TextStyle(color: Color(0xFFF1F7F4)),
          headlineLarge: const TextStyle(color: Color(0xFFF1F7F4)),
          titleLarge: const TextStyle(color: Color(0xFFF1F7F4)),
          bodyLarge: const TextStyle(color: Color(0xFFE5EFEA)),
          bodyMedium: const TextStyle(color: Color(0xFFDDE9E4)),
          labelLarge: const TextStyle(color: Color(0xFFE5EFEA)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A120F),
          foregroundColor: Color(0xFFF1F7F4),
          elevation: 0,
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF121B18),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Colors.white.withOpacity(0.05),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF141F1C),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          labelStyle: const TextStyle(
            color: Color(0xFF61D7A7),
            fontWeight: FontWeight.w700,
          ),
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.38),
            fontWeight: FontWeight.w600,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: Color(0xFF61D7A7),
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: Color(0xFFFF7B7B),
              width: 1.3,
            ),
          ),
        ),
      ),
      routerConfig: router,
    );
  }
}