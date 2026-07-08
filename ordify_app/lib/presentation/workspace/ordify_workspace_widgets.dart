import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const ordifyBg = Color(0xFF050A08);
const ordifyCard = Color(0xFF1A2D24);
const ordifyGreen = Color(0xFF35E58F);
const ordifyGreenDark = Color(0xFF06100B);
const ordifyYellow = Color(0xFFFFC857);
const ordifyBlue = Color(0xFF7BE0FF);
const ordifyRed = Color(0xFFFF6B7A);

class OrdifyBackground extends StatelessWidget {
  final Widget child;

  const OrdifyBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: ordifyBg),
        Positioned(
          top: -130,
          right: -90,
          child: OrdifyBlurCircle(
            size: 310,
            color: const Color(0xFF00B86B).withOpacity(0.30),
          ),
        ),
        Positioned(
          bottom: -90,
          left: -110,
          child: OrdifyBlurCircle(
            size: 320,
            color: ordifyGreen.withOpacity(0.20),
          ),
        ),
        Positioned(
          top: 250,
          left: -130,
          child: OrdifyBlurCircle(
            size: 260,
            color: const Color(0xFF0E7A4F).withOpacity(0.20),
          ),
        ),
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.12),
          ),
        ),
        child,
      ],
    );
  }
}

class OrdifyBlurCircle extends StatelessWidget {
  final double size;
  final Color color;

  const OrdifyBlurCircle({
    super.key,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class OrdifyGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  const OrdifyGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.radius = 30,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: ordifyCard.withOpacity(0.78),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withOpacity(0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.30),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class OrdifyTopHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final IconData icon;
  final String? badgeText;
  final VoidCallback? onBadgeTap;

  const OrdifyTopHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.icon,
    this.badgeText,
    this.onBadgeTap,
  });

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
            boxShadow: [
              BoxShadow(
                color: ordifyGreen.withOpacity(0.26),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: ordifyGreenDark,
            size: 25,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  shadows: [
                    Shadow(
                      color: ordifyGreen.withOpacity(0.20),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (badgeText != null)
          InkWell(
            onTap: onBadgeTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: ordifyGreen.withOpacity(0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: ordifyGreen.withOpacity(0.30),
                ),
              ),
              child: Text(
                badgeText!,
                style: GoogleFonts.inter(
                  color: ordifyGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class OrdifyMetricCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String? title;
  final String? label;
  final Color? color;
  final Color? iconColor;
  final double minHeight;

  const OrdifyMetricCard({
    super.key,
    required this.icon,
    required this.value,
    this.title,
    this.label,
    this.color,
    this.iconColor,
    this.minHeight = 118,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedLabel = label ?? title ?? '';
    final resolvedColor = iconColor ?? color ?? ordifyGreen;

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: resolvedColor,
            size: 25,
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: Color(0xFFFFD6D6),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            resolvedLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class OrdifyActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const OrdifyActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color = ordifyGreen,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: OrdifyGlassCard(
        radius: 24,
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                icon,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white38,
              size: 15,
            ),
          ],
        ),
      ),
    );
  }
}

class OrdifySectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;

  const OrdifySectionTitle({
    super.key,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing!,
            style: GoogleFonts.inter(
              color: ordifyGreen,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
      ],
    );
  }
}

class OrdifyStatusPill extends StatelessWidget {
  final String text;
  final Color color;

  const OrdifyStatusPill({
    super.key,
    required this.text,
    this.color = ordifyGreen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withOpacity(0.32),
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}