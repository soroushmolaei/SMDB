import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../providers/providers.dart';
import '../widgets/fullscreen_image_viewer.dart';
import 'edit_show_screen.dart';
import 'genre_shows_screen.dart';
import 'person_detail_screen.dart';

class ShowDetailScreen extends ConsumerWidget {
  final int showId;
  const ShowDetailScreen({super.key, required this.showId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showsAsync = ref.watch(showsStreamProvider);

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

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                actions: [
                  Builder(
                    builder: (context) {
                      final scanState = ref.watch(scanControllerProvider);
                      final refreshing =
                          scanState.status == ScanStatus.matching &&
                              scanState.currentItem == show.title;
                      return IconButton(
                        icon: refreshing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
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
                                      content: Text(
                                        ok
                                            ? 'Updated'
                                            : 'No match found',
                                      ),
                                    ),
                                  );
                                }
                              },
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditShowScreen(showId: show.id),
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
                flexibleSpace: FlexibleSpaceBar(
                  background: GestureDetector(
                    onTap: () => FullscreenImageViewer.show(
                      context,
                      show.backdropPath ?? show.posterPath,
                    ),
                    child: show.backdropPath != null
                        ? CachedNetworkImage(
                            imageUrl: show.backdropPath!,
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
                        onTap: () => FullscreenImageViewer.show(
                          context,
                          show.posterPath,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 110,
                            height: 165,
                            child: show.posterPath != null
                                ? CachedNetworkImage(
                                    imageUrl: show.posterPath!,
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
                              show.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (show.contentRating != null ||
                                show.status != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  [
                                    if (show.contentRating != null &&
                                        show.contentRating!.isNotEmpty)
                                      show.contentRating!,
                                    if (show.status != null &&
                                        show.status!.isNotEmpty)
                                      show.status!,
                                  ].join(' • '),
                                  style:
                                      const TextStyle(color: Colors.white54),
                                ),
                              ),
                            if (show.rating != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star,
                                        size: 16, color: Colors.amber),
                                    const SizedBox(width: 4),
                                    Text(show.rating!.toStringAsFixed(1)),
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
              if (show.genres != null && show.genres!.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => GenreShowsScreen(genre: g),
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
                    child: Text(show.overview!),
                  ),
                ),
              if (showCredits.isNotEmpty)
                SliverToBoxAdapter(
                  child: _CreditsSection(
                    credits: showCredits,
                    peopleById: peopleById,
                  ),
                ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    'Episodes',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              if (seasons.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'No episodes found.',
                      style: TextStyle(color: Colors.white54),
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
                        subtitle: Text('${seasonEpisodes.length} episodes'),
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
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _CreditsSection extends StatelessWidget {
  final List<ShowCredit> credits;
  final Map<int, Person> peopleById;
  const _CreditsSection({required this.credits, required this.peopleById});

  Widget _roleSection(BuildContext context, String title, String role) {
    final entries = credits.where((c) => c.role == role).toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.white38),
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
                  backgroundImage: person?.photoPath != null
                      ? CachedNetworkImageProvider(person!.photoPath!)
                      : null,
                  child: person?.photoPath == null
                      ? const Icon(Icons.person, size: 14)
                      : null,
                ),
                label: Text(
                  c.character != null && c.character!.isNotEmpty
                      ? '$label (${c.character})'
                      : label,
                ),
                onPressed: person == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                PersonDetailScreen(personId: person.id),
                          ),
                        ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _roleSection(context, 'CREATOR', 'creator'),
        _roleSection(context, 'CAST', 'actor'),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _EpisodeTile extends ConsumerWidget {
  final Episode episode;
  const _EpisodeTile({required this.episode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    errorWidget: (c, u, e) =>
                        Container(color: Colors.white10),
                  )
                : Container(
                    color: Colors.white10,
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
      subtitle: episode.airDate != null && episode.airDate!.isNotEmpty
          ? Text(episode.airDate!)
          : null,
      trailing: IconButton(
        icon: Icon(
          episode.watched ? Icons.check_circle : Icons.check_circle_outline,
          color: episode.watched ? Colors.greenAccent.shade400 : null,
        ),
        onPressed: () => ref
            .read(databaseProvider)
            .setEpisodeWatched(episode.id, !episode.watched),
      ),
      onTap: () {
        if (episode.overview == null || episode.overview!.isEmpty) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'S${episode.seasonNumber}E${episode.episodeNumber}'
              '${episode.title != null ? ' – ${episode.title}' : ''}',
            ),
            content: Text(episode.overview!),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }
}
