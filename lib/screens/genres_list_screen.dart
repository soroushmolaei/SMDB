import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../widgets/media_grid.dart';
import '../widgets/media_item.dart';
import 'movie_detail_screen.dart';
import 'show_detail_screen.dart';

class GenresListScreen extends ConsumerStatefulWidget {
  const GenresListScreen({super.key});

  @override
  ConsumerState<GenresListScreen> createState() => _GenresListScreenState();
}

class _GenresListScreenState extends ConsumerState<GenresListScreen> {
  bool _combineMode = false;
  final Set<String> _selected = {};

  void _openGenres(List<String> genres) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GenreDetailScreen(genres: genres),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final moviesAsync = ref.watch(moviesStreamProvider);
    final shows = ref.watch(showsStreamProvider).value ?? [];
    final colorScheme = Theme.of(context).colorScheme;

    return moviesAsync.when(
      data: (movies) {
        final counts = <String, int>{};
        void addGenres(String? raw) {
          if (raw == null) return;
          for (final g in raw.split(',')) {
            final trimmed = g.trim();
            if (trimmed.isEmpty) continue;
            counts[trimmed] = (counts[trimmed] ?? 0) + 1;
          }
        }

        for (final m in movies) {
          addGenres(m.genres);
        }
        for (final s in shows) {
          addGenres(s.genres);
        }
        final genres = counts.keys.toList()..sort();

        if (genres.isEmpty) {
          return const Center(
            child: Text(
              'No genres yet — scan a movie or show folder first.',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  if (!_combineMode)
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _combineMode = true),
                      icon: const Icon(Icons.checklist, size: 18),
                      label: const Text('Combine genres'),
                    )
                  else ...[
                    Expanded(
                      child: Text(
                        _selected.isEmpty
                            ? 'Select genres to combine — titles that have '
                                'all of them will be shown'
                            : '${_selected.length} selected: '
                                '${(_selected.toList()..sort()).join(', ')}',
                        style: const TextStyle(color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _combineMode = false;
                        _selected.clear();
                      }),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => _openGenres(_selected.toList()..sort()),
                      child: const Text('Show'),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  childAspectRatio: 3.2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: genres.length,
                itemBuilder: (context, index) {
                  final genre = genres[index];
                  final isSelected = _selected.contains(genre);
                  return Card(
                    color: _combineMode && isSelected
                        ? colorScheme.primary.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.05),
                    shape: _combineMode && isSelected
                        ? RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                            side: BorderSide(
                                color: colorScheme.primary, width: 1.5),
                          )
                        : null,
                    child: InkWell(
                      onTap: () {
                        if (_combineMode) {
                          setState(() {
                            if (isSelected) {
                              _selected.remove(genre);
                            } else {
                              _selected.add(genre);
                            }
                          });
                        } else {
                          _openGenres([genre]);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            if (_combineMode)
                              Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: isSelected
                                    ? colorScheme.primary
                                    : Colors.white38,
                              )
                            else
                              const Icon(Icons.local_offer_outlined,
                                  color: Color(0xFF9C91F5)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                genre,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                            Text(
                              '${counts[genre]}',
                              style:
                                  const TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
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

class GenreDetailScreen extends ConsumerStatefulWidget {
  /// One or more genres. When more than one is given, only titles that
  /// have ALL of them (not just any one) are shown — e.g. ['Drama',
  /// 'Family'] finds titles that are both Drama and Family at once.
  final List<String> genres;
  const GenreDetailScreen({super.key, required this.genres});

  @override
  ConsumerState<GenreDetailScreen> createState() => _GenreDetailScreenState();
}

class _GenreDetailScreenState extends ConsumerState<GenreDetailScreen>
    with MediaSelectionMixin<GenreDetailScreen> {
  SortOption _sort = SortOption.titleAsc;
  String? _selectedKind;

  @override
  Widget build(BuildContext context) {
    final moviesAsync = ref.watch(moviesStreamProvider);
    final shows = ref.watch(showsStreamProvider).value ?? [];
    final busy =
        ref.watch(scanControllerProvider).status == ScanStatus.matching;

    return Scaffold(
      appBar: AppBar(title: Text(widget.genres.join(' + '))),
      body: moviesAsync.when(
        data: (movies) {
          bool hasAllGenres(String? raw) {
            final itemGenres =
                (raw ?? '').split(',').map((g) => g.trim()).toSet();
            return widget.genres.every(itemGenres.contains);
          }

          final items = <MediaItem>[
            if (_selectedKind == null || _selectedKind == 'movie')
              ...movies
                  .where((m) => hasAllGenres(m.genres))
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
                            builder: (_) => MovieDetailScreen(movieId: m.id),
                          ),
                        ),
                      )),
            if (_selectedKind == null || _selectedKind == 'show')
              ...shows
                  .where((s) => hasAllGenres(s.genres))
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
                            builder: (_) => ShowDetailScreen(showId: s.id),
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
                onKindChanged: (k) => setState(() => _selectedKind = k),
                trailing: IconButton(
                  icon: Icon(selecting ? Icons.close : Icons.checklist),
                  tooltip: selecting ? 'Cancel selection' : 'Select multiple',
                  onPressed:
                      items.isEmpty && !selecting ? null : toggleSelectionMode,
                ),
              ),
              Expanded(
                child: MediaItemView(
                  items: items,
                  gridView: true,
                  emptyTitle: widget.genres.length > 1
                      ? 'No movies or shows have all of these genres'
                      : 'No movies or shows in this genre',
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
      ),
    );
  }
}
