import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../models/player_stats.dart';

class ResultCircle extends StatelessWidget {
  final int score;
  final int total;
  const ResultCircle({super.key, required this.score, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : score / total;
    return SizedBox(
      width: 110, height: 110,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox(
          width: 110, height: 110,
          child: CircularProgressIndicator(
            value: pct, strokeWidth: 10,
            color: AppTheme.primary,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
          ),
        ),
        Text('$score/$total',
            style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primary)),
      ]),
    );
  }
}

class XpBar extends StatelessWidget {
  final PlayerStats stats;
  const XpBar({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final xpInLevel = stats.xp % 100;
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Level ${stats.level}',
            style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text('${stats.xp} XP total',
            style: GoogleFonts.nunito(fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
      const SizedBox(height: 4),
      LinearProgressIndicator(
        value: xpInLevel / 100,
        color: AppTheme.primary,
        backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
        minHeight: 8,
        borderRadius: BorderRadius.circular(4),
      ),
    ]);
  }
}

class StreakRow extends StatelessWidget {
  final PlayerStats stats;
  const StreakRow({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('🔥', style: TextStyle(fontSize: 20)),
      const SizedBox(width: 4),
      Text('${stats.streak} day streak',
          style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700)),
      if (stats.shields > 0) ...[
        const SizedBox(width: 12),
        const Text('🛡', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 4),
        Text('×${stats.shields}',
            style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700)),
      ],
      if (stats.streakAtRisk) ...[
        const SizedBox(width: 8),
        Text('at risk!',
            style: GoogleFonts.nunito(fontSize: 13, color: AppTheme.error, fontWeight: FontWeight.w700)),
      ],
    ]);
  }
}
