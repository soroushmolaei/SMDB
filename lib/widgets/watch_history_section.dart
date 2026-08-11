import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/providers.dart';

/// Shows how many times a movie or episode has been watched and when,
/// with a way to log another watch (defaults to today, or pick a date to
/// backdate a forgotten rewatch) and to remove an entry logged by
/// mistake. A plain widget rather than a dialog itself, so it can be
/// embedded directly in the episode detail dialog (movies don't have an
/// equivalent existing dialog to embed it in -- see
/// [showWatchHistoryDialog] for those instead).
class WatchHistorySection extends ConsumerWidget {
  final String itemType; // 'movie' or 'episode'
  final int itemId;

  const WatchHistorySection({
    super.key,
    required this.itemType,
    required this.itemId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(watchHistoryProvider((itemType, itemId)));
    final mutedStyle =
        TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);

    return historyAsync.when(
      data: (events) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            events.isEmpty
                ? 'Not watched yet'
                : 'Watched ${events.length} '
                    '${events.length == 1 ? 'time' : 'times'}',
            style: mutedStyle,
          ),
          if (events.isNotEmpty) ...[
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final e = events[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child:
                              Text(DateFormat.yMMMd().format(e.watchedAt)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          tooltip: 'Remove this entry',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => ref
                              .read(databaseProvider)
                              .deleteWatchEvent(itemType, itemId, e.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: now,
                firstDate: DateTime(1900),
                lastDate: now,
              );
              if (picked != null) {
                await ref
                    .read(databaseProvider)
                    .logWatch(itemType, itemId, picked);
              }
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Log a watch'),
          ),
        ],
      ),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, st) => Text('Error: $e', style: mutedStyle),
    );
  }
}

/// Wraps [WatchHistorySection] in its own dialog -- used for movies,
/// which (unlike episodes) don't already have a detail dialog to embed
/// it in.
Future<void> showWatchHistoryDialog(
  BuildContext context, {
  required String itemType,
  required int itemId,
  required String title,
}) {
  return showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Watch history — $title'),
      content: SizedBox(
        width: 320,
        child: WatchHistorySection(itemType: itemType, itemId: itemId),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
