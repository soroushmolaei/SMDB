import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../widgets/media_grid.dart';
import '../widgets/media_item.dart';
import 'movie_detail_screen.dart';
import 'show_detail_screen.dart';

/// Top-level "MY COLLECTION > Language" screen: one tile per distinct
/// `originalLanguage` value (shared by movies and shows), with a count,
/// linking to [LanguageMoviesScreen].
class LanguageListScreen extends ConsumerWidget {
  const LanguageListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moviesAsync = ref.watch(moviesStreamProvider);
    final shows = ref.watch(showsStreamProvider).value ?? [];

    return moviesAsync.when(
      data: (movies) {
        final counts = <String, int>{};
        for (final m in movies) {
          final lang = m.originalLanguage;
          if (lang == null || lang.isEmpty) continue;
          counts[lang] = (counts[lang] ?? 0) + 1;
        }
        for (final s in shows) {
          final lang = s.originalLanguage;
          if (lang == null || lang.isEmpty) continue;
          counts[lang] = (counts[lang] ?? 0) + 1;
        }
        final languages = counts.keys.toList()..sort();

        if (languages.isEmpty) {
          return const Center(
            child: Text(
              'No languages yet — scan a movie or show folder first, or '
              'tap Update on existing titles to fill this in.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            childAspectRatio: 3.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: languages.length,
          itemBuilder: (context, index) {
            final language = languages[index];
            return Card(
              color: Colors.white.withValues(alpha: 0.05),
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        LanguageMoviesScreen(language: language),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.language, color: Color(0xFF9C91F5)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          language,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        '${counts[language]}',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

/// Drill-down for a single original language: every movie/show that
/// matches, with the same sort/filter/multi-select/bulk-refresh treatment
/// as the other MY COLLECTION drill-downs.
class LanguageMoviesScreen extends ConsumerStatefulWidget {
  final String language;
  const LanguageMoviesScreen({super.key, required this.language});

  @override
  ConsumerState<LanguageMoviesScreen> createState() =>
      _LanguageMoviesScreenState();
}

class _LanguageMoviesScreenState extends ConsumerState<LanguageMoviesScreen>
    with MediaSelectionMixin<LanguageMoviesScreen> {
  SortOption _sort = SortOption.titleAsc;
  String? _selectedKind;

  @override
  Widget build(BuildContext context) {
    final moviesAsync = ref.watch(moviesStreamProvider);
    final shows = ref.watch(showsStreamProvider).value ?? [];
    final busy =
        ref.watch(scanControllerProvider).status == ScanStatus.matching;

    return Scaffold(
      appBar: AppBar(title: Text(widget.language)),
      body: moviesAsync.when(
        data: (movies) {
          final items = <MediaItem>[
            if (_selectedKind == null || _selectedKind == 'movie')
              ...movies
                  .where((m) => m.originalLanguage == widget.language)
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
                  .where((s) => s.originalLanguage == widget.language)
                  .map((s) => MediaItem(
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
                  emptyTitle: 'No movies or shows in this language',
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
