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
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white38,
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
///
/// Uses Wrap rather than GridView: a GridView's row height has to be
/// derived from a fixed width/height ratio, which made rows far taller
/// than the avatar+text content actually needs on a wide desktop window.
/// Wrap just sizes each chip to its own natural height instead.
class CreditsGrid extends StatelessWidget {
  final List<CreditEntry> entries;
  final void Function(int personId) onTap;

  const CreditsGrid({super.key, required this.entries, required this.onTap});

  static const _crossAxisCount = 3;
  static const _spacing = 16.0;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth -
                  _spacing * (_crossAxisCount - 1)) /
              _crossAxisCount;
          return Wrap(
            spacing: _spacing,
            runSpacing: 10,
            children: [
              for (final e in entries)
                SizedBox(
                  width: itemWidth,
                  child: _CreditChip(entry: e, onTap: onTap),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CreditChip extends StatefulWidget {
  final CreditEntry entry;
  final void Function(int personId) onTap;

  const _CreditChip({required this.entry, required this.onTap});

  @override
  State<_CreditChip> createState() => _CreditChipState();
}

class _CreditChipState extends State<_CreditChip> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final clickable = e.personId != null;

    return InkWell(
      onTap: clickable ? () => widget.onTap(e.personId!) : null,
      onHover: clickable ? (h) => setState(() => _hovering = h) : null,
      borderRadius: BorderRadius.circular(8),
      hoverColor: Colors.white.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white24,
              backgroundImage: e.photoPath != null && e.photoPath!.isNotEmpty
                  ? smartImageProvider(e.photoPath!)
                  : null,
              child: e.photoPath == null || e.photoPath!.isEmpty
                  ? const Icon(Icons.person, size: 18, color: Colors.white54)
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
                      color: Colors.white,
                      decoration: clickable ? TextDecoration.underline : null,
                      decorationColor:
                          _hovering ? Colors.white : Colors.white54,
                      decorationThickness: _hovering ? 1.6 : 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    e.roleLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
