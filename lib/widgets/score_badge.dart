import 'package:flutter/material.dart';

/// A circular percentage badge for a 0-10 rating, styled like TMDB's
/// "User Score" indicator — green/yellow/red depending on the score.
class ScoreBadge extends StatelessWidget {
  final double? rating;
  final double size;

  const ScoreBadge({super.key, required this.rating, this.size = 44});

  @override
  Widget build(BuildContext context) {
    if (rating == null || rating! <= 0) return const SizedBox.shrink();
    final pct = (rating! * 10).round().clamp(0, 100);
    final Color color;
    if (pct >= 70) {
      color = const Color(0xFF21D07A);
    } else if (pct >= 40) {
      color = const Color(0xFFD2D531);
    } else {
      color = const Color(0xFFDB2360);
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: pct / 100,
              strokeWidth: 3.5,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Text(
            '$pct%',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: size * 0.3,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
