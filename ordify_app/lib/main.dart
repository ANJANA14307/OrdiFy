import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ordify_app/core/router/router.dart';
import 'core/network/error_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure flutter bindings are initialized before running the app
  
  // 1. Connect the app to cloud supabase
  await Supabase.initialize(
    url: 'https://fqgqomkkblbjoqjvwdln.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZxZ3FvbWtrYmxiam9xanZ3ZGxuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA5MzE4OTgsImV4cCI6MjA5NjUwNzg5OH0.J-6yIi_pN48woSb43n48-apDP3o5vgTJpqKZDKDSEYs',
  );
  
  // 2. Wrap the app inside the ProviderScope for riverpod state tracking
  runApp(
    const ProviderScope(
      child: OrdiFyApp(),
    ),
  );
}

// ⚡ Fixed: Changed StatelessWidget to ConsumerWidget so WidgetRef works perfectly!
class OrdiFyApp extends ConsumerWidget { 
  const OrdiFyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
       
    return MaterialApp.router( 
      title: 'ordify',
      debugShowCheckedModeBanner: false, 
      scaffoldMessengerKey: ErrorHandler.messengerKey,

      // 3. Applying OLED theme
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData( 
        brightness: Brightness.dark, 
        scaffoldBackgroundColor: const Color(0xFF000000), 
        primaryColor: const Color(0xFF00FFCC),

        textTheme: GoogleFonts.lexendTextTheme(ThemeData.dark().textTheme).copyWith( 
          displayLarge: GoogleFonts.lexend(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
          ),
         ),
        
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0D0D11), 
          contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          labelStyle: const TextStyle(color: Color(0xFF00FFCC), fontWeight: FontWeight.bold),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF1A1A22), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const Color(0xFF00FFCC) == Colors.transparent 
                ? BorderSide.none 
                : const BorderSide(color: Color(0xFF00FFCC), width: 1.5),
          ),
        ),
      ),
      routerConfig: router,
    );
  }
}