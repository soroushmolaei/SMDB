import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/providers.dart';
import '../widgets/awards_section.dart';
import '../widgets/credits_grid.dart';
import '../widgets/detail_top_bar.dart';
import '../widgets/fullscreen_image_viewer.dart';
import '../widgets/personal_rating_stars.dart';
import '../widgets/refresh_metadata_button.dart';
import '../widgets/score_badge.dart';
import '../widgets/smart_image.dart';
import '../widgets/watch_history_section.dart';
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
    final overlayOpacity =
        ref.watch(themeControllerProvider).backdropOverlayOpacity;

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
              // Fixed, full-page backdrop. A sibling of the
              // CustomScrollView (not a sliver inside it), so it never
              // moves as the content below is scrolled up and down.
              Positioned.fill(
                child: backdropUrl != null
                    ? SmartImage(
                        path: backdropUrl,
                        fit: BoxFit.cover,
                        thumbnailBytes: movie.backdropThumbnail,
                        errorBuilder: (c) => Container(color: Colors.black),
                      )
                    : Container(color: Colors.black),
              ),
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: overlayOpacity),
                ),
              ),
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _MovieHero(
                      title: movie.title,
                      originalTitle: movie.originalTitle,
                      year: movie.year,
                      contentRating: movie.contentRating,
                      runtimeMinutes: movie.runtimeMinutes,
                      rating: movie.rating,
                      genres: movie.genres,
                      backdropUrl: backdropUrl,
                      posterUrl: posterUrl,
                      posterThumbnail: movie.posterThumbnail,
                      isFavorite: movie.isFavorite,
                      watched: movie.watched,
                      personalRating: movie.personalRating,
                      onSetPersonalRating: (value) => ref
                          .read(databaseProvider)
                          .setPersonalRating(movie.id, value),
                      onToggleFavorite: () => ref
                          .read(databaseProvider)
                          .setMovieFavorite(movie.id, !movie.isFavorite),
                      onToggleWatched: () => ref
                          .read(databaseProvider)
                          .setMovieWatched(movie.id, !movie.watched),
                      onViewHistory: () => showWatchHistoryDialog(
                        context,
                        itemType: 'movie',
                        itemId: movie.id,
                        title: movie.title,
                      ),
                      onAddToGroup: () => showAddToGroupDialog(
                        context,
                        ref,
                        kind: 'movie',
                        itemId: movie.id,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    // The whole page shares the one fixed backdrop behind
                    // it now — no opaque panel here, so content sits
                    // directly over the image+tint the same way the hero
                    // does.
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
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
                                    icon: const Icon(
                                        Icons.play_circle_outline,
                                        size: 18),
                                    label: const Text('Play Trailer'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                    ),
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
                              ],
                            ),
                          ),
                          if (movie.genres != null &&
                              movie.genres!.isNotEmpty)
                            Padding(
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
                          if (movie.overview != null &&
                              movie.overview!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                movie.overview!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          Builder(
                            builder: (context) {
                              final allCredits =
                                  ref.watch(allCreditsStreamProvider).value ??
                                      [];
                              final people =
                                  ref.watch(peopleStreamProvider).value ??
                                      [];
                              final peopleById = {
                                for (final p in people) p.id: p,
                              };
                              final movieCredits = allCredits
                                  .where((c) => c.movieId == movie.id)
                                  .toList();

                              void onTap(int personId) =>
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => PersonDetailScreen(
                                          personId: personId),
                                    ),
                                  );

                              final directors = buildRoleEntries(
                                credits: movieCredits
                                    .where((c) => c.role == 'director'),
                                personIdOf: (c) => c.personId,
                                labelOf: (c) => 'Director',
                                nameOf: (id) => peopleById[id]?.name,
                                photoPathOf: (id) =>
                                    peopleById[id]?.photoPath,
                              );
                              final writers = buildRoleEntries(
                                credits: movieCredits
                                    .where((c) => c.role == 'writer'),
                                personIdOf: (c) => c.personId,
                                labelOf: (c) => 'Writer',
                                nameOf: (id) => peopleById[id]?.name,
                                photoPathOf: (id) =>
                                    peopleById[id]?.photoPath,
                              );
                              final cast = buildRoleEntries(
                                credits: movieCredits
                                    .where((c) => c.role == 'actor'),
                                personIdOf: (c) => c.personId,
                                labelOf: (c) => c.character != null &&
                                        c.character!.isNotEmpty
                                    ? c.character!
                                    : 'Actor',
                                nameOf: (id) => peopleById[id]?.name,
                                photoPathOf: (id) =>
                                    peopleById[id]?.photoPath,
                              );

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CreditsSection(
                                    title: 'DIRECTOR',
                                    entries: directors,
                                    onTap: onTap,
                                  ),
                                  CreditsSection(
                                    title: 'WRITER',
                                    entries: writers,
                                    onTap: onTap,
                                  ),
                                  CreditsSection(
                                    title: 'CAST',
                                    entries: cast,
                                    onTap: onTap,
                                  ),
                                ],
                              );
                            },
                          ),
                          AwardsSection(
                            itemType: 'movie',
                            itemId: movie.id,
                            imdbId: movie.imdbId,
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                ],
              ),
              DetailTopBar(
                actions: [
                  RefreshMetadataButton(
                    busy: refreshing,
                    onSelected: (mode) async {
                      final ok = await ref
                          .read(scanControllerProvider.notifier)
                          .refreshMovie(movie.id, mode: mode);
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

/// The poster + title/metadata/score block at the top of the movie detail
/// page. Sits on top of the page-level fixed backdrop (see
/// [MovieDetailScreen]) instead of painting its own image — text here
/// stays white regardless of the app's light/dark theme, since a photo
/// backdrop needs light text for legibility either way.
class _MovieHero extends StatelessWidget {
  final String title;
  final String? originalTitle;
  final int? year;
  final String? contentRating;
  final int? runtimeMinutes;
  final double? rating;
  final String? genres;
  final String? backdropUrl;
  final String? posterUrl;
  final Uint8List? posterThumbnail;
  final bool isFavorite;
  final bool watched;
  final VoidCallback onToggleFavorite;
  final VoidCallback onToggleWatched;
  final VoidCallback onViewHistory;
  final VoidCallback onAddToGroup;
  final double? personalRating;
  final ValueChanged<double?> onSetPersonalRating;

  const _MovieHero({
    required this.title,
    required this.originalTitle,
    required this.year,
    required this.contentRating,
    required this.runtimeMinutes,
    required this.rating,
    required this.genres,
    required this.backdropUrl,
    required this.posterUrl,
    required this.posterThumbnail,
    required this.isFavorite,
    required this.watched,
    required this.onToggleFavorite,
    required this.onToggleWatched,
    required this.onViewHistory,
    required this.onAddToGroup,
    required this.personalRating,
    required this.onSetPersonalRating,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 440,
      child: GestureDetector(
        // Tapping empty hero space still opens the fullscreen backdrop
        // viewer, even though the image itself is painted a layer below.
        behavior: HitTestBehavior.translucent,
        onTap: () => FullscreenImageViewer.show(
          context,
          backdropUrl ?? posterUrl,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 40),
          child: Center(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () =>
                      FullscreenImageViewer.show(context, posterUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 130,
                      height: 195,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: posterUrl != null
                          ? SmartImage(
                              path: posterUrl!,
                              fit: BoxFit.cover,
                              thumbnailBytes: posterThumbnail,
                            )
                          : Container(color: Colors.white10),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.15,
                          ),
                          children: [
                            TextSpan(text: title),
                            if (year != null)
                              TextSpan(
                                text: ' ($year)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white70,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (originalTitle != null &&
                          originalTitle!.isNotEmpty &&
                          originalTitle != title)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            originalTitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      if (contentRating != null ||
                          genres != null ||
                          runtimeMinutes != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (contentRating != null &&
                                  contentRating!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.white54),
                                    borderRadius: BorderRadius.circular(3),
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
                                  if (genres != null && genres!.isNotEmpty)
                                    genres!
                                        .split(',')
                                        .map((g) => g.trim())
                                        .where((g) => g.isNotEmpty)
                                        .join(', '),
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
                          padding: const EdgeInsets.only(top: 14),
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
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Row(
                          children: [
                            PersonalRatingStars(
                              value: personalRating,
                              onChanged: onSetPersonalRating,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Your\nRating',
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
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          children: [
                            HeroIconButton(
                              icon: Icon(
                                isFavorite ? Icons.star : Icons.star_border,
                                color: isFavorite ? Colors.amber : null,
                              ),
                              tooltip: 'Favorite',
                              onPressed: onToggleFavorite,
                            ),
                            HeroIconButton(
                              icon: Icon(
                                watched
                                    ? Icons.check_circle
                                    : Icons.check_circle_outline,
                              ),
                              tooltip: watched
                                  ? 'Watched'
                                  : 'Mark as watched',
                              onPressed: onToggleWatched,
                            ),
                            HeroIconButton(
                              icon: const Icon(Icons.history),
                              tooltip: 'Watch history',
                              onPressed: onViewHistory,
                            ),
                            HeroIconButton(
                              icon: const Icon(
                                  Icons.playlist_add_outlined),
                              tooltip: 'Add to group',
                              onPressed: onAddToGroup,
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
      ),
    );
  }
}
