import 'package:flutter/material.dart';

import 'smart_image.dart';

class PosterCard extends StatelessWidget {
  final String title;
  final String? posterUrl;
  final bool watched;
  final VoidCallback onTap;
  final VoidCallback? onToggleWatched;

  const PosterCard({
    super.key,
    required this.title,
    required this.posterUrl,
    required this.watched,
    required this.onTap,
    this.onToggleWatched,
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
                  child: posterUrl != null && posterUrl!.isNotEmpty
                      ? SmartImage(
                          path: posterUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context) => _fallback(),
                        )
                      : _fallback(),
                ),
                if (onToggleWatched != null)
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

  Widget _fallback() {
    return Container(
      color: Colors.white10,
      alignment: Alignment.center,
      child: const Icon(
        Icons.movie_outlined,
        color: Colors.white24,
        size: 40,
      ),
    );
  }
}
