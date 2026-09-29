import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../widgets/alphabet_index.dart';
import '../widgets/poster_card.dart';
import 'show_detail_screen.dart';

class GenreShowsScreen extends ConsumerWidget {
  final String genre;
  const GenreShowsScreen({super.key, required this.genre});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showsAsync = ref.watch(showsStreamProvider);
    final exclusionWords = ref.watch(sortExclusionWordsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(genre)),
      body: LetterIndexed(
        builder: (context, letter) => showsAsync.when(
        data: (shows) {
          final filtered = shows.where((s) {
            final genres =
                (s.genres ?? '').split(',').map((g) => g.trim());
            return genres.contains(genre);
          }).toList();

          if (filtered.isEmpty) {
            return const Center(
              child: Text(
                'No shows in this genre',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          final shown = filtered
              .where((x) => matchesLetter(x.title, letter, exclusionWords))
              .toList();

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 150,
              childAspectRatio: 0.55,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: shown.length,
            itemBuilder: (context, index) {
              final show = shown[index];
              return PosterCard(
                title: show.title,
                posterUrl: show.posterPath,
                thumbnailBytes: show.posterThumbnail,
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
      ),
      ),
    );
  }
}
