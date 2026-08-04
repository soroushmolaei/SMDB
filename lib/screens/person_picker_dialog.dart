import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

/// Shows a dialog letting the user pick one or more OTHER people to find
/// shared filmography against [excludeId] (the person whose detail page
/// this was opened from). Returns the selected person ids, or null if the
/// dialog was cancelled without a selection.
Future<List<int>?> showPersonPickerDialog(
  BuildContext context,
  WidgetRef ref, {
  required int excludeId,
}) async {
  final db = ref.read(databaseProvider);
  final allPeople = await db.watchAllPeople().first;
  final candidates = allPeople.where((p) => p.id != excludeId).toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  if (!context.mounted) return null;

  // Declared here (not inside either builder below) so selections and the
  // search query survive dialog rebuilds triggered by setDialogState.
  final selected = <int>{};
  var query = '';

  return showDialog<List<int>>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final filtered = query.isEmpty
              ? candidates
              : candidates
                  .where((p) => p.name.toLowerCase().contains(query))
                  .toList();

          return AlertDialog(
            title: const Text('Find shared titles with...'),
            content: SizedBox(
              width: 340,
              height: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search people...',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) =>
                        setDialogState(() => query = v.toLowerCase()),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: candidates.isEmpty
                        ? const Center(
                            child: Text(
                              'No other people yet.',
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : filtered.isEmpty
                            ? const Center(
                                child: Text(
                                  'No matches.',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              )
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final person = filtered[index];
                                  final isSelected =
                                      selected.contains(person.id);
                                  return CheckboxListTile(
                                    dense: true,
                                    title: Text(person.name),
                                    value: isSelected,
                                    onChanged: (checked) =>
                                        setDialogState(() {
                                      if (checked ?? false) {
                                        selected.add(person.id);
                                      } else {
                                        selected.remove(person.id);
                                      }
                                    }),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: selected.isEmpty
                    ? null
                    : () =>
                        Navigator.of(dialogContext).pop(selected.toList()),
                child: Text(
                  selected.isEmpty
                      ? 'Select people'
                      : 'Find shared titles (${selected.length + 1})',
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
