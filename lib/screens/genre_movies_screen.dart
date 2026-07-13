import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../widgets/poster_card.dart';
import 'movie_detail_screen.dart';

class GenreMoviesScreen extends ConsumerWidget {
  final String genre;
  const GenreMoviesScreen({super.key, required this.genre});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moviesAsync = ref.watch(moviesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: Text(genre)),
      body: moviesAsync.when(
        data: (movies) {
          final filtered = movies.where((m) {
            final genres =
                (m.genres ?? '').split(',').map((g) => g.trim());
            return genres.contains(genre);
          }).toList();

          if (filtered.isEmpty) {
            return const Center(
              child: Text(
                'No movies in this genre',
                style: TextStyle(color: Colors.white54),
              ),
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
