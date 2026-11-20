import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

import 'smart_image.dart';

/// A movie/show poster with the title below it, used by every library
/// grid. On hover (desktop) the poster lifts with a soft shadow and a
/// slight zoom; the year and community rating always sit on a bottom
/// gradient over the poster, so they stay legible on any image.
class PosterCard extends StatefulWidget {
  final String title;
  final String? posterUrl;
  final Uint8List? thumbnailBytes;
  final int? year;
  final double? rating;
  final bool watched;
  final VoidCallback onTap;
  final VoidCallback? onToggleWatched;
  final bool selectionMode;
  final bool selected;

  const PosterCard({
    super.key,
    required this.title,
    required this.posterUrl,
    this.thumbnailBytes,
    this.year,
    this.rating,
    required this.watched,
    required this.onTap,
    this.onToggleWatched,
    this.selectionMode = false,
    this.selected = false,
  });

  @override
  State<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<PosterCard> {
  bool _hovering = false;

  bool get _hasMeta =>
      widget.year != null || (widget.rating != null && widget.rating! > 0);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AnimatedScale(
                scale: _hovering ? 1.03 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                            alpha: _hovering ? 0.35 : 0),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        widget.posterUrl != null &&
                                widget.posterUrl!.isNotEmpty
                            ? SmartImage(
                                path: widget.posterUrl!,
                                fit: BoxFit.cover,
                                thumbnailBytes: widget.thumbnailBytes,
                                errorBuilder: (context) => _fallback(context),
                              )
                            : _fallback(context),
                        if (_hasMeta)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding:
                                  const EdgeInsets.fromLTRB(8, 20, 8, 6),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black87
                                  ],
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (widget.year != null)
                                    Text(
                                      '${widget.year}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  const Spacer(),
                                  if (widget.rating != null &&
                                      widget.rating! > 0)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star,
                                            size: 12, color: Colors.amber),
                                        const SizedBox(width: 2),
                                        Text(
                                          widget.rating!.toStringAsFixed(1),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        if (widget.selectionMode)
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black45,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                widget.selected
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 20,
                                color: widget.selected
                                    ? context.appColors.accent
                                    : Colors.white70,
                              ),
                            ),
                          )
                        else if (widget.onToggleWatched != null)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: widget.onToggleWatched,
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor: widget.watched
                                    ? Colors.greenAccent.shade400
                                    : Colors.black54,
                                child: Icon(
                                  Icons.check,
                                  size: 16,
                                  color: widget.watched
                                      ? Colors.black
                                      : Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        if (widget.selected)
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: context.appColors.accent,
                                width: 3,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      color: context.appColors.surfaceSubtle,
      alignment: Alignment.center,
      child: Icon(
        Icons.movie_outlined,
        color: context.appColors.textHint,
        size: 40,
      ),
    );
  }
}
