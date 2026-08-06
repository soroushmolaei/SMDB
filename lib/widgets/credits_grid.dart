import 'package:flutter/material.dart';

import 'smart_image.dart';

/// One person's entry in a [CreditsGrid] — their name plus a label
/// (their character for cast entries, or their role for crew).
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

/// A labelled section (e.g. "DIRECTOR", "WRITER", "CAST") containing a
/// [CreditsGrid]. Renders nothing if [entries] is empty, so sections can
/// be stacked unconditionally and empty ones just disappear.
class CreditsSection extends StatelessWidget {
  final String title;
  final List<CreditEntry> entries;
  final void Function(int personId) onTap;

  const CreditsSection({
    super.key,
    required this.title,
    required this.entries,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        CreditsGrid(entries: entries, onTap: onTap),
      ],
    );
  }
}

/// TMDB-style top-billed grid: avatar, bold name, muted role underneath,
/// three per row. Used below the hero on movie/show detail pages, one
/// per role via [CreditsSection].
class CreditsGrid extends StatelessWidget {
  final List<CreditEntry> entries;
  final void Function(int personId) onTap;

  const CreditsGrid({super.key, required this.entries, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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

/// Builds one [CreditEntry] per person for a single role's credits
/// (e.g. just the 'director' rows, or just the 'actor' rows) — a person
/// already seen in this subset isn't repeated. [labelOf] supplies the
/// second line (a character name for cast, or a fixed role name like
/// "Director" for crew).
List<CreditEntry> buildRoleEntries<C>({
  required Iterable<C> credits,
  required int Function(C) personIdOf,
  required String Function(C) labelOf,
  required String? Function(int personId) nameOf,
  required String? Function(int personId) photoPathOf,
}) {
  final seen = <int>{};
  final entries = <CreditEntry>[];
  for (final c in credits) {
    final personId = personIdOf(c);
    final name = nameOf(personId);
    if (name == null || seen.contains(personId)) continue;
    seen.add(personId);
    entries.add(CreditEntry(
      personId: personId,
      name: name,
      roleLabel: labelOf(c),
      photoPath: photoPathOf(personId),
    ));
  }
  return entries;
}
