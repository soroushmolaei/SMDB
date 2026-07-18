import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

/// Shows a dialog letting the user toggle which custom groups a movie or
/// show belongs to, and create a new group inline.
Future<void> showAddToGroupDialog(
  BuildContext context,
  WidgetRef ref, {
  required String kind, // 'movie' or 'show'
  required int itemId,
}) async {
  final db = ref.read(databaseProvider);
  final collections = await db.watchAllCollections().first;
  final membership = <int, bool>{};
  for (final c in collections) {
    membership[c.id] = kind == 'movie'
        ? await db.isMovieInCollection(c.id, itemId)
        : await db.isShowInCollection(c.id, itemId);
  }

  if (!context.mounted) return;

  await showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final newGroupController = TextEditingController();
          return AlertDialog(
            title: const Text('Add to group'),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (collections.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No groups yet — create one below.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ...collections.map((c) => CheckboxListTile(
                        title: Text(c.name),
                        value: membership[c.id] ?? false,
                        onChanged: (checked) async {
                          final isNowChecked = checked ?? false;
                          if (kind == 'movie') {
                            if (isNowChecked) {
                              await db.addMovieToCollection(c.id, itemId);
                            } else {
                              await db.removeMovieFromCollection(
                                  c.id, itemId);
                            }
                          } else {
                            if (isNowChecked) {
                              await db.addShowToCollection(c.id, itemId);
                            } else {
                              await db.removeShowFromCollection(c.id, itemId);
                            }
                          }
                          setDialogState(
                              () => membership[c.id] = isNowChecked);
                        },
                      )),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: newGroupController,
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'New group name',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () async {
                          final name = newGroupController.text.trim();
                          if (name.isEmpty) return;
                          final id = await db.createCollection(name);
                          if (kind == 'movie') {
                            await db.addMovieToCollection(id, itemId);
                          } else {
                            await db.addShowToCollection(id, itemId);
                          }
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Done'),
              ),
            ],
          );
        },
      );
    },
  );
}
