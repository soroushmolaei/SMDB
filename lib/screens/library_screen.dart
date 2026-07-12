import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../widgets/poster_card.dart';
import 'movie_detail_screen.dart';
import 'settings_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _query = '';
  String? _selectedGenre;
  int? _selectedYear;
  double? _minRating;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final moviesAsync = ref.watch(moviesStreamProvider);
    final showsAsync = ref.watch(showsStreamProvider);
    final scanState = ref.watch(scanControllerProvider);
    final omdbConfigured = ref.watch(omdbServiceProvider) != null;
    final tmdbConfigured = ref.watch(tmdbServiceProvider) != null;
    final noSourceConfigured = !omdbConfigured && !tmdbConfigured;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SMDB'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Movies'),
            Tab(text: 'Shows'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (noSourceConfigured)
            Container(
              width: double.infinity,
              color: Colors.amber.shade800,
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Add an OMDb or TMDB API key in Settings to fetch posters and details.',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()),
                    ),
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
            ),
          if (scanState.status == ScanStatus.scanning ||
              scanState.status == ScanStatus.matching)
            LinearProgressIndicator(
              value: scanState.total > 0
                  ? scanState.processed / scanState.total
                  : null,
            ),
          if (scanState.status == ScanStatus.matching)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Matching: ${scanState.currentItem ?? ''} '
                  '(${scanState.processed}/${scanState.total})',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          if (scanState.status == ScanStatus.done && scanState.total > 0)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scanState.networkErrors > 0
                    ? Colors.red.shade900
                    : Colors.green.shade900,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scanState.networkErrors > 0
                        ? 'Scan finished: ${scanState.matched}/${scanState.total} '
                            'matched, ${scanState.networkErrors} source '
                            'lookups failed (see below).'
                        : 'Scan finished: ${scanState.matched}/${scanState.total} '
                            'matched.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (scanState.networkErrors > 0 &&
                      scanState.lastError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      scanState.lastError!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'If a source is blocked on your network, check the '
                      'proxy in Settings. Files were still added to your '
                      'library even without posters.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search title, cast, director, writer...',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                moviesAsync.when(
                  data: (movies) {
                    final allGenres = <String>{};
                    final allYears = <int>{};
                    for (final m in movies) {
                      if (m.genres != null) {
                        for (final g in m.genres!.split(',')) {
                          final t = g.trim();
                          if (t.isNotEmpty) allGenres.add(t);
                        }
                      }
                      if (m.year != null) allYears.add(m.year!);
                    }
                    final sortedGenres = allGenres.toList()..sort();
                    final sortedYears = allYears.toList()
                      ..sort((a, b) => b.compareTo(a));

                    final filtered = movies.where((m) {
                      if (_query.isNotEmpty) {
                        final haystack = [
                          m.title,
                          m.castNames ?? '',
                          m.director ?? '',
                          m.writer ?? '',
                          m.genres ?? '',
                        ].join(' ').toLowerCase();
                        if (!haystack.contains(_query)) return false;
                      }
                      if (_selectedGenre != null) {
                        final genres = (m.genres ?? '')
                            .split(',')
                            .map((g) => g.trim());
                        if (!genres.contains(_selectedGenre)) return false;
                      }
                      if (_selectedYear != null && m.year != _selectedYear) {
                        return false;
                      }
                      if (_minRating != null &&
                          (m.rating == null || m.rating! < _minRating!)) {
                        return false;
                      }
                      return true;
                    }).toList();

                    return Column(
                      children: [
                        if (movies.isNotEmpty)
                          _buildFilterRow(sortedGenres, sortedYears),
                        Expanded(
                          child: filtered.isEmpty
                              ? _emptyState(
                                  movies.isEmpty
                                      ? 'No movies yet'
                                      : 'No matches',
                                  movies.isEmpty
                                      ? 'Add a folder to scan your movie collection.'
                                      : 'Try a different search or clear filters.',
                                  () => _addAndScanFolder('movie'),
                                )
                              : GridView.builder(
                                  padding: const EdgeInsets.all(12),
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
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
                                          builder: (_) => MovieDetailScreen(
                                              movieId: movie.id),
                                        ),
                                      ),
                                      onToggleWatched: () => ref
                                          .read(databaseProvider)
                                          .setMovieWatched(
                                              movie.id, !movie.watched),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('Error: $e')),
                ),
                showsAsync.when(
                  data: (shows) {
                    final filtered = _query.isEmpty
                        ? shows
                        : shows.where((s) {
                            final haystack =
                                '${s.title} ${s.genres ?? ''}'.toLowerCase();
                            return haystack.contains(_query);
                          }).toList();
                    if (filtered.isEmpty) {
                      return _emptyState(
                        'No shows yet',
                        'Add a folder to scan your TV show collection.',
                        () => _addAndScanFolder('show'),
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
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
                          onTap: () {},
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('Error: $e')),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addAndScanFolder(
          _tabController.index == 0 ? 'movie' : 'show',
        ),
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('Add Folder'),
      ),
    );
  }

  Widget _buildFilterRow(List<String> genres, List<int> years) {
    final hasActiveFilters = _selectedGenre != null ||
        _selectedYear != null ||
        _minRating != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            DropdownButton<String?>(
              value: _selectedGenre,
              hint: const Text('Genre'),
              underline: const SizedBox.shrink(),
              items: [
                const DropdownMenuItem(value: null, child: Text('All genres')),
                ...genres.map(
                  (g) => DropdownMenuItem(value: g, child: Text(g)),
                ),
              ],
              onChanged: (v) => setState(() => _selectedGenre = v),
            ),
            const SizedBox(width: 12),
            DropdownButton<int?>(
              value: _selectedYear,
              hint: const Text('Year'),
              underline: const SizedBox.shrink(),
              items: [
                const DropdownMenuItem(value: null, child: Text('All years')),
                ...years.map(
                  (y) => DropdownMenuItem(value: y, child: Text('$y')),
                ),
              ],
              onChanged: (v) => setState(() => _selectedYear = v),
            ),
            const SizedBox(width: 12),
            DropdownButton<double?>(
              value: _minRating,
              hint: const Text('Rating'),
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: null, child: Text('Any rating')),
                DropdownMenuItem(value: 9.0, child: Text('9+')),
                DropdownMenuItem(value: 8.0, child: Text('8+')),
                DropdownMenuItem(value: 7.0, child: Text('7+')),
                DropdownMenuItem(value: 6.0, child: Text('6+')),
                DropdownMenuItem(value: 5.0, child: Text('5+')),
              ],
              onChanged: (v) => setState(() => _minRating = v),
            ),
            if (hasActiveFilters) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() {
                  _selectedGenre = null;
                  _selectedYear = null;
                  _minRating = null;
                }),
                child: const Text('Clear'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String title, String subtitle, VoidCallback onAdd) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.video_library_outlined,
              size: 56, color: Colors.white24),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add Folder'),
          ),
        ],
      ),
    );
  }
}
