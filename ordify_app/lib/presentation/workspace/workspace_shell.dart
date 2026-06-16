import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class WorkspaceShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const WorkspaceShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 64,
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D0D),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(5, (index) {
            final icons = [
              Icons.dashboard_rounded,
              Icons.receipt_long_rounded,
              Icons.inventory_2_rounded,
              Icons.people_alt_rounded,
              Icons.psychology_alt_rounded,
            ];              
            final labels = [
                'Dashboard',
                'Orders',
                'Inventory',
                'Customers',
                'AI',
              ];              
              final bool isActive = index == navigationShell.currentIndex;
              
              return InkWell(
                onTap: () => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icons[index],
                      size: isActive ? 24 : 20,
                      color: isActive
                          ? const Color(0xFF00FFCC)
                          : Colors.grey,
                    ),                    
                    Text(labels[index], style: GoogleFonts.lexend(fontSize: 10, color: isActive ? const Color(0xFF00FFCC) : Colors.grey)),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}