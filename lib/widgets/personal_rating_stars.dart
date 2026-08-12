import 'package:flutter/material.dart';

/// Interactive 5-star control for the user's own 0-10 rating (distinct
/// from ScoreBadge, which shows TMDB/OMDb's community score). Each star
/// covers two points, so a left/right tap gives half-star precision and
/// 10 discrete levels overall. Hovering previews the value before it's
/// set; tapping the star that already matches the current rating clears
/// it.
class PersonalRatingStars extends StatefulWidget {
  final double? value;
  final ValueChanged<double?> onChanged;
  final double size;

  const PersonalRatingStars({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 20,
  });

  @override
  State<PersonalRatingStars> createState() => _PersonalRatingStarsState();
}

class _PersonalRatingStarsState extends State<PersonalRatingStars> {
  int? _hoverValue;

  int? get _snappedValue => widget.value?.clamp(1.0, 10.0).round();

  int _valueForTapX(double dx, int starIndex) {
    final isLeftHalf = dx < widget.size / 2;
    return starIndex * 2 + (isLeftHalf ? 1 : 2);
  }

  void _handleTap(double dx, int starIndex) {
    final tapped = _valueForTapX(dx, starIndex);
    final wasAlreadySet = _snappedValue == tapped;
    widget.onChanged(wasAlreadySet ? null : tapped.toDouble());
    setState(() => _hoverValue = null);
  }

  @override
  Widget build(BuildContext context) {
    final snapped = _snappedValue;
    final display = _hoverValue ?? snapped;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++) _buildStar(i, display),
        if (snapped != null) ...[
          const SizedBox(width: 6),
          Text(
            '$snapped/10',
            style: TextStyle(
              color: Colors.amber,
              fontSize: widget.size * 0.55,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 2),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => widget.onChanged(null),
              child: Icon(
                Icons.close,
                size: widget.size * 0.6,
                color: Colors.white38,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStar(int index, int? display) {
    IconData icon;
    if (display == null) {
      icon = Icons.star_border;
    } else {
      final covered = display - index * 2;
      if (covered >= 2) {
        icon = Icons.star;
      } else if (covered >= 1) {
        icon = Icons.star_half;
      } else {
        icon = Icons.star_border;
      }
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onHover: (event) => setState(
        () => _hoverValue = _valueForTapX(event.localPosition.dx, index),
      ),
      onExit: (_) => setState(() => _hoverValue = null),
      child: GestureDetector(
        onTapDown: (details) => _handleTap(details.localPosition.dx, index),
        child: Icon(icon, size: widget.size, color: Colors.amber),
      ),
    );
  }
}
