import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../providers/providers.dart';
import '../widgets/media_grid.dart';
import '../widgets/media_item.dart';
import 'movie_detail_screen.dart';
import 'show_detail_screen.dart';

/// Browse the library by release year: a timeline histogram (one bar per
/// year, height = how many titles) with a [RangeSlider] to narrow down to
/// a specific span, backed by `Movies.year` / `Shows.year`.
///
/// Titles without a known year (mainly shows added before that field
/// existed, until they're re-matched) can't be placed on the timeline, so
/// they're excluded here rather than silently mis-bucketed -- with a note
/// saying how many were left out.
class YearScreen extends ConsumerStatefulWidget {
  const YearScreen({super.key});

  @override
  ConsumerState<YearScreen> createState() => _YearScreenState();
}

class _YearScreenState extends ConsumerState<YearScreen>
    with MediaSelectionMixin<YearScreen> {
  SortOption _sort = SortOption.yearNewest;
  RangeValues? _range;
  String? _selectedKind;

  @override
  Widget build(BuildContext context) {
    final moviesAsync = ref.watch(moviesStreamProvider);
    final shows = ref.watch(showsStreamProvider).value ?? [];
    final busy =
        ref.watch(scanControllerProvider).status == ScanStatus.matching;
    final colorScheme = Theme.of(context).colorScheme;

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

        final dated = <MediaItem>[
          if (_selectedKind == null || _selectedKind == 'movie')
            ...movies.where((m) => m.year != null).map(toMovieItem),
          if (_selectedKind == null || _selectedKind == 'show')
            ...shows.where((s) => s.year != null).map(toShowItem),
        ];
        // Respects the kind filter too, so this stays accurate when
        // narrowed to Movies only or Shows only rather than comparing
        // against the unfiltered grand total.
        final relevantMovieCount = _selectedKind == 'show' ? 0 : movies.length;
        final relevantShowCount = _selectedKind == 'movie' ? 0 : shows.length;
        final missingYearCount =
            relevantMovieCount + relevantShowCount - dated.length;

        if (dated.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                missingYearCount > 0
                    ? 'None of your $missingYearCount movies/shows have a '
                        'known release year yet. Scan or tap Update on '
                        'them to fill this in.'
                    : 'No movies or shows yet — scan a folder first.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54),
              ),
            ),
          );
        }

        final years = dated.map((e) => e.year!).toList();
        final minYear = years.reduce((a, b) => a < b ? a : b);
        final maxYear = years.reduce((a, b) => a > b ? a : b);
        final hasSpan = maxYear > minYear;

        final current = _range ??
            RangeValues(minYear.toDouble(), maxYear.toDouble());
        final start = current.start
            .clamp(minYear.toDouble(), maxYear.toDouble())
            .toDouble();
        final end = current.end
            .clamp(minYear.toDouble(), maxYear.toDouble())
            .toDouble();

        final countByYear = <int, int>{};
        for (final y in years) {
          countByYear[y] = (countByYear[y] ?? 0) + 1;
        }
        final maxCount = countByYear.values
            .fold<int>(0, (a, b) => a > b ? a : b);

        final filtered = dated
            .where((e) => e.year! >= start.round() && e.year! <= end.round())
            .toList();
        sortMediaItems(filtered, _sort);

        final isFullRange =
            start.round() == minYear && end.round() == maxYear;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          hasSpan
                              ? '${filtered.length} title'
                                  '${filtered.length == 1 ? '' : 's'} • '
                                  '${start.round()}–${end.round()}'
                              : '${filtered.length} title'
                                  '${filtered.length == 1 ? '' : 's'} • '
                                  '$minYear',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (hasSpan && !isFullRange)
                        TextButton(
                          onPressed: () => setState(() {
                            _range = RangeValues(
                              minYear.toDouble(),
                              maxYear.toDouble(),
                            );
                          }),
                          child: const Text('Reset'),
                        ),
                    ],
                  ),
                  if (hasSpan) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 46,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var y = minYear; y <= maxYear; y++)
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 0.5),
                                child: Container(
                                  height: maxCount == 0
                                      ? 3.0
                                      : 3.0 +
                                          39.0 *
                                              ((countByYear[y] ?? 0) /
                                                  maxCount),
                                  decoration: BoxDecoration(
                                    color: y >= start.round() &&
                                            y <= end.round()
                                        ? colorScheme.primary
                                        : Colors.white12,
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    RangeSlider(
                      values: RangeValues(start, end),
                      min: minYear.toDouble(),
                      max: maxYear.toDouble(),
                      divisions: maxYear - minYear,
                      labels: RangeLabels(
                        '${start.round()}',
                        '${end.round()}',
                      ),
                      onChanged: (values) => setState(() => _range = values),
                    ),
                  ],
                  if (missingYearCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '$missingYearCount title'
                        '${missingYearCount == 1 ? '' : 's'} without a '
                        "known year aren't shown here.",
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
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
              selectedKind: _selectedKind,
              onKindChanged: (k) => setState(() => _selectedKind = k),
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
                emptyTitle: 'No titles in this range',
                emptySubtitle: 'Try widening the year range above.',
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
