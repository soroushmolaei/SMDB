import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../widgets/media_grid.dart';
import '../widgets/media_item.dart';
import 'movie_detail_screen.dart';
import 'show_detail_screen.dart';

class GenresListScreen extends ConsumerWidget {
  const GenresListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moviesAsync = ref.watch(moviesStreamProvider);
    final shows = ref.watch(showsStreamProvider).value ?? [];

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

        return GridView.builder(
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
            return Card(
              color: Colors.white.withOpacity(0.05),
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GenreDetailScreen(genre: genre),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.local_offer_outlined,
                          color: Color(0xFF9C91F5)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          genre,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        '${counts[genre]}',
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

class GenreDetailScreen extends ConsumerStatefulWidget {
  final String genre;
  const GenreDetailScreen({super.key, required this.genre});

  @override
  ConsumerState<GenreDetailScreen> createState() => _GenreDetailScreenState();
}

class _GenreDetailScreenState extends ConsumerState<GenreDetailScreen> {
  SortOption _sort = SortOption.titleAsc;

  @override
  Widget build(BuildContext context) {
    final moviesAsync = ref.watch(moviesStreamProvider);
    final shows = ref.watch(showsStreamProvider).value ?? [];

    return Scaffold(
      appBar: AppBar(title: Text(widget.genre)),
      body: moviesAsync.when(
        data: (movies) {
          bool hasGenre(String? raw) => (raw ?? '')
              .split(',')
              .map((g) => g.trim())
              .contains(widget.genre);

          final items = <MediaItem>[
            ...movies.where((m) => hasGenre(m.genres)).map((m) => MediaItem(
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
                )),
            ...shows.where((s) => hasGenre(s.genres)).map((s) => MediaItem(
                  kind: 'show',
                  id: s.id,
                  title: s.title,
                  year: null,
                  posterPath: s.posterPath,
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
              SortFilterBar(
                sort: _sort,
                onSortChanged: (s) => setState(() => _sort = s),
              ),
              Expanded(
                child: MediaItemView(
                  items: items,
                  gridView: true,
                  emptyTitle: 'No movies or shows in this genre',
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
