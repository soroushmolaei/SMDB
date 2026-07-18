import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../providers/providers.dart';
import '../widgets/media_grid.dart';
import '../widgets/media_item.dart';
import 'genres_list_screen.dart';
import 'group_detail_screen.dart';
import 'movie_detail_screen.dart';
import 'mpa_list_screen.dart';
import 'people_tab.dart';
import 'settings_screen.dart';
import 'show_detail_screen.dart';

enum _Section {
  movies,
  shows,
  people,
  genres,
  mpa,
  latestAdditions,
  favorites,
  notYetWatched,
  watched,
}

enum _ContentMode { moviesOnly, showsOnly, combined }

enum _CombinedFilter { none, favorites, watched, notWatched }

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  _Section _section = _Section.movies;
  String _query = '';
  bool _gridView = true;
  String? _letterFilter;
  SortOption _sort = SortOption.titleAsc;
  String? _selectedGenre;
  int? _selectedYear;
  double? _minRating;

  String get _title {
    switch (_section) {
      case _Section.movies:
        return 'Movies';
      case _Section.shows:
        return 'Shows';
      case _Section.people:
        return 'People';
      case _Section.genres:
        return 'Genres';
      case _Section.mpa:
        return 'MPA';
      case _Section.latestAdditions:
        return 'Latest Additions';
      case _Section.favorites:
        return 'Favorites';
      case _Section.notYetWatched:
        return 'Not yet Watched';
      case _Section.watched:
        return 'Watched';
    }
  }

  bool get _isLibrarySection =>
      _section == _Section.movies ||
      _section == _Section.shows ||
      _section == _Section.latestAdditions ||
      _section == _Section.favorites ||
      _section == _Section.notYetWatched ||
      _section == _Section.watched;

  void _resetFiltersOnNav() {
    _letterFilter = null;
    _selectedGenre = null;
    _selectedYear = null;
    _minRating = null;
  }

  Future<void> _addAndScanFolder(String type) async {
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle:
          type == 'movie' ? 'Select movies folder' : 'Select shows folder',
    );
    if (selected == null) return;

    final db = ref.read(databaseProvider);
    await db.addFolder(selected, type);

    final controller = ref.read(scanControllerProvider.notifier);
    if (type == 'movie') {
      await controller.scanMovieFolder(selected);
    } else {
      await controller.scanShowFolder(selected);
    }
  }

  Future<void> _createGroup() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Group name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      final id = await ref.read(databaseProvider).createCollection(name);
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GroupDetailScreen(collectionId: id),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scanControllerProvider);
    final omdbConfigured = ref.watch(omdbServiceProvider) != null;
    final tmdbConfigured = ref.watch(tmdbServiceProvider) != null;
    final collections = ref.watch(collectionsStreamProvider).value ?? [];

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Sidebar(
            selected: _section,
            onSelect: (s) => setState(() {
              _section = s;
              _resetFiltersOnNav();
            }),
            onSettings: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            collections: collections,
            onGroupTap: (id) => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GroupDetailScreen(collectionId: id),
              ),
            ),
            onNewGroup: _createGroup,
          ),
          const VerticalDivider(width: 1, color: Colors.white12),
          Expanded(
            child: Column(
              children: [
                _Toolbar(
                  title: _title,
                  gridView: _gridView,
                  showAddButtons: _section == _Section.movies ||
                      _section == _Section.shows,
                  onToggleView: () => setState(() => _gridView = !_gridView),
                  onAddMovies: () => _addAndScanFolder('movie'),
                  onAddShows: () => _addAndScanFolder('show'),
                  onSearchChanged: (v) =>
                      setState(() => _query = v.toLowerCase()),
                ),
                if (!omdbConfigured && !tmdbConfigured)
                  _Banner(
                    text: 'Add an OMDb or TMDB API key in Settings to '
                        'fetch posters and details.',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()),
                    ),
                  ),
                if (scanState.status == ScanStatus.scanning ||
                    scanState.status == ScanStatus.matching)
                  LinearProgressIndicator(
                    value: scanState.total > 0
                        ? scanState.processed / scanState.total
                        : null,
                  ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_isLibrarySection)
                        _AlphabetIndex(
                          selected: _letterFilter,
                          onSelect: (l) =>
                              setState(() => _letterFilter = l),
                        ),
                      Expanded(child: _buildContent()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_section) {
      case _Section.movies:
        return _LibrarySection(
          mode: _ContentMode.moviesOnly,
          combinedFilter: _CombinedFilter.none,
          query: _query,
          letter: _letterFilter,
          gridView: _gridView,
          sort: _sort,
          onSortChanged: (s) => setState(() => _sort = s),
          selectedGenre: _selectedGenre,
          onGenreChanged: (g) => setState(() => _selectedGenre = g),
          selectedYear: _selectedYear,
          onYearChanged: (y) => setState(() => _selectedYear = y),
          minRating: _minRating,
          onMinRatingChanged: (r) => setState(() => _minRating = r),
          emptyTitle: 'No movies yet',
          emptySubtitle: 'Tap Add Movies above to scan a folder.',
        );
      case _Section.shows:
        return _LibrarySection(
          mode: _ContentMode.showsOnly,
          combinedFilter: _CombinedFilter.none,
          query: _query,
          letter: _letterFilter,
          gridView: _gridView,
          sort: _sort,
          onSortChanged: (s) => setState(() => _sort = s),
          selectedGenre: _selectedGenre,
          onGenreChanged: (g) => setState(() => _selectedGenre = g),
          selectedYear: null,
          onYearChanged: null,
          minRating: _minRating,
          onMinRatingChanged: (r) => setState(() => _minRating = r),
          emptyTitle: 'No shows yet',
          emptySubtitle: 'Tap Add Shows above to scan a folder.',
        );
      case _Section.people:
        return const PeopleTab();
      case _Section.genres:
        return const GenresListScreen();
      case _Section.mpa:
        return const MpaListScreen();
      case _Section.latestAdditions:
        return _LibrarySection(
          mode: _ContentMode.combined,
          combinedFilter: _CombinedFilter.none,
          query: _query,
          letter: _letterFilter,
          gridView: _gridView,
          sort: _sort,
          onSortChanged: (s) => setState(() => _sort = s),
          selectedGenre: _selectedGenre,
          onGenreChanged: (g) => setState(() => _selectedGenre = g),
          selectedYear: _selectedYear,
          onYearChanged: (y) => setState(() => _selectedYear = y),
          minRating: _minRating,
          onMinRatingChanged: (r) => setState(() => _minRating = r),
          emptyTitle: 'Nothing added yet',
          emptySubtitle: '',
        );
      case _Section.favorites:
        return _LibrarySection(
          mode: _ContentMode.combined,
          combinedFilter: _CombinedFilter.favorites,
          query: _query,
          letter: _letterFilter,
          gridView: _gridView,
          sort: _sort,
          onSortChanged: (s) => setState(() => _sort = s),
          selectedGenre: _selectedGenre,
          onGenreChanged: (g) => setState(() => _selectedGenre = g),
          selectedYear: _selectedYear,
          onYearChanged: (y) => setState(() => _selectedYear = y),
          minRating: _minRating,
          onMinRatingChanged: (r) => setState(() => _minRating = r),
          emptyTitle: 'No favorites yet',
          emptySubtitle: 'Tap the star on a movie or show to add it here.',
        );
      case _Section.notYetWatched:
        return _LibrarySection(
          mode: _ContentMode.combined,
          combinedFilter: _CombinedFilter.notWatched,
          query: _query,
          letter: _letterFilter,
          gridView: _gridView,
          sort: _sort,
          onSortChanged: (s) => setState(() => _sort = s),
          selectedGenre: _selectedGenre,
          onGenreChanged: (g) => setState(() => _selectedGenre = g),
          selectedYear: _selectedYear,
          onYearChanged: (y) => setState(() => _selectedYear = y),
          minRating: _minRating,
          onMinRatingChanged: (r) => setState(() => _minRating = r),
          emptyTitle: 'Everything is watched',
          emptySubtitle: '',
        );
      case _Section.watched:
        return _LibrarySection(
          mode: _ContentMode.combined,
          combinedFilter: _CombinedFilter.watched,
          query: _query,
          letter: _letterFilter,
          gridView: _gridView,
          sort: _sort,
          onSortChanged: (s) => setState(() => _sort = s),
          selectedGenre: _selectedGenre,
          onGenreChanged: (g) => setState(() => _selectedGenre = g),
          selectedYear: _selectedYear,
          onYearChanged: (y) => setState(() => _selectedYear = y),
          minRating: _minRating,
          onMinRatingChanged: (r) => setState(() => _minRating = r),
          emptyTitle: 'Nothing watched yet',
          emptySubtitle: '',
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Sidebar
// ---------------------------------------------------------------------------

class _Sidebar extends StatelessWidget {
  final _Section selected;
  final ValueChanged<_Section> onSelect;
  final VoidCallback onSettings;
  final List<Collection> collections;
  final ValueChanged<int> onGroupTap;
  final VoidCallback onNewGroup;

  const _Sidebar({
    required this.selected,
    required this.onSelect,
    required this.onSettings,
    required this.collections,
    required this.onGroupTap,
    required this.onNewGroup,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      color: const Color(0xFF17171C),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
            child: Row(
              children: [
                const Icon(Icons.movie_creation_outlined,
                    color: Color(0xFF6C5CE7)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'SMDB',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  tooltip: 'Settings',
                  onPressed: onSettings,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const _SectionHeader('MY COLLECTION'),
                _NavItem(
                  icon: Icons.movie_outlined,
                  label: 'Movies',
                  selected: selected == _Section.movies,
                  onTap: () => onSelect(_Section.movies),
                ),
                _NavItem(
                  icon: Icons.tv_outlined,
                  label: 'Shows',
                  selected: selected == _Section.shows,
                  onTap: () => onSelect(_Section.shows),
                ),
                _NavItem(
                  icon: Icons.people_outline,
                  label: 'People',
                  selected: selected == _Section.people,
                  onTap: () => onSelect(_Section.people),
                ),
                _NavItem(
                  icon: Icons.local_offer_outlined,
                  label: 'Genres',
                  selected: selected == _Section.genres,
                  onTap: () => onSelect(_Section.genres),
                ),
                _NavItem(
                  icon: Icons.shield_outlined,
                  label: 'MPA',
                  selected: selected == _Section.mpa,
                  onTap: () => onSelect(_Section.mpa),
                ),
                const SizedBox(height: 12),
                const _SectionHeader('MY VIEWS'),
                _NavItem(
                  icon: Icons.fiber_new_outlined,
                  label: 'Latest Additions',
                  selected: selected == _Section.latestAdditions,
                  onTap: () => onSelect(_Section.latestAdditions),
                ),
                _NavItem(
                  icon: Icons.star_outline,
                  label: 'Favorites',
                  selected: selected == _Section.favorites,
                  onTap: () => onSelect(_Section.favorites),
                ),
                _NavItem(
                  icon: Icons.flag_outlined,
                  label: 'Not yet Watched',
                  selected: selected == _Section.notYetWatched,
                  onTap: () => onSelect(_Section.notYetWatched),
                ),
                _NavItem(
                  icon: Icons.check_circle_outline,
                  label: 'Watched',
                  selected: selected == _Section.watched,
                  onTap: () => onSelect(_Section.watched),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'MY GROUPS',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 16),
                        tooltip: 'New group',
                        onPressed: onNewGroup,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 28, minHeight: 28),
                      ),
                    ],
                  ),
                ),
                if (collections.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 0, 14, 8),
                    child: Text(
                      'No groups yet',
                      style: TextStyle(fontSize: 12, color: Colors.white38),
                    ),
                  ),
                ...collections.map(
                  (c) => _NavItem(
                    icon: Icons.folder_outlined,
                    label: c.name,
                    selected: false,
                    onTap: () => onGroupTap(c.id),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.white38,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF6C5CE7).withOpacity(0.18) : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? const Color(0xFF9C91F5) : Colors.white60),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: selected ? Colors.white : Colors.white70,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Toolbar
// ---------------------------------------------------------------------------

class _Toolbar extends StatelessWidget {
  final String title;
  final bool gridView;
  final bool showAddButtons;
  final VoidCallback onToggleView;
  final VoidCallback onAddMovies;
  final VoidCallback onAddShows;
  final ValueChanged<String> onSearchChanged;

  const _Toolbar({
    required this.title,
    required this.gridView,
    required this.showAddButtons,
    required this.onToggleView,
    required this.onAddMovies,
    required this.onAddShows,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (showAddButtons) ...[
            OutlinedButton.icon(
              onPressed: onAddMovies,
              icon: const Icon(Icons.movie_outlined, size: 16),
              label: const Text('Add Movies'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onAddShows,
              icon: const Icon(Icons.tv_outlined, size: 16),
              label: const Text('Add Shows'),
            ),
            const SizedBox(width: 12),
          ],
          SizedBox(
            width: 220,
            height: 36,
            child: TextField(
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 18),
                hintText: 'Search...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(gridView ? Icons.view_list_outlined : Icons.grid_view),
            tooltip: gridView ? 'List view' : 'Grid view',
            onPressed: onToggleView,
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _Banner({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.amber.shade800,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.black)),
          ),
          TextButton(onPressed: onTap, child: const Text('Open Settings')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// A-Z index
// ---------------------------------------------------------------------------

class _AlphabetIndex extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelect;
  const _AlphabetIndex({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const letters = [
      'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', //
      'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', '#',
    ];
    return Container(
      width: 26,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        children: letters.map((l) {
          final isSelected = selected == l;
          return InkWell(
            onTap: () => onSelect(isSelected ? null : l),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 3),
              color:
                  isSelected ? const Color(0xFF6C5CE7).withOpacity(0.3) : null,
              alignment: Alignment.center,
              child: Text(
                l,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? Colors.white : Colors.white38,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Unified library section: movies-only, shows-only, or combined, with
// search, letter index, genre/year/rating filters, and sort — all sharing
// one implementation via MediaItem.
// ---------------------------------------------------------------------------

class _LibrarySection extends ConsumerWidget {
  final _ContentMode mode;
  final _CombinedFilter combinedFilter;
  final String query;
  final String? letter;
  final bool gridView;
  final SortOption sort;
  final ValueChanged<SortOption> onSortChanged;
  final String? selectedGenre;
  final ValueChanged<String?> onGenreChanged;
  final int? selectedYear;
  final ValueChanged<int?>? onYearChanged;
  final double? minRating;
  final ValueChanged<double?> onMinRatingChanged;
  final String emptyTitle;
  final String emptySubtitle;

  const _LibrarySection({
    required this.mode,
    required this.combinedFilter,
    required this.query,
    required this.letter,
    required this.gridView,
    required this.sort,
    required this.onSortChanged,
    required this.selectedGenre,
    required this.onGenreChanged,
    required this.selectedYear,
    required this.onYearChanged,
    required this.minRating,
    required this.onMinRatingChanged,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moviesAsync = ref.watch(moviesStreamProvider);
    final needsShows =
        mode == _ContentMode.showsOnly || mode == _ContentMode.combined;
    final List<Show> shows = needsShows
        ? (ref.watch(showsStreamProvider).value ?? const <Show>[])
        : const <Show>[];
    final needsEpisodes =
        needsShows && combinedFilter != _CombinedFilter.none;
    final List<Episode> episodes = needsEpisodes
        ? (ref.watch(allEpisodesStreamProvider).value ?? const <Episode>[])
        : const <Episode>[];

    return moviesAsync.when(
      data: (movies) {
        final items = <MediaItem>[];

        if (mode == _ContentMode.moviesOnly || mode == _ContentMode.combined) {
          for (final m in movies) {
            items.add(MediaItem(
              kind: 'movie',
              id: m.id,
              title: m.title,
              year: m.year,
              posterPath: m.posterPath,
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
            ));
          }
        }

        if (needsShows) {
          for (final s in shows) {
            bool showWatched = false;
            if (needsEpisodes) {
              final showEpisodes =
                  episodes.where((e) => e.showId == s.id).toList();
              if (showEpisodes.isNotEmpty) {
                showWatched = showEpisodes.every((e) => e.watched);
              }
            }
            items.add(MediaItem(
              kind: 'show',
              id: s.id,
              title: s.title,
              year: null,
              posterPath: s.posterPath,
              rating: s.rating,
              genres: s.genres,
              watched: showWatched,
              isFavorite: s.isFavorite,
              dateAdded: s.dateAdded,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ShowDetailScreen(showId: s.id),
                ),
              ),
            ));
          }
        }

        var filtered = items.where((item) {
          if (query.isNotEmpty &&
              !item.title.toLowerCase().contains(query)) {
            return false;
          }
          if (letter != null) {
            final first =
                item.title.isEmpty ? '#' : item.title[0].toLowerCase();
            if (letter == '#') {
              if (RegExp(r'[a-z]').hasMatch(first)) return false;
            } else if (first != letter) {
              return false;
            }
          }
          if (selectedGenre != null) {
            final genres =
                (item.genres ?? '').split(',').map((g) => g.trim());
            if (!genres.contains(selectedGenre)) return false;
          }
          if (selectedYear != null && item.year != selectedYear) {
            return false;
          }
          if (minRating != null &&
              (item.rating == null || item.rating! < minRating!)) {
            return false;
          }
          switch (combinedFilter) {
            case _CombinedFilter.favorites:
              if (!item.isFavorite) return false;
              break;
            case _CombinedFilter.watched:
              if (!item.watched) return false;
              break;
            case _CombinedFilter.notWatched:
              if (item.watched) return false;
              break;
            case _CombinedFilter.none:
              break;
          }
          return true;
        }).toList();

        sortMediaItems(filtered, sort);

        final genreSet = <String>{};
        final yearSet = <int>{};
        for (final item in items) {
          if (item.genres != null) {
            for (final g in item.genres!.split(',')) {
              final t = g.trim();
              if (t.isNotEmpty) genreSet.add(t);
            }
          }
          if (item.year != null) yearSet.add(item.year!);
        }
        final genreList = genreSet.toList()..sort();
        final yearList = yearSet.toList()..sort((a, b) => b.compareTo(a));

        return Column(
          children: [
            SortFilterBar(
              sort: sort,
              onSortChanged: onSortChanged,
              selectedGenre: selectedGenre,
              availableGenres: genreList,
              onGenreChanged: onGenreChanged,
              selectedYear: selectedYear,
              availableYears: yearList,
              onYearChanged: onYearChanged,
              minRating: minRating,
              onMinRatingChanged: onMinRatingChanged,
            ),
            Expanded(
              child: MediaItemView(
                items: filtered,
                gridView: gridView,
                emptyTitle: items.isEmpty ? emptyTitle : 'No matches',
                emptySubtitle: items.isEmpty
                    ? emptySubtitle
                    : 'Try a different search or clear filters.',
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
