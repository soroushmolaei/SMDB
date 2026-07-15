import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import 'genre_movies_screen.dart';

class GenresListScreen extends ConsumerWidget {
  const GenresListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moviesAsync = ref.watch(moviesStreamProvider);

    return moviesAsync.when(
      data: (movies) {
        final counts = <String, int>{};
        for (final m in movies) {
          if (m.genres == null) continue;
          for (final g in m.genres!.split(',')) {
            final trimmed = g.trim();
            if (trimmed.isEmpty) continue;
            counts[trimmed] = (counts[trimmed] ?? 0) + 1;
          }
        }
        final genres = counts.keys.toList()..sort();

        if (genres.isEmpty) {
          return const Center(
            child: Text(
              'No genres yet — scan a movie folder first.',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            childAspectRatio: 3.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: genres.length,
          itemBuilder: (context, index) {
            final genre = genres[index];
            return Card(
              color: Colors.white.withOpacity(0.05),
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GenreMoviesScreen(genre: genre),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.local_offer_outlined,
                          color: Color(0xFF9C91F5)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          genre,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        '${counts[genre]}',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}
