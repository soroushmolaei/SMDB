import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import 'person_detail_screen.dart';

class PeopleTab extends ConsumerStatefulWidget {
  const PeopleTab({super.key});

  @override
  ConsumerState<PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends ConsumerState<PeopleTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final peopleAsync = ref.watch(peopleStreamProvider);
    final creditsAsync = ref.watch(allCreditsStreamProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search people...',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
          ),
        ),
        Expanded(
          child: peopleAsync.when(
            data: (people) {
              final filtered = _query.isEmpty
                  ? people
                  : people
                      .where((p) => p.name.toLowerCase().contains(_query))
                      .toList()
                ..sort((a, b) => a.name.compareTo(b.name));

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_outline,
                          size: 56, color: Colors.white24),
                      const SizedBox(height: 12),
                      Text(
                        people.isEmpty ? 'No people yet' : 'No matches',
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Scan a movie folder with a TMDB or OMDb key set '
                        'to populate cast and crew.',
                        style: TextStyle(color: Colors.white54),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return creditsAsync.when(
                data: (allCredits) {
                  final roleByPerson = <int, Set<String>>{};
                  final countByPerson = <int, int>{};
                  for (final c in allCredits) {
                    roleByPerson.putIfAbsent(c.personId, () => {}).add(c.role);
                    countByPerson[c.personId] =
                        (countByPerson[c.personId] ?? 0) + 1;
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 110,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final person = filtered[index];
                      final roles = roleByPerson[person.id] ?? {};
                      final roleLabel = _summarizeRoles(roles);
                      final count = countByPerson[person.id] ?? 0;
                      return InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                PersonDetailScreen(personId: person.id),
                          ),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: Colors.white10,
                              backgroundImage: person.photoPath != null
                                  ? CachedNetworkImageProvider(
                                      person.photoPath!)
                                  : null,
                              child: person.photoPath == null
                                  ? const Icon(Icons.person,
                                      color: Colors.white38, size: 32)
                                  : null,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              person.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              count > 0 ? '$roleLabel · $count' : roleLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white38,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error: $e')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  String _summarizeRoles(Set<String> roles) {
    if (roles.contains('director') && roles.contains('actor')) {
      return 'Director/Actor';
    }
    if (roles.contains('director')) return 'Director';
    if (roles.contains('writer')) return 'Writer';
    if (roles.contains('actor')) return 'Actor';
    return '';
  }
}
