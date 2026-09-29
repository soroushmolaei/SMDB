import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../providers/providers.dart';
import '../widgets/media_grid.dart';
import '../widgets/media_item.dart';
import '../widgets/multi_select_filter.dart';
import 'movie_detail_screen.dart';
import 'show_detail_screen.dart';

/// MY COLLECTION > Advanced: every filter (Type, Genre, Year, Language,
/// Content rating, Rating, People) available at once on one page, rather
/// than having to enter a single category (a specific genre, a specific
/// language, ...) first. Every filter is multi-select. Within a filter:
/// Genre and People require ALL ticked values (like Combine genres and
/// Shared Filmography); the others match ANY ticked value.
/// Everything else -- sort, multi-select, bulk Refresh Metadata -- matches
/// the other MY COLLECTION drill-downs.
class AdvancedFilterScreen extends ConsumerStatefulWidget {
  const AdvancedFilterScreen({super.key});

  @override
  ConsumerState<AdvancedFilterScreen> createState() =>
      _AdvancedFilterScreenState();
}

class _AdvancedFilterScreenState extends ConsumerState<AdvancedFilterScreen>
    with MediaSelectionMixin<AdvancedFilterScreen> {
  SortOption _sort = SortOption.titleAsc;
  Set<String> _kinds = {};
  Set<String> _genres = {};
  Set<int> _years = {};
  Set<String> _languages = {};
  Set<String> _contentRatings = {};
  Set<String> _ratingBuckets = {};
  Set<int> _people = {};

  static const _ratingBucketOptions = [
    '9–10',
    '8–9',
    '7–8',
    '6–7',
    '5–6',
    'Below 5',
    'Unrated',
  ];

  static String _ratingBucket(double? r) {
    if (r == null) return 'Unrated';
    if (r >= 9) return '9–10';
    if (r >= 8) return '8–9';
    if (r >= 7) return '7–8';
    if (r >= 6) return '6–7';
    if (r >= 5) return '5–6';
    return 'Below 5';
  }

  bool get _hasActiveFilters =>
      _kinds.isNotEmpty ||
      _genres.isNotEmpty ||
      _years.isNotEmpty ||
      _languages.isNotEmpty ||
      _contentRatings.isNotEmpty ||
      _ratingBuckets.isNotEmpty ||
      _people.isNotEmpty;

  void _clearFilters() {
    setState(() {
      _kinds = {};
      _genres = {};
      _years = {};
      _languages = {};
      _contentRatings = {};
      _ratingBuckets = {};
      _people = {};
    });
  }

  @override
  Widget build(BuildContext context) {
    final moviesAsync = ref.watch(moviesStreamProvider);
    final shows = ref.watch(showsStreamProvider).value ?? [];
    final people = ref.watch(peopleStreamProvider).value ?? [];
    final movieCredits = ref.watch(allCreditsStreamProvider).value ?? [];
    final showCredits = ref.watch(allShowCreditsStreamProvider).value ?? [];
    final episodeCredits =
        ref.watch(allEpisodeCreditsStreamProvider).value ?? [];
    final episodes = ref.watch(allEpisodesStreamProvider).value ?? [];
    final busy =
        ref.watch(scanControllerProvider).status == ScanStatus.matching;
    final exclusionWords = ref.watch(sortExclusionWordsProvider);

    return moviesAsync.when(
      data: (movies) {
        MediaItem toMovieItem(Movie m) => MediaItem(
              kind: 'movie',
              id: m.id,
              title: m.title,
              year: m.year,
              posterPath: m.posterPath,
              posterThumbnail: m.posterThumbnail,
              rating: m.rating,
              genres: m.genres,
              watched: m.watched,
              isFavorite: m.isFavorite,
              dateAdded: m.dateAdded,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MovieDetailScreen(movieId: m.id),
                ),
              ),
            );
        MediaItem toShowItem(Show s) => MediaItem(
              kind: 'show',
              id: s.id,
              title: s.title,
              year: s.year,
              posterPath: s.posterPath,
              posterThumbnail: s.posterThumbnail,
              rating: s.rating,
              genres: s.genres,
              watched: false,
              isFavorite: s.isFavorite,
              dateAdded: s.dateAdded,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ShowDetailScreen(showId: s.id),
                ),
              ),
            );

        // originalLanguage isn't one of MediaItem's own fields, so keep
        // a lookup keyed by the same selectionKey to filter by language
        // without a second pass over Movie/Show.
        final movieItems = movies.map(toMovieItem).toList();
        final showItems = shows.map(toShowItem).toList();
        final languageByKey = <String, String?>{
          for (final m in movies) 'movie:${m.id}': m.originalLanguage,
          for (final s in shows) 'show:${s.id}': s.originalLanguage,
        };

        final contentRatingByKey = <String, String?>{
          for (final m in movies) 'movie:${m.id}': m.contentRating,
          for (final s in shows) 'show:${s.id}': s.contentRating,
        };

        // Who appears in which title (cast, directors, writers, creators,
        // plus guest stars via their episode's show), keyed like
        // MediaItem.selectionKey.
        final peopleByKey = <String, Set<int>>{};
        for (final c in movieCredits) {
          peopleByKey
              .putIfAbsent('movie:${c.movieId}', () => <int>{})
              .add(c.personId);
        }
        for (final c in showCredits) {
          peopleByKey
              .putIfAbsent('show:${c.showId}', () => <int>{})
              .add(c.personId);
        }
        final episodeShowId = {for (final e in episodes) e.id: e.showId};
        for (final c in episodeCredits) {
          final showId = episodeShowId[c.episodeId];
          if (showId == null) continue;
          peopleByKey
              .putIfAbsent('show:$showId', () => <int>{})
              .add(c.personId);
        }

        final allItems = <MediaItem>[...movieItems, ...showItems];

        final genreSet = <String>{};
        final yearSet = <int>{};
        final languageSet = <String>{};
        final contentRatingSet = <String>{};
        final personIdSet = <int>{};
        for (final item in allItems) {
          if (item.genres != null) {
            for (final g in item.genres!.split(',')) {
              final t = g.trim();
              if (t.isNotEmpty) genreSet.add(t);
            }
          }
          if (item.year != null) yearSet.add(item.year!);
          final lang = languageByKey[item.selectionKey];
          if (lang != null && lang.isNotEmpty) languageSet.add(lang);
          final cr = contentRatingByKey[item.selectionKey];
          if (cr != null && cr.isNotEmpty) contentRatingSet.add(cr);
          personIdSet.addAll(peopleByKey[item.selectionKey] ?? const <int>{});
        }
        final genreList = genreSet.toList()..sort();
        final yearList = yearSet.toList()..sort((a, b) => b.compareTo(a));
        final languageList = languageSet.toList()..sort();
        final contentRatingList = contentRatingSet.toList()..sort();
        final nameById = {for (final p in people) p.id: p.name};
        final personList = personIdSet
            .where(nameById.containsKey)
            .toList()
          ..sort((a, b) => nameById[a]!.compareTo(nameById[b]!));

        final filtered = allItems.where((item) {
          final key = item.selectionKey;
          if (_kinds.isNotEmpty && !_kinds.contains(item.kind)) return false;
          if (_genres.isNotEmpty) {
            final itemGenres =
                (item.genres ?? '').split(',').map((g) => g.trim()).toSet();
            if (!_genres.every(itemGenres.contains)) return false;
          }
          if (_years.isNotEmpty &&
              (item.year == null || !_years.contains(item.year))) {
            return false;
          }
          if (_languages.isNotEmpty &&
              !_languages.contains(languageByKey[key])) {
            return false;
          }
          if (_contentRatings.isNotEmpty &&
              !_contentRatings.contains(contentRatingByKey[key])) {
            return false;
          }
          if (_ratingBuckets.isNotEmpty &&
              !_ratingBuckets.contains(_ratingBucket(item.rating))) {
            return false;
          }
          if (_people.isNotEmpty) {
            final itemPeople = peopleByKey[key];
            if (itemPeople == null || !_people.every(itemPeople.contains)) {
              return false;
            }
          }
          return true;
        }).toList();
        sortMediaItems(filtered, _sort, exclusionWords: exclusionWords);
        final shown = applyLetterFilter(filtered, exclusionWords);

        return withAlphabetIndex(Column(
          children: [
            if (selecting)
              SelectionActionBar(
                selectedCount: selectedKeys.length,
                totalCount: shown.length,
                busy: busy,
                onSelectAll: () => selectAll(shown),
                onClear: clearSelection,
                onCancel: toggleSelectionMode,
                onRefresh: refreshSelected,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          DropdownButton<SortOption>(
                            value: _sort,
                            underline: const SizedBox.shrink(),
                            icon: const Icon(Icons.sort, size: 16),
                            items: SortOption.values
                                .map((o) => DropdownMenuItem(
                                      value: o,
                                      child: Text(o.label,
                                          style:
                                              const TextStyle(fontSize: 13)),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _sort = v);
                            },
                          ),
                          const SizedBox(width: 12),
                          MultiSelectFilter<String>(
                            label: 'Type',
                            allLabel: 'Movies & Shows',
                            options: const ['movie', 'show'],
                            selected: _kinds,
                            labelOf: (k) => k == 'movie' ? 'Movies' : 'Shows',
                            onChanged: (v) => setState(() => _kinds = v),
                          ),
                          const SizedBox(width: 12),
                          MultiSelectFilter<String>(
                            label: 'Genre',
                            allLabel: 'All genres',
                            options: genreList,
                            selected: _genres,
                            labelOf: (g) => g,
                            onChanged: (v) => setState(() => _genres = v),
                          ),
                          const SizedBox(width: 12),
                          MultiSelectFilter<int>(
                            label: 'Year',
                            allLabel: 'All years',
                            options: yearList,
                            selected: _years,
                            labelOf: (y) => '$y',
                            onChanged: (v) => setState(() => _years = v),
                          ),
                          const SizedBox(width: 12),
                          MultiSelectFilter<String>(
                            label: 'Language',
                            allLabel: 'All languages',
                            options: languageList,
                            selected: _languages,
                            labelOf: (l) => l,
                            onChanged: (v) => setState(() => _languages = v),
                          ),
                          const SizedBox(width: 12),
                          MultiSelectFilter<String>(
                            label: 'Content rating',
                            allLabel: 'All ratings (MPA)',
                            options: contentRatingList,
                            selected: _contentRatings,
                            labelOf: (r) => r,
                            onChanged: (v) =>
                                setState(() => _contentRatings = v),
                          ),
                          const SizedBox(width: 12),
                          MultiSelectFilter<String>(
                            label: 'Rating',
                            allLabel: 'Any rating',
                            options: _ratingBucketOptions,
                            selected: _ratingBuckets,
                            labelOf: (r) => r,
                            onChanged: (v) =>
                                setState(() => _ratingBuckets = v),
                          ),
                          const SizedBox(width: 12),
                          MultiSelectFilter<int>(
                            label: 'People',
                            allLabel: 'All people',
                            options: personList,
                            selected: _people,
                            labelOf: (id) => nameById[id] ?? '',
                            searchable: true,
                            onChanged: (v) => setState(() => _people = v),
                          ),
                          if (_hasActiveFilters) ...[
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: _clearFilters,
                              child: const Text('Clear'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(selecting ? Icons.close : Icons.checklist),
                    tooltip: selecting ? 'Cancel selection' : 'Select multiple',
                    onPressed: shown.isEmpty && !selecting
                        ? null
                        : toggleSelectionMode,
                  ),
                ],
              ),
            ),
            Expanded(
              child: MediaItemView(
                items: shown,
                gridView: true,
                emptyTitle: allItems.isEmpty
                    ? 'Nothing in your library yet'
                    : 'No matches',
                emptySubtitle: allItems.isEmpty
                    ? 'Scan a movie or show folder first.'
                    : 'Try loosening a filter above.',
                selectionMode: selecting,
                selectedKeys: selectedKeys,
                onToggleSelect: toggleItemSelection,
              ),
            ),
          ],
        ));
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}
