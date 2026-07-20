import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../providers/providers.dart';

/// Shows a movie/show's awards (Won/Nominated), fetched lazily from
/// Wikidata the first time this widget is built for a given item, then
/// cached in the local database. Renders nothing if there's no IMDb id to
/// look up, or if the lookup finds no award data (most titles won't have
/// any tracked on Wikidata — that's normal, not an error).
class AwardsSection extends ConsumerStatefulWidget {
  final String itemType; // 'movie' or 'show'
  final int itemId;
  final String? imdbId;

  const AwardsSection({
    super.key,
    required this.itemType,
    required this.itemId,
    required this.imdbId,
  });

  @override
  ConsumerState<AwardsSection> createState() => _AwardsSectionState();
}

class _AwardsSectionState extends ConsumerState<AwardsSection> {
  bool _fetchTriggered = false;
  bool _fetching = false;

  Future<void> _maybeFetch() async {
    if (_fetchTriggered || widget.imdbId == null) return;
    final db = ref.read(databaseProvider);
    final already = await db.hasAwardsFetched(widget.itemType, widget.itemId);
    if (already) return;
    _fetchTriggered = true;
    if (mounted) setState(() => _fetching = true);

    try {
      final wikidata = ref.read(wikidataServiceProvider);
      final results = await wikidata.getAwardsByImdbId(widget.imdbId!);
      await db.setAwardsFor(
        widget.itemType,
        widget.itemId,
        results
            .map((r) => AwardInput(
                  name: r.name,
                  result: r.result,
                  year: r.year,
                ))
            .toList(),
      );
      await db.markAwardsChecked(widget.itemType, widget.itemId);
    } catch (_) {
      // Awards are a nice-to-have; fail silently.
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imdbId == null) return const SizedBox.shrink();
    _maybeFetch();

    final awardsAsync =
        ref.watch(awardsProvider((widget.itemType, widget.itemId)));

    return awardsAsync.when(
      data: (awards) {
        if (awards.isEmpty) {
          if (_fetching) {
            return const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Checking Wikidata for awards…',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        }

        final won = awards.where((a) => a.result == 'Won').toList();
        final nominated =
            awards.where((a) => a.result != 'Won').toList();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AWARDS',
                style: TextStyle(fontSize: 12, color: Colors.white38),
              ),
              const SizedBox(height: 6),
              ...won.map((a) => _AwardRow(award: a, won: true)),
              ...nominated.map((a) => _AwardRow(award: a, won: false)),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
    );
  }
}

class _AwardRow extends StatelessWidget {
  final Award award;
  final bool won;
  const _AwardRow({required this.award, required this.won});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            won ? Icons.emoji_events : Icons.emoji_events_outlined,
            size: 16,
            color: won ? Colors.amber : Colors.white38,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: won ? 'Won: ' : 'Nominated: ',
                    style: TextStyle(
                      color: won ? Colors.amber : Colors.white54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: award.year != null
                        ? '${award.name} (${award.year})'
                        : award.name,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
