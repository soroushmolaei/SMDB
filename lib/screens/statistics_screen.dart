import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../providers/providers.dart';

/// Library-wide statistics: counts, total watch time, watched progress,
/// ratings, and breakdowns by language/genre/content rating/decade.
///
/// Duration and language depend on `Movies.runtimeMinutes`,
/// `Episodes.runtimeMinutes` and `*.originalLanguage` -- fields that are
/// only populated going forward or when an item is re-matched. Titles
/// added before this existed will read as "Unknown"/excluded from
/// duration totals until their "Update" button is used, so the relevant
/// sections note the coverage rather than presenting an undercount as
/// complete.
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moviesAsync = ref.watch(moviesStreamProvider);
    final shows = ref.watch(showsStreamProvider).value ?? [];
    final episodes = ref.watch(allEpisodesStreamProvider).value ?? [];
    final people = ref.watch(peopleStreamProvider).value ?? [];

    return moviesAsync.when(
      data: (movies) {
        if (movies.isEmpty && shows.isEmpty) {
          return const Center(
            child: Text(
              'No stats yet — scan a movie or show folder first.',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }
        return _StatisticsBody(
          movies: movies,
          shows: shows,
          episodes: episodes,
          peopleCount: people.length,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

class _StatisticsBody extends StatelessWidget {
  final List<Movie> movies;
  final List<Show> shows;
  final List<Episode> episodes;
  final int peopleCount;

  const _StatisticsBody({
    required this.movies,
    required this.shows,
    required this.episodes,
    required this.peopleCount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final watchedMovies = movies.where((m) => m.watched).length;
    final watchedEpisodes = episodes.where((e) => e.watched).length;
    final favoriteCount =
        movies.where((m) => m.isFavorite).length + shows.where((s) => s.isFavorite).length;

    final movieRuntimes =
        movies.map((m) => m.runtimeMinutes).whereType<int>().toList();
    final totalMovieMinutes = movieRuntimes.fold<int>(0, (a, b) => a + b);
    final episodeRuntimes =
        episodes.map((e) => e.runtimeMinutes).whereType<int>().toList();
    final totalEpisodeMinutes = episodeRuntimes.fold<int>(0, (a, b) => a + b);
    final combinedMinutes = totalMovieMinutes + totalEpisodeMinutes;

    final movieRatings = movies.map((m) => m.rating).whereType<double>().toList();
    final avgMovieRating = movieRatings.isEmpty
        ? null
        : movieRatings.reduce((a, b) => a + b) / movieRatings.length;
    final showRatings = shows.map((s) => s.rating).whereType<double>().toList();
    final avgShowRating = showRatings.isEmpty
        ? null
        : showRatings.reduce((a, b) => a + b) / showRatings.length;
    final personalRatings = [
      ...movies.map((m) => m.personalRating).whereType<double>(),
      ...shows.map((s) => s.personalRating).whereType<double>(),
    ];
    final avgPersonalRating = personalRatings.isEmpty
        ? null
        : personalRatings.reduce((a, b) => a + b) / personalRatings.length;

    // --- Breakdowns ----------------------------------------------------

    final languageCounts = <String, int>{};
    var unknownLanguageCount = 0;
    void addLanguage(String? raw) {
      if (raw == null || raw.isEmpty) {
        unknownLanguageCount++;
        return;
      }
      languageCounts[raw] = (languageCounts[raw] ?? 0) + 1;
    }

    for (final m in movies) {
      addLanguage(m.originalLanguage);
    }
    for (final s in shows) {
      addLanguage(s.originalLanguage);
    }

    final genreCounts = <String, int>{};
    void addGenres(String? raw) {
      if (raw == null) return;
      for (final g in raw.split(',')) {
        final trimmed = g.trim();
        if (trimmed.isEmpty) continue;
        genreCounts[trimmed] = (genreCounts[trimmed] ?? 0) + 1;
      }
    }

    for (final m in movies) {
      addGenres(m.genres);
    }
    for (final s in shows) {
      addGenres(s.genres);
    }

    final contentRatingCounts = <String, int>{};
    void addContentRating(String? raw) {
      if (raw == null || raw.isEmpty) return;
      contentRatingCounts[raw] = (contentRatingCounts[raw] ?? 0) + 1;
    }

    for (final m in movies) {
      addContentRating(m.contentRating);
    }
    for (final s in shows) {
      addContentRating(s.contentRating);
    }

    // Shows have no release-year field of their own, so the decade
    // breakdown only covers movies.
    final decadeCounts = <String, int>{};
    for (final m in movies) {
      final year = m.year;
      if (year == null) continue;
      final decade = '${(year ~/ 10) * 10}s';
      decadeCounts[decade] = (decadeCounts[decade] ?? 0) + 1;
    }

    // --- Fun facts -------------------------------------------------------

    Movie? longestMovie;
    Movie? shortestMovie;
    for (final m in movies) {
      final runtime = m.runtimeMinutes;
      if (runtime == null) continue;
      if (longestMovie == null || runtime > longestMovie.runtimeMinutes!) {
        longestMovie = m;
      }
      if (shortestMovie == null || runtime < shortestMovie.runtimeMinutes!) {
        shortestMovie = m;
      }
    }

    final episodeCountByShow = <int, int>{};
    for (final e in episodes) {
      episodeCountByShow[e.showId] = (episodeCountByShow[e.showId] ?? 0) + 1;
    }
    Show? mostEpisodesShow;
    var mostEpisodesCount = 0;
    for (final s in shows) {
      final count = episodeCountByShow[s.id] ?? 0;
      if (count > mostEpisodesCount) {
        mostEpisodesCount = count;
        mostEpisodesShow = s;
      }
    }

    final topGenre = _topEntries(genreCounts, 1);
    final topLanguage = _topEntries(languageCounts, 1);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader('OVERVIEW'),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatCard(
                icon: Icons.movie_outlined,
                value: '${movies.length}',
                label: 'Movies',
                color: colorScheme.primary,
              ),
              _StatCard(
                icon: Icons.tv_outlined,
                value: '${shows.length}',
                label: 'Shows',
                color: colorScheme.primary,
              ),
              _StatCard(
                icon: Icons.video_library_outlined,
                value: '${episodes.length}',
                label: 'Episodes',
                color: colorScheme.primary,
              ),
              _StatCard(
                icon: Icons.people_outline,
                value: '$peopleCount',
                label: 'People',
                color: colorScheme.primary,
              ),
              _StatCard(
                icon: Icons.star_outline,
                value: '$favoriteCount',
                label: 'Favorites',
                color: colorScheme.primary,
              ),
              _StatCard(
                icon: Icons.schedule_outlined,
                value: _formatDuration(combinedMinutes),
                label: 'Total watch time',
                color: colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionHeader('DURATION'),
          _SectionCard(
            title: 'Movies',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatLine(
                  label: 'Total duration',
                  value: _formatDuration(totalMovieMinutes),
                ),
                _StatLine(
                  label: 'Average length',
                  value: movieRuntimes.isEmpty
                      ? '—'
                      : _formatDuration(totalMovieMinutes ~/ movieRuntimes.length),
                ),
                if (movieRuntimes.length < movies.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${movieRuntimes.length} of ${movies.length} movies have a '
                      'known duration — tap Update on the rest to fill this in.',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Shows (episodes)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatLine(
                  label: 'Total duration',
                  value: _formatDuration(totalEpisodeMinutes),
                ),
                _StatLine(
                  label: 'Average episode length',
                  value: episodeRuntimes.isEmpty
                      ? '—'
                      : _formatDuration(
                          totalEpisodeMinutes ~/ episodeRuntimes.length),
                ),
                if (episodeRuntimes.length < episodes.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${episodeRuntimes.length} of ${episodes.length} episodes have a '
                      'known duration — tap Update on the show to fill this in.',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionHeader('WATCHED'),
          _SectionCard(
            title: 'Progress',
            child: Column(
              children: [
                _ProgressStat(
                  label: 'Movies watched',
                  watched: watchedMovies,
                  total: movies.length,
                  color: colorScheme.primary,
                ),
                _ProgressStat(
                  label: 'Episodes watched',
                  watched: watchedEpisodes,
                  total: episodes.length,
                  color: colorScheme.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionHeader('RATINGS'),
          _SectionCard(
            title: 'Averages',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatLine(
                  label: 'Average movie score (TMDB/IMDb)',
                  value: avgMovieRating == null
                      ? '—'
                      : '${avgMovieRating.toStringAsFixed(1)} / 10',
                ),
                _StatLine(
                  label: 'Average show score (TMDB/IMDb)',
                  value: avgShowRating == null
                      ? '—'
                      : '${avgShowRating.toStringAsFixed(1)} / 10',
                ),
                _StatLine(
                  label: 'Average personal rating',
                  value: avgPersonalRating == null
                      ? '—'
                      : '${avgPersonalRating.toStringAsFixed(1)} / 10',
                ),
                _StatLine(
                  label: 'Titles you\'ve personally rated',
                  value: '${personalRatings.length}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionHeader('LANGUAGE'),
          _SectionCard(
            title: 'By original language',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BarList(
                  entries: _topEntries(languageCounts, 8),
                  color: colorScheme.primary,
                ),
                if (unknownLanguageCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '$unknownLanguageCount title${unknownLanguageCount == 1 ? '' : 's'} '
                      'with no language on file yet — tap Update to fill it in.',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionHeader('GENRES'),
          _SectionCard(
            title: 'Top genres',
            child: _BarList(
              entries: _topEntries(genreCounts, 8),
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          const _SectionHeader('CONTENT RATINGS'),
          _SectionCard(
            title: 'By content rating',
            child: _BarList(
              entries: _topEntries(contentRatingCounts, 8),
              color: colorScheme.primary,
            ),
          ),
          if (decadeCounts.isNotEmpty) ...[
            const SizedBox(height: 24),
            const _SectionHeader('MOVIES BY DECADE'),
            _SectionCard(
              title: 'Release decade',
              child: _BarList(
                entries: _sortedByKey(decadeCounts),
                color: colorScheme.primary,
              ),
            ),
          ],
          const SizedBox(height: 24),
          const _SectionHeader('FUN FACTS'),
          _SectionCard(
            title: 'Highlights',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (longestMovie != null)
                  _FactRow(
                    icon: Icons.timelapse,
                    text: 'Longest movie: ${longestMovie.title} '
                        '(${_formatDuration(longestMovie.runtimeMinutes!)})',
                  ),
                if (shortestMovie != null)
                  _FactRow(
                    icon: Icons.timer_outlined,
                    text: 'Shortest movie: ${shortestMovie.title} '
                        '(${_formatDuration(shortestMovie.runtimeMinutes!)})',
                  ),
                if (mostEpisodesShow != null)
                  _FactRow(
                    icon: Icons.playlist_play,
                    text: 'Most episodes: ${mostEpisodesShow.title} '
                        '($mostEpisodesCount episodes)',
                  ),
                if (topGenre.isNotEmpty)
                  _FactRow(
                    icon: Icons.local_offer_outlined,
                    text: 'Favorite genre: ${topGenre.first.key} '
                        '(${topGenre.first.value} titles)',
                  ),
                if (topLanguage.isNotEmpty)
                  _FactRow(
                    icon: Icons.language,
                    text: 'Most common language: ${topLanguage.first.key} '
                        '(${topLanguage.first.value} titles)',
                  ),
                if (longestMovie == null &&
                    shortestMovie == null &&
                    mostEpisodesShow == null &&
                    topGenre.isEmpty &&
                    topLanguage.isEmpty)
                  const Text(
                    'Not enough data yet.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sorts a counts map by value descending and keeps the top [n] entries.
List<MapEntry<String, int>> _topEntries(Map<String, int> counts, int n) {
  final entries = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries.take(n).toList();
}

/// Sorts a counts map by key ascending (used for the decade breakdown, so
/// it reads chronologically rather than by count).
List<MapEntry<String, int>> _sortedByKey(Map<String, int> counts) {
  final entries = counts.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return entries;
}

/// Formats a minute count as e.g. "3d 4h 12m", "6h 5m", or "42m".
String _formatDuration(int totalMinutes) {
  if (totalMinutes <= 0) return '0m';
  final days = totalMinutes ~/ (60 * 24);
  final hours = (totalMinutes % (60 * 24)) ~/ 60;
  final minutes = totalMinutes % 60;
  final parts = <String>[];
  if (days > 0) parts.add('${days}d');
  if (hours > 0 || days > 0) parts.add('${hours}h');
  parts.add('${minutes}m');
  return parts.join(' ');
}

// ---------------------------------------------------------------------------
// Small display widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white54,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  final String label;
  final String value;
  const _StatLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ProgressStat extends StatelessWidget {
  final String label;
  final int watched;
  final int total;
  final Color color;

  const _ProgressStat({
    required this.label,
    required this.watched,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : watched / total;
    final percent = (fraction * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 13)),
              Text(
                '$watched / $total ($percent%)',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarList extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  final Color color;

  const _BarList({required this.entries, required this.color});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Text(
        'Not enough data yet.',
        style: TextStyle(color: Colors.white38, fontSize: 12),
      );
    }
    final maxValue = entries
        .map((e) => e.value)
        .fold<int>(0, (a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final e in entries)
          _BarRow(
            label: e.key,
            count: e.value,
            fraction: maxValue == 0 ? 0 : e.value / maxValue,
            color: color,
          ),
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final int count;
  final double fraction;
  final Color color;

  const _BarRow({
    required this.label,
    required this.count,
    required this.fraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 12,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 34,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FactRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF9C91F5)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
