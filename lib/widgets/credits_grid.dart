import 'package:flutter/material.dart';

import 'smart_image.dart';

/// One person's entry in a [CreditsGrid] — their name plus a combined
/// label of every role they held (e.g. a person who both wrote and
/// appeared in a movie shows as "Brenda, Writer" in one entry, rather
/// than appearing twice in separate cast/crew sections).
class CreditEntry {
  final int? personId;
  final String name;
  final String roleLabel;
  final String? photoPath;

  const CreditEntry({
    required this.personId,
    required this.name,
    required this.roleLabel,
    this.photoPath,
  });
}

/// TMDB-style top-billed grid: avatar, bold name, muted role underneath,
/// three per row, ordered by billing (first credit appearance in the
/// source list). Used below the hero on movie/show detail pages.
class CreditsGrid extends StatelessWidget {
  final List<CreditEntry> entries;
  final void Function(int personId) onTap;

  const CreditsGrid({super.key, required this.entries, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 14,
          childAspectRatio: 3.1,
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final e = entries[index];
          return InkWell(
            onTap: e.personId == null ? null : () => onTap(e.personId!),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  backgroundImage:
                      e.photoPath != null && e.photoPath!.isNotEmpty
                          ? smartImageProvider(e.photoPath!)
                          : null,
                  child: e.photoPath == null || e.photoPath!.isEmpty
                      ? Icon(Icons.person,
                          size: 18, color: colorScheme.onSurfaceVariant)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        e.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          decoration: e.personId == null
                              ? null
                              : TextDecoration.underline,
                          decorationColor: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        e.roleLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Groups movie/show credits by person, combining every role a person
/// held into one entry (e.g. actor + writer -> "Brenda, Writer"),
/// preserving first-appearance order from [credits].
List<CreditEntry> buildCreditEntries<C>({
  required Iterable<C> credits,
  required int Function(C) personIdOf,
  required String Function(C) roleOf,
  required String? Function(C) characterOf,
  required String? Function(int personId) nameOf,
  required String? Function(int personId) photoPathOf,
}) {
  final order = <int>[];
  final labelsByPerson = <int, List<String>>{};

  for (final c in credits) {
    final personId = personIdOf(c);
    if (nameOf(personId) == null) continue;
    if (!labelsByPerson.containsKey(personId)) {
      order.add(personId);
      labelsByPerson[personId] = [];
    }
    final role = roleOf(c);
    final character = characterOf(c);
    switch (role) {
      case 'actor':
        labelsByPerson[personId]!
            .add(character != null && character.isNotEmpty
                ? character
                : 'Actor');
        break;
      case 'director':
        labelsByPerson[personId]!.add('Director');
        break;
      case 'writer':
        labelsByPerson[personId]!.add('Writer');
        break;
      case 'creator':
        labelsByPerson[personId]!.add('Creator');
        break;
      default:
        labelsByPerson[personId]!.add(role);
    }
  }

  return order
      .map((id) => CreditEntry(
            personId: id,
            name: nameOf(id)!,
            roleLabel: labelsByPerson[id]!.join(', '),
            photoPath: photoPathOf(id),
          ))
      .toList();
}
