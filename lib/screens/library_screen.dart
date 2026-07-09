import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../services/tmdb_service.dart';
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
    final tmdbConfigured = ref.watch(tmdbServiceProvider) != null;

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
          if (!tmdbConfigured)
            Container(
              width: double.infinity,
              color: Colors.amber.shade800,
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Add a TMDB API key in Settings to fetch posters and details.',
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search your library...',
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
                    final filtered = _query.isEmpty
                        ? movies
                        : movies
                            .where((m) =>
                                m.title.toLowerCase().contains(_query))
                            .toList();
                    if (filtered.isEmpty) {
                      return _emptyState(
                        'No movies yet',
                        'Add a folder to scan your movie collection.',
                        () => _addAndScanFolder('movie'),
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
                        final movie = filtered[index];
                        return PosterCard(
                          title: movie.title,
                          posterUrl: TmdbService.imageUrl(movie.posterPath),
                          watched: movie.watched,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  MovieDetailScreen(movieId: movie.id),
                            ),
                          ),
                          onToggleWatched: () => ref
                              .read(databaseProvider)
                              .setMovieWatched(movie.id, !movie.watched),
                        );
                      },
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
                        : shows
                            .where((s) =>
                                s.title.toLowerCase().contains(_query))
                            .toList();
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
                          posterUrl: TmdbService.imageUrl(show.posterPath),
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
