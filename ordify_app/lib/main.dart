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
        scaffoldBackgroundColor: const Color(0xFF050A08),
        primaryColor: const Color(0xFF35E58F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF35E58F),
          secondary: Color(0xFFFFC857),
          surface: Color(0xFF0B1510),
        ),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0D1712),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          labelStyle: const TextStyle(
            color: Color(0xFF35E58F),
            fontWeight: FontWeight.w700,
          ),
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.38),
            fontWeight: FontWeight.w600,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.10),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.10),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: Color(0xFF35E58F),
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: Color(0xFFFF6B7A),
              width: 1.3,
            ),
          ),
        ),
      ),
      routerConfig: router,
    );
  }
}