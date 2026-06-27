import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ordify_workspace_widgets.dart';

class AiScreen extends StatelessWidget {
  const AiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ordifyBg,
      body: OrdifyBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 145),
            children: [
              const OrdifyTopHeader(
                eyebrow: 'Smart assistant',
                title: 'OrdiFy AI',
                icon: Icons.auto_awesome_rounded,
                badgeText: 'Beta',
              ),
              const SizedBox(height: 18),

              OrdifyGlassCard(
                radius: 30,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Business Assistant',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Get smart suggestions for stock, orders, customers, captions, and seller decisions.',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        height: 1.4,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ordifyGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.psychology_rounded,
                            color: ordifyGreen,
                            size: 34,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Ask OrdiFy AI what to restock, which product to promote, or how to improve sales.',
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                height: 1.4,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              GestureDetector(
                onTap: () {
                  context.push('/instagram-dms');
                },
                child: OrdifyGlassCard(
                  radius: 28,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        height: 54,
                        width: 54,
                        decoration: BoxDecoration(
                          color: ordifyGreen.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(19),
                        ),
                        child: const Icon(
                          Icons.mark_chat_unread_rounded,
                          color: ordifyGreen,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Instagram DM Orders',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'View DM conversations and convert customer messages into orders.',
                              style: GoogleFonts.inter(
                                color: Colors.white54,
                                height: 1.4,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        height: 38,
                        width: 38,
                        decoration: BoxDecoration(
                          color: ordifyGreen,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: ordifyGreenDark,
                          size: 21,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),
              const OrdifySectionTitle(title: 'Suggested Prompts'),
              const SizedBox(height: 12),

              const OrdifyActionTile(
                icon: Icons.inventory_2_rounded,
                title: 'What should I restock?',
                subtitle: 'Analyze inventory and low-stock products',
              ),
              const SizedBox(height: 12),
              const OrdifyActionTile(
                icon: Icons.trending_up_rounded,
                title: 'How can I increase sales?',
                subtitle: 'Get product and customer-based suggestions',
                color: ordifyYellow,
              ),
              const SizedBox(height: 12),
              const OrdifyActionTile(
                icon: Icons.campaign_rounded,
                title: 'Create Instagram caption',
                subtitle: 'Generate caption for product promotion',
                color: ordifyBlue,
              ),

              const SizedBox(height: 22),

              OrdifyGlassCard(
                radius: 28,
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ask OrdiFy AI...',
                          hintStyle: GoogleFonts.inter(
                            color: Colors.white38,
                            fontWeight: FontWeight.w700,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    Container(
                      height: 46,
                      width: 46,
                      decoration: BoxDecoration(
                        color: ordifyGreen,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        color: ordifyGreenDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AIScreen extends AiScreen {
  const AIScreen({super.key});
}

class AIPage extends AiScreen {
  const AIPage({super.key});
}

class AiToolsScreen extends AiScreen {
  const AiToolsScreen({super.key});
}