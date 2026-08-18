import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../widgets/media_grid.dart';
import '../widgets/media_item.dart';
import 'movie_detail_screen.dart';
import 'show_detail_screen.dart';

/// Shows every movie and show that ALL of [personIds] (2 or more) are
/// credited on — e.g. "what have these two actors done together".
///
/// A person counts as credited on a show either via a main show credit
/// (cast/creator) or via a guest-star episode credit, same as how the
/// People tab and person detail page already treat show association —
/// so this stays consistent with the counts shown elsewhere in the app.
class SharedFilmographyScreen extends ConsumerStatefulWidget {
  final List<int> personIds;
  final List<String> personNames;

  const SharedFilmographyScreen({
    super.key,
    required this.personIds,
    required this.personNames,
  });

  @override
  ConsumerState<SharedFilmographyScreen> createState() =>
      _SharedFilmographyScreenState();
}

class _SharedFilmographyScreenState
    extends ConsumerState<SharedFilmographyScreen>
    with MediaSelectionMixin<SharedFilmographyScreen> {
  SortOption _sort = SortOption.titleAsc;
  bool _gridView = true;
  String? _selectedKind;

  String get _headerTitle {
    final names = widget.personNames;
    if (names.isEmpty) return 'Shared titles';
    if (names.length == 1) return names.first;
    if (names.length == 2) return '${names[0]} & ${names[1]}';
    return '${names.sublist(0, names.length - 1).join(', ')} '
        '& ${names.last}';
  }

  @override
  Widget build(BuildContext context) {
    final movieCreditsAsync = ref.watch(allCreditsStreamProvider);
    final showCreditsAsync = ref.watch(allShowCreditsStreamProvider);
    final episodeCreditsAsync = ref.watch(allEpisodeCreditsStreamProvider);
    final moviesAsync = ref.watch(moviesStreamProvider);
    final showsAsync = ref.watch(showsStreamProvider);
    final episodesAsync = ref.watch(allEpisodesStreamProvider);
    final busy =
        ref.watch(scanControllerProvider).status == ScanStatus.matching;

    return Scaffold(
      appBar: AppBar(
        title: Text('Shared with $_headerTitle'),
        actions: [
          IconButton(
            icon: Icon(_gridView ? Icons.view_list : Icons.grid_view),
            tooltip: _gridView ? 'List view' : 'Grid view',
            onPressed: () => setState(() => _gridView = !_gridView),
          ),
        ],
      ),
      body: movieCreditsAsync.when(
        data: (allMovieCredits) => showCreditsAsync.when(
          data: (allShowCredits) => episodeCreditsAsync.when(
            data: (allEpisodeCredits) => moviesAsync.when(
              data: (movies) => showsAsync.when(
                data: (shows) => episodesAsync.when(
                  data: (episodes) {
                    final movieById = {for (final m in movies) m.id: m};
                    final showById = {for (final s in shows) s.id: s};
                    final episodeShowId = {
                      for (final e in episodes) e.id: e.showId,
                    };
                    final wanted = widget.personIds.toSet();

                    // movieId -> set of person ids credited on it (any
                    // role: actor/director/writer).
                    final peopleByMovie = <int, Set<int>>{};
                    for (final c in allMovieCredits) {
                      if (!movieById.containsKey(c.movieId)) continue;
                      peopleByMovie
                          .putIfAbsent(c.movieId, () => {})
                          .add(c.personId);
                    }

                    // showId -> set of person ids credited on it, merging
                    // main show credits (actor/creator) with guest-star
                    // episode credits mapped up to their parent show.
                    final peopleByShow = <int, Set<int>>{};
                    for (final c in allShowCredits) {
                      if (!showById.containsKey(c.showId)) continue;
                      peopleByShow
                          .putIfAbsent(c.showId, () => {})
                          .add(c.personId);
                    }
                    for (final c in allEpisodeCredits) {
                      final showId = episodeShowId[c.episodeId];
                      if (showId == null || !showById.containsKey(showId)) {
                        continue;
                      }
                      peopleByShow
                          .putIfAbsent(showId, () => {})
                          .add(c.personId);
                    }

                    final items = <MediaItem>[
                      if (_selectedKind == null || _selectedKind == 'movie')
                        ...peopleByMovie.entries
                            .where((e) => e.value.containsAll(wanted))
                            .map((e) => movieById[e.key]!)
                            .map((m) => MediaItem(
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
                                      builder: (_) =>
                                          MovieDetailScreen(movieId: m.id),
                                    ),
                                  ),
                                )),
                      if (_selectedKind == null || _selectedKind == 'show')
                        ...peopleByShow.entries
                            .where((e) => e.value.containsAll(wanted))
                            .map((e) => showById[e.key]!)
                            .map((s) => MediaItem(
                                  kind: 'show',
                                  id: s.id,
                                  title: s.title,
                                  year: null,
                                  posterPath: s.posterPath,
                                  posterThumbnail: s.posterThumbnail,
                                  rating: s.rating,
                                  genres: s.genres,
                                  watched: false,
                                  isFavorite: s.isFavorite,
                                  dateAdded: s.dateAdded,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ShowDetailScreen(showId: s.id),
                                    ),
                                  ),
                                )),
                    ];
                    sortMediaItems(items, _sort);

                    return Column(
                      children: [
                        if (selecting)
                          SelectionActionBar(
                            selectedCount: selectedKeys.length,
                            totalCount: items.length,
                            busy: busy,
                            onSelectAll: () => selectAll(items),
                            onClear: clearSelection,
                            onCancel: toggleSelectionMode,
                            onRefresh: refreshSelected,
                          ),
                        SortFilterBar(
                          sort: _sort,
                          onSortChanged: (s) => setState(() => _sort = s),
                          selectedKind: _selectedKind,
                          onKindChanged: (k) =>
                              setState(() => _selectedKind = k),
                          trailing: IconButton(
                            icon: Icon(
                                selecting ? Icons.close : Icons.checklist),
                            tooltip: selecting
                                ? 'Cancel selection'
                                : 'Select multiple',
                            onPressed: items.isEmpty && !selecting
                                ? null
                                : toggleSelectionMode,
                          ),
                        ),
                        Expanded(
                          child: MediaItemView(
                            items: items,
                            gridView: _gridView,
                            emptyTitle: 'No shared titles',
                            emptySubtitle: 'These people have not '
                                'appeared in anything together yet.',
                            selectionMode: selecting,
                            selectedKeys: selectedKeys,
                            onToggleSelect: toggleItemSelection,
                          ),
                        ),
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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
