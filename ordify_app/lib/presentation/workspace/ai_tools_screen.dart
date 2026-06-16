import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AiToolsScreen extends StatelessWidget {
  const AiToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _SimpleWorkspaceScreen(
      title: 'AI Tools',
      subtitle: 'AI helpers for product descriptions, order summaries, and insights.',
      icon: Icons.psychology_alt_rounded,
    );
  }
}

class _SimpleWorkspaceScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SimpleWorkspaceScreen({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF00FFCC), size: 42),
            const SizedBox(height: 16),
            Text(title, style: GoogleFonts.lexend(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.lexend(color: Colors.white54, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}