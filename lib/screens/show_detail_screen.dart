import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../database/database.dart';
import '../providers/providers.dart';
import '../widgets/awards_section.dart';
import '../widgets/credits_grid.dart';
import '../widgets/detail_top_bar.dart';
import '../widgets/fullscreen_image_viewer.dart';
import '../widgets/score_badge.dart';
import '../widgets/smart_image.dart';
import 'add_to_group_dialog.dart';
import 'edit_show_screen.dart';
import 'genre_shows_screen.dart';
import 'person_detail_screen.dart';

class ShowDetailScreen extends ConsumerWidget {
  final int showId;
  const ShowDetailScreen({super.key, required this.showId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showsAsync = ref.watch(showsStreamProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: showsAsync.when(
        data: (shows) {
          final matches = shows.where((s) => s.id == showId);
          final show = matches.isEmpty ? null : matches.first;
          if (show == null) {
            return const Center(child: Text('Show not found'));
          }

          final episodes =
              ref.watch(episodesForShowProvider(showId)).value ?? [];
          final allShowCredits =
              ref.watch(allShowCreditsStreamProvider).value ?? [];
          final people = ref.watch(peopleStreamProvider).value ?? [];
          final peopleById = {for (final p in people) p.id: p};
          final showCredits =
              allShowCredits.where((c) => c.showId == show.id).toList();

          final seasons = episodes.map((e) => e.seasonNumber).toSet().toList()
            ..sort();

          final scanState = ref.watch(scanControllerProvider);
          final refreshing = scanState.status == ScanStatus.matching &&
              scanState.currentItem == show.title;

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _ShowHero(
                      title: show.title,
                      contentRating: show.contentRating,
                      status: show.status,
                      rating: show.rating,
                      genres: show.genres,
                      backdropUrl: show.backdropPath,
                      posterUrl: show.posterPath,
                      backdropThumbnail: show.backdropThumbnail,
                      posterThumbnail: show.posterThumbnail,
                      isFavorite: show.isFavorite,
                      onToggleFavorite: () => ref
                          .read(databaseProvider)
                          .setShowFavorite(show.id, !show.isFavorite),
                      onAddToGroup: () => showAddToGroupDialog(
                        context,
                        ref,
                        kind: 'show',
                        itemId: show.id,
                      ),
                    ),
                  ),
                  if (show.imdbId != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => launchUrl(
                                Uri.parse(
                                  'https://www.imdb.com/title/${show.imdbId}/',
                                ),
                                mode: LaunchMode.externalApplication,
                              ),
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: const Text('Open on IMDb'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (show.genres != null && show.genres!.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: show.genres!
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
                                          GenreShowsScreen(genre: g),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  if (show.overview != null && show.overview!.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          show.overview!,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  if (showCredits.isNotEmpty)
                    SliverToBoxAdapter(
                      child: CreditsGrid(
                        entries: buildCreditEntries(
                          credits: showCredits,
                          personIdOf: (c) => c.personId,
                          roleOf: (c) => c.role,
                          characterOf: (c) => c.character,
                          nameOf: (id) => peopleById[id]?.name,
                          photoPathOf: (id) => peopleById[id]?.photoPath,
                        ),
                        onTap: (personId) => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                PersonDetailScreen(personId: personId),
                          ),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: AwardsSection(
                      itemType: 'show',
                      itemId: show.id,
                      imdbId: show.imdbId,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Text(
                        'Episodes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  if (seasons.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'No episodes found.',
                          style:
                              TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final season = seasons[index];
                          final seasonEpisodes = episodes
                              .where((e) => e.seasonNumber == season)
                              .toList()
                            ..sort((a, b) =>
                                a.episodeNumber.compareTo(b.episodeNumber));
                          return ExpansionTile(
                            title: Text('Season $season'),
                            subtitle:
                                Text('${seasonEpisodes.length} episodes'),
                            children: seasonEpisodes
                                .map((ep) => _EpisodeTile(episode: ep))
                                .toList(),
                          );
                        },
                        childCount: seasons.length,
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
                                .refreshShow(show.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text(ok ? 'Updated' : 'No match found'),
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
                        builder: (_) => EditShowScreen(showId: show.id),
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
                          title: const Text('Delete show?'),
                          content: Text(
                            'This removes "${show.title}" and its episode '
                            'list from your library. Video files on disk '
                            'are not touched.',
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
                        await ref.read(databaseProvider).deleteShow(show.id);
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
/// the top of the show detail page. Intentionally stays dark with white
/// text regardless of the app's light/dark theme, matching the movie
/// detail hero and most media apps' treatment of a photographic backdrop.
class _ShowHero extends StatelessWidget {
  final String title;
  final String? contentRating;
  final String? status;
  final double? rating;
  final String? genres;
  final String? backdropUrl;
  final String? posterUrl;
  final Uint8List? backdropThumbnail;
  final Uint8List? posterThumbnail;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onAddToGroup;

  const _ShowHero({
    required this.title,
    required this.contentRating,
    required this.status,
    required this.rating,
    required this.genres,
    required this.backdropUrl,
    required this.posterUrl,
    required this.backdropThumbnail,
    required this.posterThumbnail,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onAddToGroup,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 440,
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
                    thumbnailBytes: backdropThumbnail,
                    errorBuilder: (c) => Container(color: Colors.black),
                  )
                : Container(color: Colors.black),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.35, 0.75, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.2),
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.8),
                  Colors.black,
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 64,
            bottom: 20,
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
                      if (contentRating != null ||
                          genres != null ||
                          status != null)
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
                                  if (status != null && status!.isNotEmpty)
                                    status!,
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
        ],
      ),
    );
  }
}

class _EpisodeTile extends ConsumerWidget {
  final Episode episode;
  const _EpisodeTile({required this.episode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaceVariant = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ListTile(
      leading: GestureDetector(
        onTap: () =>
            FullscreenImageViewer.show(context, episode.stillPath),
        child: SizedBox(
          width: 64,
          height: 40,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: episode.stillPath != null
                ? CachedNetworkImage(
                    imageUrl: episode.stillPath!,
                    fit: BoxFit.cover,
                    errorWidget: (c, u, e) => Container(color: surfaceVariant),
                  )
                : Container(
                    color: surfaceVariant,
                    child: const Icon(Icons.tv_outlined,
                        color: Colors.white24, size: 16),
                  ),
          ),
        ),
      ),
      title: Text(
        'E${episode.episodeNumber} '
        '${episode.title != null && episode.title!.isNotEmpty ? '· ${episode.title}' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          if (episode.airDate != null && episode.airDate!.isNotEmpty)
            Text(episode.airDate!),
          if (episode.rating != null && episode.rating! > 0) ...[
            if (episode.airDate != null && episode.airDate!.isNotEmpty)
              const Text('  •  '),
            const Icon(Icons.star, size: 12, color: Colors.amber),
            const SizedBox(width: 2),
            Text(episode.rating!.toStringAsFixed(1)),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Play episode',
            onPressed: () => launchUrl(Uri.file(episode.filePath)),
          ),
          IconButton(
            icon: Icon(
              episode.watched
                  ? Icons.check_circle
                  : Icons.check_circle_outline,
              color: episode.watched ? Colors.greenAccent.shade400 : null,
            ),
            onPressed: () => ref
                .read(databaseProvider)
                .setEpisodeWatched(episode.id, !episode.watched),
          ),
        ],
      ),
      onTap: () {
        final hasOverview =
            episode.overview != null && episode.overview!.isNotEmpty;
        if (!hasOverview && episode.rating == null) return;
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              'S${episode.seasonNumber}E${episode.episodeNumber}'
              '${episode.title != null ? ' – ${episode.title}' : ''}',
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (episode.rating != null && episode.rating! > 0) ...[
                      Row(
                        children: [
                          const Icon(Icons.star,
                              size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(episode.rating!.toStringAsFixed(1)),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (hasOverview) Text(episode.overview!),
                    Consumer(
                      builder: (context, ref, _) {
                        final credits =
                            ref.watch(episodeCreditsProvider(episode.id));
                        final people =
                            ref.watch(peopleStreamProvider).value ?? [];
                        final peopleById = {
                          for (final p in people) p.id: p,
                        };
                        return credits.when(
                          data: (entries) {
                            if (entries.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'GUEST STARS',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white38,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  ...entries.map((credit) {
                                    final person =
                                        peopleById[credit.personId];
                                    return InkWell(
                                      onTap: person == null
                                          ? null
                                          : () {
                                              Navigator.of(context).pop();
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      PersonDetailScreen(
                                                    personId: person.id,
                                                  ),
                                                ),
                                              );
                                            },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 13,
                                              backgroundColor:
                                                  Colors.white10,
                                              backgroundImage: person
                                                          ?.photoPath !=
                                                      null
                                                  ? CachedNetworkImageProvider(
                                                      person!.photoPath!)
                                                  : null,
                                              child: person?.photoPath ==
                                                      null
                                                  ? const Icon(Icons.person,
                                                      size: 12)
                                                  : null,
                                            ),
                                            const SizedBox(width: 8),
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
                                                credit.character ?? '',
                                                style: const TextStyle(
                                                    color: Colors.white54),
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
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (e, st) => const SizedBox.shrink(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }
}
