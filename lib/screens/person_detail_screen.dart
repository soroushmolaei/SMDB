import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../providers/providers.dart';
import '../services/tmdb_service.dart';
import '../widgets/fullscreen_image_viewer.dart';
import 'movie_detail_screen.dart';
import 'show_detail_screen.dart';

class PersonDetailScreen extends ConsumerStatefulWidget {
  final int personId;
  const PersonDetailScreen({super.key, required this.personId});

  @override
  ConsumerState<PersonDetailScreen> createState() =>
      _PersonDetailScreenState();
}

class _PersonDetailScreenState extends ConsumerState<PersonDetailScreen> {
  bool _fetchTriggered = false;
  bool _fetching = false;

  Future<void> _maybeFetchBio(Person person) async {
    if (_fetchTriggered || person.biography != null) return;
    final tmdb = ref.read(tmdbServiceProvider);
    if (tmdb == null) return;
    _fetchTriggered = true;
    if (mounted) setState(() => _fetching = true);

    try {
      final results = await tmdb.searchPerson(person.name);
      if (results.isNotEmpty) {
        final tmdbPersonId = results.first['id'] as int?;
        if (tmdbPersonId != null) {
          final details = await tmdb.getPersonDetails(tmdbPersonId);
          final bio = details['biography'] as String?;
          await ref.read(databaseProvider).updatePersonBio(
                person.id,
                tmdbPersonId: tmdbPersonId,
                photoPath: person.photoPath ??
                    TmdbService.imageUrl(
                      details['profile_path'] as String?,
                      size: 'w300',
                    ),
                biography:
                    (bio != null && bio.trim().isNotEmpty) ? bio : null,
                birthday: details['birthday'] as String?,
                placeOfBirth: details['place_of_birth'] as String?,
              );
        }
      }
    } catch (_) {
      // Biography is a nice-to-have; fail silently.
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final peopleAsync = ref.watch(peopleStreamProvider);
    final movieCreditsAsync = ref.watch(allCreditsStreamProvider);
    final showCreditsAsync = ref.watch(allShowCreditsStreamProvider);
    final episodeCreditsAsync = ref.watch(allEpisodeCreditsStreamProvider);
    final moviesAsync = ref.watch(moviesStreamProvider);
    final showsAsync = ref.watch(showsStreamProvider);
    final episodesAsync = ref.watch(allEpisodesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Person')),
      body: peopleAsync.when(
        data: (people) {
          final personMatches =
              people.where((p) => p.id == widget.personId);
          if (personMatches.isEmpty) {
            return const Center(child: Text('Person not found'));
          }
          final person = personMatches.first;
          _maybeFetchBio(person);

          return movieCreditsAsync.when(
            data: (allMovieCredits) => showCreditsAsync.when(
              data: (allShowCredits) => episodeCreditsAsync.when(
                data: (allEpisodeCredits) => moviesAsync.when(
                  data: (movies) => showsAsync.when(
                    data: (shows) => episodesAsync.when(
                      data: (episodes) {
                        final movieById = {
                          for (final m in movies) m.id: m,
                        };
                        final showById = {for (final s in shows) s.id: s};
                        final episodeById = {
                          for (final e in episodes) e.id: e,
                        };

                        // Only keep credits whose movie/show/episode still
                        // exists — otherwise a deleted title leaves a stale
                        // credit row that would inflate the count below.
                        final myMovieCredits = allMovieCredits
                            .where((c) =>
                                c.personId == widget.personId &&
                                movieById.containsKey(c.movieId))
                            .toList();
                        final myShowCredits = allShowCredits
                            .where((c) =>
                                c.personId == widget.personId &&
                                showById.containsKey(c.showId))
                            .toList();
                        final myEpisodeCredits = allEpisodeCredits
                            .where((c) =>
                                c.personId == widget.personId &&
                                episodeById.containsKey(c.episodeId) &&
                                showById.containsKey(
                                    episodeById[c.episodeId]!.showId))
                            .toList();
                        final directingCredits = myMovieCredits
                            .where((c) => c.role == 'director')
                            .toList();
                        final writingCredits = myMovieCredits
                            .where((c) => c.role == 'writer')
                            .toList();
                        final creatingCredits = myShowCredits
                            .where((c) => c.role == 'creator')
                            .toList();
                        final actingMovieCredits = myMovieCredits
                            .where((c) => c.role == 'actor')
                            .toList();
                        final actingShowCredits = myShowCredits
                            .where((c) => c.role == 'actor')
                            .toList();

                        // Group guest-star episode credits by show, so a
                        // person who guest-starred in 3 episodes of the
                        // same show shows up as ONE show entry (expandable
                        // to reveal which episodes), not 3 separate rows.
                        final episodesByShow = <int, List<EpisodeCredit>>{};
                        for (final c in myEpisodeCredits) {
                          final showId = episodeById[c.episodeId]!.showId;
                          episodesByShow
                              .putIfAbsent(showId, () => [])
                              .add(c);
                        }

                        final totalCredits = directingCredits.length +
                            writingCredits.length +
                            creatingCredits.length +
                            actingMovieCredits.length +
                            actingShowCredits.length +
                            episodesByShow.length;

                        Widget sectionHeader(String title) => Padding(
                              padding: const EdgeInsets.only(
                                  top: 20, bottom: 8),
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.white54,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            );

                        Widget posterThumb(String? posterPath,
                                IconData fallbackIcon) =>
                            SizedBox(
                              width: 40,
                              height: 56,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: posterPath != null
                                    ? CachedNetworkImage(
                                        imageUrl: posterPath,
                                        fit: BoxFit.cover,
                                        errorWidget: (c, u, e) => Container(
                                            color: Colors.white10),
                                      )
                                    : Container(
                                        color: Colors.white10,
                                        child: Icon(
                                          fallbackIcon,
                                          color: Colors.white24,
                                          size: 18,
                                        ),
                                      ),
                              ),
                            );

                        Widget movieRow(MovieCredit credit) {
                          final movie = movieById[credit.movieId]!;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: posterThumb(
                                movie.posterPath, Icons.movie_outlined),
                            title: Text(movie.title),
                            subtitle: credit.character != null &&
                                    credit.character!.isNotEmpty
                                ? Text('as ${credit.character}')
                                : null,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    MovieDetailScreen(movieId: movie.id),
                              ),
                            ),
                          );
                        }

                        Widget showRow(ShowCredit credit) {
                          final show = showById[credit.showId]!;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: posterThumb(
                                show.posterPath, Icons.tv_outlined),
                            title: Text(show.title),
                            subtitle: credit.character != null &&
                                    credit.character!.isNotEmpty
                                ? Text('as ${credit.character}')
                                : null,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ShowDetailScreen(showId: show.id),
                              ),
                            ),
                          );
                        }

                        Widget guestStarGroup(
                          int showId,
                          List<EpisodeCredit> credits,
                        ) {
                          final show = showById[showId]!;
                          final sorted = [...credits]..sort((a, b) {
                              final ea = episodeById[a.episodeId]!;
                              final eb = episodeById[b.episodeId]!;
                              if (ea.seasonNumber != eb.seasonNumber) {
                                return ea.seasonNumber
                                    .compareTo(eb.seasonNumber);
                              }
                              return ea.episodeNumber
                                  .compareTo(eb.episodeNumber);
                            });
                          return ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: EdgeInsets.zero,
                            leading: posterThumb(
                                show.posterPath, Icons.tv_outlined),
                            title: Text(show.title),
                            subtitle: Text(
                              '${sorted.length} episode'
                              '${sorted.length > 1 ? 's' : ''}',
                            ),
                            children: sorted.map((c) {
                              final ep = episodeById[c.episodeId]!;
                              return ListTile(
                                dense: true,
                                contentPadding:
                                    const EdgeInsets.only(left: 52),
                                title: Text(
                                  'S${ep.seasonNumber}E${ep.episodeNumber}'
                                  '${ep.title != null && ep.title!.isNotEmpty ? ' – ${ep.title}' : ''}',
                                ),
                                subtitle: c.character != null &&
                                        c.character!.isNotEmpty
                                    ? Text('as ${c.character}')
                                    : null,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ShowDetailScreen(showId: show.id),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        }

                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: person.photoPath == null
                                      ? null
                                      : () => FullscreenImageViewer.show(
                                            context,
                                            person.photoPath,
                                          ),
                                  child: CircleAvatar(
                                    radius: 40,
                                    backgroundColor: Colors.white10,
                                    backgroundImage: person.photoPath != null
                                        ? CachedNetworkImageProvider(
                                            person.photoPath!)
                                        : null,
                                    child: person.photoPath == null
                                        ? const Icon(Icons.person,
                                            size: 40, color: Colors.white38)
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        person.name,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (person.birthday != null ||
                                          person.placeOfBirth != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                            [
                                              if (person.birthday != null)
                                                'Born ${person.birthday}',
                                              if (person.placeOfBirth != null)
                                                person.placeOfBirth!,
                                            ].join(' • '),
                                            style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 13),
                                          ),
                                        ),
                                      if (_fetching)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 6),
                                          child: SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (person.biography != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                person.biography!,
                                style: const TextStyle(height: 1.4),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Text(
                              'Filmography ($totalCredits)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (totalCredits == 0)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'No linked movies or shows.',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ),
                            if (directingCredits.isNotEmpty) ...[
                              sectionHeader('DIRECTING'),
                              ...directingCredits.map(movieRow),
                            ],
                            if (writingCredits.isNotEmpty) ...[
                              sectionHeader('WRITING'),
                              ...writingCredits.map(movieRow),
                            ],
                            if (creatingCredits.isNotEmpty) ...[
                              sectionHeader('CREATING'),
                              ...creatingCredits.map(showRow),
                            ],
                            if (actingMovieCredits.isNotEmpty ||
                                actingShowCredits.isNotEmpty) ...[
                              sectionHeader('ACTING'),
                              ...actingMovieCredits.map(movieRow),
                              ...actingShowCredits.map(showRow),
                            ],
                            if (episodesByShow.isNotEmpty) ...[
                              sectionHeader('GUEST STARRING'),
                              ...episodesByShow.entries
                                  .map((e) => guestStarGroup(e.key, e.value)),
                            ],
                          ],
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, st) => Center(child: Text('Error: $e')),
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, st) => Center(child: Text('Error: $e')),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('Error: $e')),
                ),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error: $e')),
              ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
