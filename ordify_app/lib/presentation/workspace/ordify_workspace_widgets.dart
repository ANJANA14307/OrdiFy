import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ordify_logo_mark.dart';

const ordifyBg = Color(0xFF050A08);
const ordifyCard = Color(0xFF15211D);
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
        Container(
          color: ordifyBg,
        ),
        Positioned(
          top: -130,
          right: -90,
          child: OrdifyBlurCircle(
            size: 310,
            color: const Color(0xFF00B86B).withValues(alpha: 0.30),
          ),
        ),
        Positioned(
          bottom: -90,
          left: -110,
          child: OrdifyBlurCircle(
            size: 320,
            color: ordifyGreen.withValues(alpha: 0.20),
          ),
        ),
        Positioned(
          top: 250,
          left: -130,
          child: OrdifyBlurCircle(
            size: 260,
            color: const Color(0xFF0E7A4F).withValues(alpha: 0.20),
          ),
        ),
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.12),
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
    this.padding = const EdgeInsets.all(18),
    this.radius = 28,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: ordifyCard.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 26,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: child,
        ),
      ),
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
        const OrdifyLogoMark(size: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                title,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),
        if (badgeText != null)
          InkWell(
            onTap: onBadgeTap,
            borderRadius: BorderRadius.circular(22),
            child: OrdifyGlassCard(
              radius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
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
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const OrdifyMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color = ordifyGreen,
  });

  @override
  Widget build(BuildContext context) {
    return OrdifyGlassCard(
      radius: 24,
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        height: 86,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: color,
              size: 22,
            ),
            const Spacer(),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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
                color: color.withValues(alpha: 0.14),
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