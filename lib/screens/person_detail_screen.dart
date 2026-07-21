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

  String _roleLabel(String role, String? character) {
    if (role == 'actor' && character != null && character.isNotEmpty) {
      return 'as $character';
    }
    if (role.isEmpty) return '';
    return role[0].toUpperCase() + role.substring(1);
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
                        final totalCredits = myMovieCredits.length +
                            myShowCredits.length +
                            myEpisodeCredits.length;

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
                            const SizedBox(height: 24),
                            Text(
                              'Filmography ($totalCredits)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (totalCredits == 0)
                              const Text(
                                'No linked movies or shows.',
                                style: TextStyle(color: Colors.white54),
                              ),
                            ...myMovieCredits.map((credit) {
                              final movie = movieById[credit.movieId]!;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: SizedBox(
                                  width: 40,
                                  height: 56,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: movie.posterPath != null
                                        ? CachedNetworkImage(
                                            imageUrl: movie.posterPath!,
                                            fit: BoxFit.cover,
                                            errorWidget: (c, u, e) =>
                                                Container(
                                                    color: Colors.white10),
                                          )
                                        : Container(
                                            color: Colors.white10,
                                            child: const Icon(
                                              Icons.movie_outlined,
                                              color: Colors.white24,
                                              size: 18,
                                            ),
                                          ),
                                  ),
                                ),
                                title: Text(movie.title),
                                subtitle: Text(
                                    _roleLabel(credit.role, credit.character)),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        MovieDetailScreen(movieId: movie.id),
                                  ),
                                ),
                              );
                            }),
                            ...myShowCredits.map((credit) {
                              final show = showById[credit.showId]!;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: SizedBox(
                                  width: 40,
                                  height: 56,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: show.posterPath != null
                                        ? CachedNetworkImage(
                                            imageUrl: show.posterPath!,
                                            fit: BoxFit.cover,
                                            errorWidget: (c, u, e) =>
                                                Container(
                                                    color: Colors.white10),
                                          )
                                        : Container(
                                            color: Colors.white10,
                                            child: const Icon(
                                              Icons.tv_outlined,
                                              color: Colors.white24,
                                              size: 18,
                                            ),
                                          ),
                                  ),
                                ),
                                title: Text(show.title),
                                subtitle: Text(
                                    _roleLabel(credit.role, credit.character)),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ShowDetailScreen(showId: show.id),
                                  ),
                                ),
                              );
                            }),
                            ...myEpisodeCredits.map((credit) {
                              final episode = episodeById[credit.episodeId]!;
                              final show = showById[episode.showId]!;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: SizedBox(
                                  width: 40,
                                  height: 56,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: show.posterPath != null
                                        ? CachedNetworkImage(
                                            imageUrl: show.posterPath!,
                                            fit: BoxFit.cover,
                                            errorWidget: (c, u, e) =>
                                                Container(
                                                    color: Colors.white10),
                                          )
                                        : Container(
                                            color: Colors.white10,
                                            child: const Icon(
                                              Icons.tv_outlined,
                                              color: Colors.white24,
                                              size: 18,
                                            ),
                                          ),
                                  ),
                                ),
                                title: Text(
                                  '${show.title} · S${episode.seasonNumber}'
                                  'E${episode.episodeNumber}',
                                ),
                                subtitle: Text(
                                  _roleLabel('actor', credit.character),
                                ),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ShowDetailScreen(showId: show.id),
                                  ),
                                ),
                              );
                            }),
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
