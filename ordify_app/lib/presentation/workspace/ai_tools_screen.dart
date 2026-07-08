import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_client.dart';
import 'ordify_workspace_widgets.dart';

class AiToolsScreen extends StatefulWidget {
  const AiToolsScreen({super.key});

  @override
  State<AiToolsScreen> createState() => _AiToolsScreenState();
}

class _AiToolsScreenState extends State<AiToolsScreen> {
  bool isLoading = true;
  String? errorMessage;

  Map<String, dynamic> aiData = {};
  List<dynamic> suggestions = [];
  List<dynamic> priorityActions = [];

  @override
  void initState() {
    super.initState();
    fetchSuggestions();
  }

  Future<void> fetchSuggestions() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await apiClient.get('/ai/suggestions');

      final rawData = response.data;
      final data = rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : <String, dynamic>{};

      setState(() {
        aiData = data;
        suggestions = List<dynamic>.from(data['suggestions'] ?? []);
        priorityActions = List<dynamic>.from(data['priority_actions'] ?? []);
        isLoading = false;
        errorMessage = null;
      });
    } catch (error) {
      setState(() {
        aiData = {};
        suggestions = [];
        priorityActions = [];
        errorMessage = error.toString();
        isLoading = false;
      });
    }
  }

  String textValue(dynamic value) {
    return value?.toString() ?? '0';
  }

  @override
  Widget build(BuildContext context) {
    final healthScore = textValue(aiData['business_health_score']);
    final summary = aiData['summary']?.toString() ??
        'OrdiFy AI will analyze your orders, stock, payments and customers.';

    return Scaffold(
      backgroundColor: ordifyBg,
      body: OrdifyBackground(
        child: SafeArea(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: ordifyGreen),
                )
              : RefreshIndicator(
                  color: ordifyGreen,
                  backgroundColor: const Color(0xFF0B1510),
                  onRefresh: fetchSuggestions,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 26, 20, 145),
                    children: [
                      _Header(onRefresh: fetchSuggestions),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 14),
                        _AiWarningCard(
                          onRetry: fetchSuggestions,
                        ),
                      ],
                      const SizedBox(height: 18),
                      OrdifyGlassCard(
                        radius: 30,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _GlowText(
                              'AI Business Assistant',
                              fontSize: 23,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              summary,
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                height: 1.45,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: ordifyGreen.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: ordifyGreen.withOpacity(0.24),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.health_and_safety_rounded,
                                    color: ordifyGreen,
                                    size: 34,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'AI Health Score',
                                          style: GoogleFonts.inter(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$healthScore%',
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 28,
                                            fontWeight: FontWeight.w900,
                                            shadows: const [
                                              Shadow(
                                                color: Color(0xFFFFC8C8),
                                                blurRadius: 8,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
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
                                  color: ordifyGreen.withOpacity(0.14),
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
                                    const _GlowText(
                                      'Instagram DM Orders',
                                      fontSize: 16,
                                      soft: true,
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
                      const _GlowText(
                        'Priority Actions',
                        fontSize: 22,
                      ),
                      const SizedBox(height: 12),
                      if (priorityActions.isEmpty)
                        const _EmptyCard(
                          icon: Icons.task_alt_rounded,
                          title: 'No urgent action',
                          subtitle:
                              'Keep adding orders and payments to improve AI recommendations.',
                        )
                      else
                        ...priorityActions.map((action) {
                          return _PriorityCard(
                            text: action.toString(),
                          );
                        }),
                      const SizedBox(height: 22),
                      const _GlowText(
                        'Smart Suggestions',
                        fontSize: 22,
                      ),
                      const SizedBox(height: 12),
                      if (suggestions.isEmpty)
                        const _EmptyCard(
                          icon: Icons.auto_awesome_rounded,
                          title: 'No suggestions yet',
                          subtitle:
                              'Create products, customers, orders and payments to unlock suggestions.',
                        )
                      else
                        ...suggestions.map((suggestion) {
                          if (suggestion is Map) {
                            final suggestionMap =
                                Map<String, dynamic>.from(suggestion);

                            return _SuggestionCard(
                              suggestion: suggestionMap,
                            );
                          }

                          return _PriorityCard(
                            text: suggestion.toString(),
                          );
                        }),
                      const SizedBox(height: 22),
                      OrdifyGlassCard(
                        radius: 28,
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                readOnly: true,
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: const Color(0xFF0F2419),
                                      content: Text(
                                        'Chat AI will be connected later. For now, suggestions are generated from your business data.',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Ask OrdiFy AI... coming soon',
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
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onRefresh,
  });

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            color: ordifyGreen,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: ordifyGreenDark,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Smart assistant',
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'OrdiFy AI',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: ordifyGreen.withOpacity(0.25),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: ordifyGreen.withOpacity(0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: ordifyGreen.withOpacity(0.30),
            ),
          ),
          child: Text(
            'Live',
            style: GoogleFonts.inter(
              color: ordifyGreen,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          onPressed: onRefresh,
          icon: const Icon(
            Icons.refresh_rounded,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _AiWarningCard extends StatelessWidget {
  const _AiWarningCard({
    required this.onRetry,
  });

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return OrdifyGlassCard(
      radius: 24,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: ordifyYellow,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'AI backend is not ready yet. Screen opened in fallback mode.',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: GoogleFonts.inter(
                color: ordifyGreen,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: OrdifyGlassCard(
        radius: 26,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: ordifyYellow.withOpacity(0.18),
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: ordifyYellow,
                size: 27,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  height: 1.35,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
  });

  final Map<String, dynamic> suggestion;

  Color get color {
    final priority = suggestion['priority']?.toString() ?? '';

    if (priority == 'high') {
      return const Color(0xFFFF5E73);
    }

    if (priority == 'medium') {
      return ordifyYellow;
    }

    return ordifyGreen;
  }

  IconData get icon {
    final type = suggestion['type']?.toString() ?? '';

    if (type == 'stock') return Icons.inventory_2_rounded;
    if (type == 'payment') return Icons.payments_rounded;
    if (type == 'growth') return Icons.trending_up_rounded;
    if (type == 'sales') return Icons.campaign_rounded;
    if (type == 'customer') return Icons.people_alt_rounded;
    if (type == 'health') return Icons.health_and_safety_rounded;

    return Icons.auto_awesome_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final title = suggestion['title']?.toString() ?? 'Suggestion';
    final message = suggestion['message']?.toString() ?? '';
    final action = suggestion['action']?.toString() ?? '';
    final priority = suggestion['priority']?.toString().toUpperCase() ?? 'INFO';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: OrdifyGlassCard(
        radius: 28,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _GlowText(
                    title,
                    fontSize: 17,
                    soft: true,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: color.withOpacity(0.35),
                    ),
                  ),
                  child: Text(
                    priority,
                    style: GoogleFonts.inter(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              message,
              style: GoogleFonts.inter(
                color: Colors.white70,
                height: 1.4,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (action.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.tips_and_updates_rounded,
                      color: color,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        action,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          height: 1.35,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return OrdifyGlassCard(
      radius: 28,
      child: Column(
        children: [
          Icon(
            icon,
            color: ordifyGreen,
            size: 54,
          ),
          const SizedBox(height: 16),
          _GlowText(
            title,
            fontSize: 20,
            soft: true,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowText extends StatelessWidget {
  const _GlowText(
    this.text, {
    required this.fontSize,
    this.soft = false,
  });

  final String text;
  final double fontSize;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        shadows: [
          Shadow(
            color: soft ? const Color(0xFFFFC8C8) : const Color(0xFFFFD6D6),
            blurRadius: soft ? 8 : 12,
          ),
          Shadow(
            color: ordifyGreen.withOpacity(0.25),
            blurRadius: soft ? 8 : 14,
          ),
        ],
      ),
    );
  }
}

class AiScreen extends AiToolsScreen {
  const AiScreen({super.key});
}

class AIScreen extends AiToolsScreen {
  const AIScreen({super.key});
}

class AIPage extends AiToolsScreen {
  const AIPage({super.key});
}