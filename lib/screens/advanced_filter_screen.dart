import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../providers/providers.dart';
import '../widgets/media_grid.dart';
import '../widgets/media_item.dart';
import 'movie_detail_screen.dart';
import 'show_detail_screen.dart';

/// MY COLLECTION > Advanced: every filter (Type, Genre, Year, Language,
/// Rating) available at once on one page, rather than having to enter a
/// single category (a specific genre, a specific language, ...) first.
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
  String? _selectedKind;
  String? _selectedGenre;
  int? _selectedYear;
  String? _selectedLanguage;
  double? _minRating;

  @override
  Widget build(BuildContext context) {
    final moviesAsync = ref.watch(moviesStreamProvider);
    final shows = ref.watch(showsStreamProvider).value ?? [];
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

        final allItems = <MediaItem>[...movieItems, ...showItems];

        final genreSet = <String>{};
        final yearSet = <int>{};
        final languageSet = <String>{};
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
        }
        final genreList = genreSet.toList()..sort();
        final yearList = yearSet.toList()..sort((a, b) => b.compareTo(a));
        final languageList = languageSet.toList()..sort();

        final filtered = allItems.where((item) {
          if (_selectedKind != null && item.kind != _selectedKind) {
            return false;
          }
          if (_selectedGenre != null) {
            final genres =
                (item.genres ?? '').split(',').map((g) => g.trim());
            if (!genres.contains(_selectedGenre)) return false;
          }
          if (_selectedYear != null && item.year != _selectedYear) {
            return false;
          }
          if (_selectedLanguage != null &&
              languageByKey[item.selectionKey] != _selectedLanguage) {
            return false;
          }
          if (_minRating != null &&
              (item.rating == null || item.rating! < _minRating!)) {
            return false;
          }
          return true;
        }).toList();
        sortMediaItems(filtered, _sort, exclusionWords: exclusionWords);

        return Column(
          children: [
            if (selecting)
              SelectionActionBar(
                selectedCount: selectedKeys.length,
                totalCount: filtered.length,
                busy: busy,
                onSelectAll: () => selectAll(filtered),
                onClear: clearSelection,
                onCancel: toggleSelectionMode,
                onRefresh: refreshSelected,
              ),
            SortFilterBar(
              sort: _sort,
              onSortChanged: (s) => setState(() => _sort = s),
              selectedGenre: _selectedGenre,
              availableGenres: genreList,
              onGenreChanged: (g) => setState(() => _selectedGenre = g),
              selectedYear: _selectedYear,
              availableYears: yearList,
              onYearChanged: (y) => setState(() => _selectedYear = y),
              minRating: _minRating,
              onMinRatingChanged: (r) => setState(() => _minRating = r),
              selectedKind: _selectedKind,
              onKindChanged: (k) => setState(() => _selectedKind = k),
              selectedLanguage: _selectedLanguage,
              availableLanguages: languageList,
              onLanguageChanged: (l) =>
                  setState(() => _selectedLanguage = l),
              trailing: IconButton(
                icon: Icon(selecting ? Icons.close : Icons.checklist),
                tooltip: selecting ? 'Cancel selection' : 'Select multiple',
                onPressed: filtered.isEmpty && !selecting
                    ? null
                    : toggleSelectionMode,
              ),
            ),
            Expanded(
              child: MediaItemView(
                items: filtered,
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
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}
