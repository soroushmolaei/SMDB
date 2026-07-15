import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../widgets/poster_card.dart';
import 'movie_detail_screen.dart';

class MpaListScreen extends ConsumerWidget {
  const MpaListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moviesAsync = ref.watch(moviesStreamProvider);

    return moviesAsync.when(
      data: (movies) {
        final counts = <String, int>{};
        for (final m in movies) {
          final rating = m.contentRating;
          if (rating == null || rating.isEmpty) continue;
          counts[rating] = (counts[rating] ?? 0) + 1;
        }
        final ratings = counts.keys.toList()..sort();

        if (ratings.isEmpty) {
          return const Center(
            child: Text(
              'No content ratings yet — scan a movie folder first.',
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
          itemCount: ratings.length,
          itemBuilder: (context, index) {
            final rating = ratings[index];
            return Card(
              color: Colors.white.withOpacity(0.05),
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MpaMoviesScreen(rating: rating),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined,
                          color: Color(0xFF9C91F5)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          rating,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        '${counts[rating]}',
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

class MpaMoviesScreen extends ConsumerWidget {
  final String rating;
  const MpaMoviesScreen({super.key, required this.rating});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moviesAsync = ref.watch(moviesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: Text(rating)),
      body: moviesAsync.when(
        data: (movies) {
          final filtered =
              movies.where((m) => m.contentRating == rating).toList();
          if (filtered.isEmpty) {
            return const Center(
              child: Text('No movies with this rating',
                  style: TextStyle(color: Colors.white54)),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 150,
              childAspectRatio: 0.55,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final movie = filtered[index];
              return PosterCard(
                title: movie.title,
                posterUrl: movie.posterPath,
                watched: movie.watched,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MovieDetailScreen(movieId: movie.id),
                  ),
                ),
                onToggleWatched: () => ref
                    .read(databaseProvider)
                    .setMovieWatched(movie.id, !movie.watched),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
