import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../widgets/media_grid.dart';
import '../widgets/media_item.dart';
import 'movie_detail_screen.dart';
import 'show_detail_screen.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final int collectionId;
  const GroupDetailScreen({super.key, required this.collectionId});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  SortOption _sort = SortOption.titleAsc;

  Future<void> _rename(String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename group'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (newName != null && newName.trim().isNotEmpty) {
      await ref
          .read(databaseProvider)
          .renameCollection(widget.collectionId, newName);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete group?'),
        content: const Text(
          'This only removes the group. Movies and shows themselves are '
          'not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(databaseProvider).deleteCollection(widget.collectionId);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final collectionsAsync = ref.watch(collectionsStreamProvider);
    final movieLinksAsync =
        ref.watch(collectionMovieLinksProvider(widget.collectionId));
    final showLinksAsync =
        ref.watch(collectionShowLinksProvider(widget.collectionId));
    final moviesAsync = ref.watch(moviesStreamProvider);
    final showsAsync = ref.watch(showsStreamProvider);

    return collectionsAsync.when(
      data: (collections) {
        final matches =
            collections.where((c) => c.id == widget.collectionId);
        final name = matches.isEmpty ? 'Group' : matches.first.name;

        return Scaffold(
          appBar: AppBar(
            title: Text(name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Rename',
                onPressed: () => _rename(name),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete group',
                onPressed: _delete,
              ),
            ],
          ),
          body: Column(
            children: [
              SortFilterBar(
                sort: _sort,
                onSortChanged: (s) => setState(() => _sort = s),
              ),
              Expanded(
                child: movieLinksAsync.when(
                  data: (movieLinks) => showLinksAsync.when(
                    data: (showLinks) => moviesAsync.when(
                      data: (movies) => showsAsync.when(
                        data: (shows) {
                          final movieIds =
                              movieLinks.map((l) => l.movieId).toSet();
                          final showIds =
                              showLinks.map((l) => l.showId).toSet();

                          final items = <MediaItem>[
                            ...movies
                                .where((m) => movieIds.contains(m.id))
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
                                          builder: (_) => MovieDetailScreen(
                                              movieId: m.id),
                                        ),
                                      ),
                                    )),
                            ...shows
                                .where((s) => showIds.contains(s.id))
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
                                          builder: (_) =>
                                              ShowDetailScreen(showId: s.id),
                                        ),
                                      ),
                                    )),
                          ];
                          sortMediaItems(items, _sort);

                          return MediaItemView(
                            items: items,
                            gridView: true,
                            emptyTitle: 'Nothing in this group yet',
                            emptySubtitle: 'Add movies or shows to it from '
                                'their detail page.',
                          );
                        },
                        loading: () => const Center(
                            child: CircularProgressIndicator()),
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
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}
