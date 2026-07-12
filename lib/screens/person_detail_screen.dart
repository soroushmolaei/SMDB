import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../providers/providers.dart';
import 'movie_detail_screen.dart';

class PersonDetailScreen extends ConsumerWidget {
  final int personId;
  const PersonDetailScreen({super.key, required this.personId});

  String _roleLabel(MovieCredit credit) {
    if (credit.role == 'actor' &&
        credit.character != null &&
        credit.character!.isNotEmpty) {
      return 'as ${credit.character}';
    }
    if (credit.role.isEmpty) return '';
    return credit.role[0].toUpperCase() + credit.role.substring(1);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peopleAsync = ref.watch(peopleStreamProvider);
    final creditsAsync = ref.watch(allCreditsStreamProvider);
    final moviesAsync = ref.watch(moviesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Person')),
      body: peopleAsync.when(
        data: (people) {
          final personMatches = people.where((p) => p.id == personId);
          if (personMatches.isEmpty) {
            return const Center(child: Text('Person not found'));
          }
          final person = personMatches.first;

          return creditsAsync.when(
            data: (allCredits) {
              final myCredits =
                  allCredits.where((c) => c.personId == personId).toList();

              return moviesAsync.when(
                data: (movies) {
                  final movieById = {for (final m in movies) m.id: m};
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.white10,
                            backgroundImage: person.photoPath != null
                                ? CachedNetworkImageProvider(
                                    person.photoPath!)
                                : null,
                            child: person.photoPath == null
                                ? const Icon(Icons.person,
                                    size: 40, color: Colors.white38)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              person.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Filmography (${myCredits.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (myCredits.isEmpty)
                        const Text(
                          'No linked movies.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ...myCredits.map((credit) {
                        final movie = movieById[credit.movieId];
                        if (movie == null) return const SizedBox.shrink();
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: SizedBox(
                            width: 40,
                            height: 56,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: movie.posterPath != null
                                  ? CachedNetworkImage(
                                      imageUrl: movie.posterPath!,
                                      fit: BoxFit.cover,
                                      errorWidget: (c, u, e) =>
                                          Container(color: Colors.white10),
                                    )
                                  : Container(
                                      color: Colors.white10,
                                      child: const Icon(
                                        Icons.movie_outlined,
                                        color: Colors.white24,
                                        size: 18,
                                      ),
                                    ),
                            ),
                          ),
                          title: Text(movie.title),
                          subtitle: Text(_roleLabel(credit)),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  MovieDetailScreen(movieId: movie.id),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error: $e')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
