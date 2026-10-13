import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppBranding {
  static const String appName = 'DATINGLY';
  static const String slogan = 'Lướt qua đời nhau, để lại dấu ấn';
}

class BrandHero extends StatelessWidget {
  const BrandHero({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final logoSize = compact ? 72.0 : 88.0;
    final iconSize = compact ? 34.0 : 42.0;
    final titleSize = compact ? 28.0 : 40.0;
    final sloganSize = compact ? 12.0 : 14.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(compact ? 4 : 5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: compact ? 18 : 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Container(
            width: logoSize,
            height: logoSize,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
            ),
            child: Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: iconSize,
            ),
          ),
        ),
        SizedBox(height: compact ? 14 : 18),
        Text(
          AppBranding.appName,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: titleSize,
            fontWeight: FontWeight.w800,
            letterSpacing: compact ? 3 : 5,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        ),
        SizedBox(height: compact ? 10 : 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 14 : 18,
              vertical: compact ? 8 : 10,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
            ),
            child: Text(
              AppBranding.slogan,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: sloganSize,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class BrandBanner extends StatelessWidget {
  const BrandBanner({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(compact ? 20 : 24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 48 : 56,
            height: compact ? 48 : 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
            ),
            child: Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: compact ? 24 : 28,
            ),
          ),
          SizedBox(width: compact ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppBranding.appName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 22 : 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: compact ? 2.5 : 3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppBranding.slogan,
                  maxLines: compact ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BrandWordmark extends StatelessWidget {
  const BrandWordmark({
    super.key,
    this.showSlogan = false,
    this.center = false,
    this.titleSize = 24,
    this.sloganSize = 12,
    this.maxSloganLines = 2,
  });

  final bool showSlogan;
  final bool center;
  final double titleSize;
  final double sloganSize;
  final int maxSloganLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (bounds) =>
              AppColors.primaryGradient.createShader(bounds),
          child: Text(
            AppBranding.appName,
            textAlign: center ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              color: Colors.white,
              fontSize: titleSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.8,
            ),
          ),
        ),
        if (showSlogan) ...[
          const SizedBox(height: 2),
          Text(
            AppBranding.slogan,
            maxLines: maxSloganLines,
            overflow: TextOverflow.ellipsis,
            textAlign: center ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.9),
              fontSize: sloganSize,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ],
      ],
    );
  }
}
