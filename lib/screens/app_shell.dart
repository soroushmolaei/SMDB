import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../widgets/poster_card.dart';
import 'genres_list_screen.dart';
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

  bool get _showsLetterIndex => _section != _Section.shows &&
      _section != _Section.people &&
      _section != _Section.genres &&
      _section != _Section.mpa;

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

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scanControllerProvider);
    final omdbConfigured = ref.watch(omdbServiceProvider) != null;
    final tmdbConfigured = ref.watch(tmdbServiceProvider) != null;

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Sidebar(
            selected: _section,
            onSelect: (s) => setState(() {
              _section = s;
              _letterFilter = null;
            }),
            onSettings: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
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
                      if (_showsLetterIndex)
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
        return _MoviesGrid(
          query: _query,
          letter: _letterFilter,
          gridView: _gridView,
        );
      case _Section.shows:
        return _ShowsGrid(query: _query, gridView: _gridView);
      case _Section.people:
        return const PeopleTab();
      case _Section.genres:
        return const GenresListScreen();
      case _Section.mpa:
        return const MpaListScreen();
      case _Section.latestAdditions:
        return _MoviesGrid(
          query: _query,
          letter: _letterFilter,
          gridView: _gridView,
          sortByDateAdded: true,
        );
      case _Section.favorites:
        return _MoviesGrid(
          query: _query,
          letter: _letterFilter,
          gridView: _gridView,
          onlyFavorites: true,
        );
      case _Section.notYetWatched:
        return _MoviesGrid(
          query: _query,
          letter: _letterFilter,
          gridView: _gridView,
          onlyUnwatched: true,
        );
      case _Section.watched:
        return _MoviesGrid(
          query: _query,
          letter: _letterFilter,
          gridView: _gridView,
          onlyWatched: true,
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

  const _Sidebar({
    required this.selected,
    required this.onSelect,
    required this.onSettings,
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
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
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
// Movies grid (shared by Movies / Latest Additions / Favorites / Watched /
// Not yet Watched)
// ---------------------------------------------------------------------------

class _MoviesGrid extends ConsumerWidget {
  final String query;
  final String? letter;
  final bool gridView;
  final bool sortByDateAdded;
  final bool onlyFavorites;
  final bool onlyWatched;
  final bool onlyUnwatched;

  const _MoviesGrid({
    required this.query,
    required this.letter,
    required this.gridView,
    this.sortByDateAdded = false,
    this.onlyFavorites = false,
    this.onlyWatched = false,
    this.onlyUnwatched = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moviesAsync = ref.watch(moviesStreamProvider);
    return moviesAsync.when(
      data: (movies) {
        var filtered = movies.where((m) {
          if (query.isNotEmpty) {
            final haystack = [
              m.title,
              m.castNames ?? '',
              m.director ?? '',
              m.writer ?? '',
              m.genres ?? '',
            ].join(' ').toLowerCase();
            if (!haystack.contains(query)) return false;
          }
          if (letter != null) {
            final first = m.title.isEmpty ? '#' : m.title[0].toLowerCase();
            if (letter == '#') {
              if (RegExp(r'[a-z]').hasMatch(first)) return false;
            } else if (first != letter) {
              return false;
            }
          }
          if (onlyFavorites && !m.isFavorite) return false;
          if (onlyWatched && !m.watched) return false;
          if (onlyUnwatched && m.watched) return false;
          return true;
        }).toList();

        if (sortByDateAdded) {
          filtered.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        } else {
          filtered.sort((a, b) => a.title.compareTo(b.title));
        }

        if (filtered.isEmpty) {
          return const Center(
            child: Text('No movies here yet',
                style: TextStyle(color: Colors.white54)),
          );
        }

        if (!gridView) {
          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final movie = filtered[index];
              return ListTile(
                leading: SizedBox(
                  width: 40,
                  child: movie.posterPath != null
                      ? Image.network(movie.posterPath!, fit: BoxFit.cover)
                      : const Icon(Icons.movie_outlined),
                ),
                title: Text(movie.title),
                subtitle: Text([
                  if (movie.year != null) '${movie.year}',
                  if (movie.genres != null) movie.genres!,
                ].join(' • ')),
                trailing: movie.rating != null
                    ? Text(movie.rating!.toStringAsFixed(1))
                    : null,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MovieDetailScreen(movieId: movie.id),
                  ),
                ),
              );
            },
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 150,
            childAspectRatio: 0.55,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final movie = filtered[index];
            return PosterCard(
              title: movie.title,
              posterUrl: movie.posterPath,
              watched: movie.watched,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MovieDetailScreen(movieId: movie.id),
                ),
              ),
              onToggleWatched: () => ref
                  .read(databaseProvider)
                  .setMovieWatched(movie.id, !movie.watched),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

class _ShowsGrid extends ConsumerWidget {
  final String query;
  final bool gridView;
  const _ShowsGrid({required this.query, required this.gridView});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showsAsync = ref.watch(showsStreamProvider);
    return showsAsync.when(
      data: (shows) {
        final filtered = (query.isEmpty
            ? shows
            : shows.where((s) {
                final haystack = '${s.title} ${s.genres ?? ''}'.toLowerCase();
                return haystack.contains(query);
              }).toList())
          ..sort((a, b) => a.title.compareTo(b.title));

        if (filtered.isEmpty) {
          return const Center(
            child: Text('No shows here yet',
                style: TextStyle(color: Colors.white54)),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 150,
            childAspectRatio: 0.55,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final show = filtered[index];
            return PosterCard(
              title: show.title,
              posterUrl: show.posterPath,
              watched: false,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ShowDetailScreen(showId: show.id),
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
