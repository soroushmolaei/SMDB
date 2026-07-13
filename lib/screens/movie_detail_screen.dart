import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../widgets/fullscreen_image_viewer.dart';
import 'edit_movie_screen.dart';
import 'genre_movies_screen.dart';
import 'person_detail_screen.dart';

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
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditMovieScreen(movieId: movie.id),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete',
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Delete movie?'),
                          content: Text(
                            'This removes "${movie.title}" from your '
                            'library. The video file on disk is not '
                            'touched.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await ref
                            .read(databaseProvider)
                            .deleteMovie(movie.id);
                        if (context.mounted) Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: GestureDetector(
                    onTap: () => FullscreenImageViewer.show(
                      context,
                      backdropUrl ?? posterUrl,
                    ),
                    child: backdropUrl != null
                        ? CachedNetworkImage(
                            imageUrl: backdropUrl,
                            fit: BoxFit.cover,
                            errorWidget: (c, u, e) =>
                                Container(color: Colors.black26),
                          )
                        : Container(color: Colors.black26),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () =>
                            FullscreenImageViewer.show(context, posterUrl),
                        child: ClipRRect(
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
                            if (movie.year != null ||
                                movie.contentRating != null ||
                                movie.runtimeMinutes != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  [
                                    if (movie.year != null) '${movie.year}',
                                    if (movie.contentRating != null &&
                                        movie.contentRating!.isNotEmpty)
                                      movie.contentRating!,
                                    if (movie.runtimeMinutes != null)
                                      '${movie.runtimeMinutes} min',
                                  ].join(' • '),
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
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: movie.genres!
                          .split(',')
                          .map((g) => g.trim())
                          .where((g) => g.isNotEmpty)
                          .map(
                            (g) => ActionChip(
                              label: Text(g),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      GenreMoviesScreen(genre: g),
                                ),
                              ),
                            ),
                          )
                          .toList(),
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
              SliverToBoxAdapter(
                child: Builder(
                  builder: (context) {
                    final allCredits =
                        ref.watch(allCreditsStreamProvider).value ?? [];
                    final people =
                        ref.watch(peopleStreamProvider).value ?? [];
                    final peopleById = {for (final p in people) p.id: p};
                    final movieCredits = allCredits
                        .where((c) => c.movieId == movie.id)
                        .toList();

                    if (movieCredits.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    Widget roleSection(String title, String role) {
                      final entries = movieCredits
                          .where((c) => c.role == role)
                          .toList();
                      if (entries.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white38,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: entries.map((c) {
                                final person = peopleById[c.personId];
                                final label = person?.name ?? 'Unknown';
                                return ActionChip(
                                  avatar: CircleAvatar(
                                    backgroundColor: Colors.white10,
                                    backgroundImage:
                                        person?.photoPath != null
                                            ? CachedNetworkImageProvider(
                                                person!.photoPath!)
                                            : null,
                                    child: person?.photoPath == null
                                        ? const Icon(Icons.person, size: 14)
                                        : null,
                                  ),
                                  label: Text(
                                    c.character != null &&
                                            c.character!.isNotEmpty
                                        ? '$label (${c.character})'
                                        : label,
                                  ),
                                  onPressed: person == null
                                      ? null
                                      : () => Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  PersonDetailScreen(
                                                personId: person.id,
                                              ),
                                            ),
                                          ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        roleSection('DIRECTOR', 'director'),
                        roleSection('WRITER', 'writer'),
                        roleSection('CAST', 'actor'),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
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
