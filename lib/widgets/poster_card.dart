import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

import 'smart_image.dart';

class PosterCard extends StatelessWidget {
  final String title;
  final String? posterUrl;
  final Uint8List? thumbnailBytes;
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
    required this.watched,
    required this.onTap,
    this.onToggleWatched,
    this.selectionMode = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: selected
                        ? BoxDecoration(
                            border: Border.all(
                              color: context.appColors.accent,
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          )
                        : null,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: posterUrl != null && posterUrl!.isNotEmpty
                          ? SmartImage(
                              path: posterUrl!,
                              fit: BoxFit.cover,
                              thumbnailBytes: thumbnailBytes,
                              errorBuilder: (context) => _fallback(context),
                            )
                          : _fallback(context),
                    ),
                  ),
                ),
                if (selectionMode)
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
                        selected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 20,
                        color: selected
                            ? context.appColors.accent
                            : Colors.white70,
                      ),
                    ),
                  )
                else if (onToggleWatched != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: onToggleWatched,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: watched
                            ? Colors.greenAccent.shade400
                            : Colors.black54,
                        child: Icon(
                          Icons.check,
                          size: 16,
                          color: watched ? Colors.black : Colors.white70,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
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
