import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/providers.dart';
import '../widgets/awards_section.dart';
import '../widgets/detail_top_bar.dart';
import '../widgets/fullscreen_image_viewer.dart';
import '../widgets/score_badge.dart';
import '../widgets/smart_image.dart';
import 'add_to_group_dialog.dart';
import 'edit_movie_screen.dart';
import 'genre_movies_screen.dart';
import 'person_detail_screen.dart';

class MovieDetailScreen extends ConsumerWidget {
  final int movieId;
  const MovieDetailScreen({super.key, required this.movieId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moviesAsync = ref.watch(moviesStreamProvider);
    final colorScheme = Theme.of(context).colorScheme;

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
          final scanState = ref.watch(scanControllerProvider);
          final refreshing = scanState.status == ScanStatus.matching &&
              scanState.currentItem == movie.title;

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _MovieHero(
                      title: movie.title,
                      year: movie.year,
                      contentRating: movie.contentRating,
                      runtimeMinutes: movie.runtimeMinutes,
                      rating: movie.rating,
                      backdropUrl: backdropUrl,
                      posterUrl: posterUrl,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: () =>
                                launchUrl(Uri.file(movie.filePath)),
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: const Text('Play Movie'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                            ),
                          ),
                          if (movie.trailerFilePath != null)
                            OutlinedButton.icon(
                              onPressed: () => launchUrl(
                                Uri.file(movie.trailerFilePath!),
                              ),
                              icon: const Icon(Icons.play_circle_outline,
                                  size: 18),
                              label: const Text('Play Trailer'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                              ),
                            ),
                          FilledButton.tonalIcon(
                            onPressed: () => ref
                                .read(databaseProvider)
                                .setMovieWatched(movie.id, !movie.watched),
                            icon: Icon(
                              movie.watched
                                  ? Icons.check_circle
                                  : Icons.check_circle_outline,
                              size: 18,
                            ),
                            label: Text(
                              movie.watched ? 'Watched' : 'Mark as watched',
                            ),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              movie.isFavorite
                                  ? Icons.star
                                  : Icons.star_border,
                              color:
                                  movie.isFavorite ? Colors.amber : null,
                            ),
                            tooltip: 'Favorite',
                            onPressed: () => ref
                                .read(databaseProvider)
                                .setMovieFavorite(
                                    movie.id, !movie.isFavorite),
                          ),
                          if (movie.imdbId != null)
                            IconButton(
                              icon: const Icon(Icons.open_in_new),
                              tooltip: 'Open on IMDb',
                              onPressed: () => launchUrl(
                                Uri.parse(
                                  'https://www.imdb.com/title/${movie.imdbId}/',
                                ),
                                mode: LaunchMode.externalApplication,
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.playlist_add_outlined),
                            tooltip: 'Add to group',
                            onPressed: () => showAddToGroupDialog(
                              context,
                              ref,
                              kind: 'movie',
                              itemId: movie.id,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (movie.genres != null && movie.genres!.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                                  onPressed: () =>
                                      Navigator.of(context).push(
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
                        child: Text(
                          movie.overview!,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Builder(
                      builder: (context) {
                        final allCredits =
                            ref.watch(allCreditsStreamProvider).value ?? [];
                        final people =
                            ref.watch(peopleStreamProvider).value ?? [];
                        final peopleById = {
                          for (final p in people) p.id: p,
                        };
                        final movieCredits = allCredits
                            .where((c) => c.movieId == movie.id)
                            .toList();

                        if (movieCredits.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        final muted = colorScheme.onSurfaceVariant;

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
                                  style:
                                      TextStyle(fontSize: 12, color: muted),
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
                                        backgroundColor:
                                            colorScheme.surfaceContainerHighest,
                                        backgroundImage:
                                            person?.photoPath != null
                                                ? CachedNetworkImageProvider(
                                                    person!.photoPath!)
                                                : null,
                                        child: person?.photoPath == null
                                            ? const Icon(Icons.person,
                                                size: 14)
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

                        Widget castList() {
                          final entries = movieCredits
                              .where((c) => c.role == 'actor')
                              .toList();
                          if (entries.isEmpty) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CAST',
                                  style:
                                      TextStyle(fontSize: 12, color: muted),
                                ),
                                const SizedBox(height: 6),
                                ...entries.map((c) {
                                  final person = peopleById[c.personId];
                                  return InkWell(
                                    onTap: person == null
                                        ? null
                                        : () => Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    PersonDetailScreen(
                                                  personId: person.id,
                                                ),
                                              ),
                                            ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 6),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: colorScheme
                                                .surfaceContainerHighest,
                                            backgroundImage:
                                                person?.photoPath != null
                                                    ? CachedNetworkImageProvider(
                                                        person!.photoPath!)
                                                    : null,
                                            child: person?.photoPath == null
                                                ? const Icon(Icons.person,
                                                    size: 14)
                                                : null,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              person?.name ?? 'Unknown',
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w500),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              c.character ?? '',
                                              style: TextStyle(color: muted),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            roleSection('DIRECTOR', 'director'),
                            roleSection('WRITER', 'writer'),
                            castList(),
                            const SizedBox(height: 8),
                          ],
                        );
                      },
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: AwardsSection(
                      itemType: 'movie',
                      itemId: movie.id,
                      imdbId: movie.imdbId,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
              DetailTopBar(
                actions: [
                  HeroIconButton(
                    icon: refreshing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.refresh),
                    tooltip: 'Update metadata',
                    onPressed: refreshing
                        ? null
                        : () async {
                            final ok = await ref
                                .read(scanControllerProvider.notifier)
                                .refreshMovie(movie.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? 'Updated'
                                        : 'No match found — try Edit → '
                                            'Wrong match? instead',
                                  ),
                                ),
                              );
                            }
                          },
                  ),
                  HeroIconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditMovieScreen(movieId: movie.id),
                      ),
                    ),
                  ),
                  HeroIconButton(
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
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

/// The backdrop + gradient + poster + title/metadata/score hero block at
/// the top of the movie detail page. Intentionally stays dark with white
/// text regardless of the app's light/dark theme — a photo backdrop needs
/// a dark scrim for legibility either way, matching how most media apps
/// (Netflix, Plex, TMDB itself) treat this kind of hero image.
class _MovieHero extends StatelessWidget {
  final String title;
  final int? year;
  final String? contentRating;
  final int? runtimeMinutes;
  final double? rating;
  final String? backdropUrl;
  final String? posterUrl;

  const _MovieHero({
    required this.title,
    required this.year,
    required this.contentRating,
    required this.runtimeMinutes,
    required this.rating,
    required this.backdropUrl,
    required this.posterUrl,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () => FullscreenImageViewer.show(
              context,
              backdropUrl ?? posterUrl,
            ),
            child: backdropUrl != null
                ? SmartImage(
                    path: backdropUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (c) => Container(color: Colors.black),
                  )
                : Container(color: Colors.black),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.5, 1.0],
                colors: [
                  Colors.black.withOpacity(0.15),
                  Colors.black.withOpacity(0.45),
                  Colors.black.withOpacity(0.96),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () =>
                        FullscreenImageViewer.show(context, posterUrl),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 110,
                        height: 165,
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: posterUrl != null
                            ? SmartImage(path: posterUrl!, fit: BoxFit.cover)
                            : Container(color: Colors.white10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.15,
                          ),
                        ),
                        if (year != null ||
                            contentRating != null ||
                            runtimeMinutes != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              children: [
                                if (contentRating != null &&
                                    contentRating!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.white54),
                                      borderRadius:
                                          BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      contentRating!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                Text(
                                  [
                                    if (year != null) '$year',
                                    if (runtimeMinutes != null)
                                      '${runtimeMinutes! ~/ 60}h '
                                          '${runtimeMinutes! % 60}m',
                                  ].join('  •  '),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (rating != null && rating! > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              children: [
                                ScoreBadge(rating: rating, size: 40),
                                const SizedBox(width: 8),
                                const Text(
                                  'User\nScore',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    height: 1.1,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
