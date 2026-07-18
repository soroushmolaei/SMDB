import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../widgets/media_grid.dart';
import '../widgets/media_item.dart';
import 'movie_detail_screen.dart';
import 'show_detail_screen.dart';

class MpaListScreen extends ConsumerWidget {
  const MpaListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moviesAsync = ref.watch(moviesStreamProvider);
    final shows = ref.watch(showsStreamProvider).value ?? [];

    return moviesAsync.when(
      data: (movies) {
        final counts = <String, int>{};
        for (final m in movies) {
          final rating = m.contentRating;
          if (rating == null || rating.isEmpty) continue;
          counts[rating] = (counts[rating] ?? 0) + 1;
        }
        for (final s in shows) {
          final rating = s.contentRating;
          if (rating == null || rating.isEmpty) continue;
          counts[rating] = (counts[rating] ?? 0) + 1;
        }
        final ratings = counts.keys.toList()..sort();

        if (ratings.isEmpty) {
          return const Center(
            child: Text(
              'No content ratings yet — scan a movie or show folder first.',
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
          itemCount: ratings.length,
          itemBuilder: (context, index) {
            final rating = ratings[index];
            return Card(
              color: Colors.white.withOpacity(0.05),
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MpaMoviesScreen(rating: rating),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined,
                          color: Color(0xFF9C91F5)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          rating,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        '${counts[rating]}',
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

class MpaMoviesScreen extends ConsumerStatefulWidget {
  final String rating;
  const MpaMoviesScreen({super.key, required this.rating});

  @override
  ConsumerState<MpaMoviesScreen> createState() => _MpaMoviesScreenState();
}

class _MpaMoviesScreenState extends ConsumerState<MpaMoviesScreen> {
  SortOption _sort = SortOption.titleAsc;

  @override
  Widget build(BuildContext context) {
    final moviesAsync = ref.watch(moviesStreamProvider);
    final shows = ref.watch(showsStreamProvider).value ?? [];

    return Scaffold(
      appBar: AppBar(title: Text(widget.rating)),
      body: moviesAsync.when(
        data: (movies) {
          final items = <MediaItem>[
            ...movies
                .where((m) => m.contentRating == widget.rating)
                .map((m) => MediaItem(
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
            ...shows
                .where((s) => s.contentRating == widget.rating)
                .map((s) => MediaItem(
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
                  emptyTitle: 'No movies or shows with this rating',
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
