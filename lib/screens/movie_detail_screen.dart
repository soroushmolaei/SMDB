import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

class MovieDetailScreen extends ConsumerWidget {
  final int movieId;
  const MovieDetailScreen({super.key, required this.movieId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moviesAsync = ref.watch(moviesStreamProvider);

    return Scaffold(
      body: moviesAsync.when(
        data: (movies) {
          final matches = movies.where((m) => m.id == movieId);
          final movie = matches.isEmpty ? null : matches.first;
          if (movie == null) {
            return const Center(child: Text('Movie not found'));
          }

          final backdropUrl = movie.backdropPath;
          final posterUrl = movie.posterPath;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: backdropUrl != null
                      ? CachedNetworkImage(
                          imageUrl: backdropUrl,
                          fit: BoxFit.cover,
                          errorWidget: (c, u, e) =>
                              Container(color: Colors.black26),
                        )
                      : Container(color: Colors.black26),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 110,
                          height: 165,
                          child: posterUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: posterUrl,
                                  fit: BoxFit.cover,
                                )
                              : Container(color: Colors.white10),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              movie.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (movie.year != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  movie.runtimeMinutes != null
                                      ? '${movie.year} • ${movie.runtimeMinutes} min'
                                      : '${movie.year}',
                                  style:
                                      const TextStyle(color: Colors.white54),
                                ),
                              ),
                            if (movie.rating != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star,
                                        size: 16, color: Colors.amber),
                                    const SizedBox(width: 4),
                                    Text(movie.rating!.toStringAsFixed(1)),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              onPressed: () => ref
                                  .read(databaseProvider)
                                  .setMovieWatched(movie.id, !movie.watched),
                              icon: Icon(
                                movie.watched
                                    ? Icons.check_circle
                                    : Icons.check_circle_outline,
                              ),
                              label: Text(
                                movie.watched ? 'Watched' : 'Mark as watched',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (movie.genres != null && movie.genres!.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      movie.genres!,
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ),
                ),
              if (movie.overview != null && movie.overview!.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(movie.overview!),
                  ),
                ),
              if (movie.director != null && movie.director!.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Director: ${movie.director}'),
                  ),
                ),
              if (movie.castNames != null && movie.castNames!.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Cast: ${movie.castNames}'),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
