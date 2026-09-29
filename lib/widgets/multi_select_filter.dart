import 'package:flutter/material.dart';

/// A dropdown-style filter button that lets the user tick several options
/// at once. Shows [allLabel] when nothing is ticked, the option's own label
/// when exactly one is, and "[label] (N)" for more. Opens a dialog with a
/// checkbox per option (and a search box when [searchable], for long lists
/// like people); the new selection is reported once via [onChanged] when
/// the user taps Apply.
class MultiSelectFilter<T> extends StatelessWidget {
  final String label;
  final String allLabel;
  final List<T> options;
  final Set<T> selected;
  final String Function(T) labelOf;
  final ValueChanged<Set<T>> onChanged;
  final bool searchable;

  const MultiSelectFilter({
    super.key,
    required this.label,
    required this.allLabel,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.searchable = false,
  });

  String get _summary {
    if (selected.isEmpty) return allLabel;
    if (selected.length == 1) return labelOf(selected.first);
    return '$label (${selected.length})';
  }

  Future<void> _open(BuildContext context) async {
    final result = await showDialog<Set<T>>(
      context: context,
      builder: (_) => _MultiSelectDialog<T>(
        title: label,
        options: options,
        initial: selected,
        labelOf: labelOf,
        searchable: searchable,
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _summary,
              style: TextStyle(
                fontSize: 13,
                color: selected.isEmpty
                    ? null
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}

class _MultiSelectDialog<T> extends StatefulWidget {
  final String title;
  final List<T> options;
  final Set<T> initial;
  final String Function(T) labelOf;
  final bool searchable;

  const _MultiSelectDialog({
    required this.title,
    required this.options,
    required this.initial,
    required this.labelOf,
    required this.searchable,
  });

  @override
  State<_MultiSelectDialog<T>> createState() => _MultiSelectDialogState<T>();
}

class _MultiSelectDialogState<T> extends State<_MultiSelectDialog<T>> {
  late final Set<T> _picked = {...widget.initial};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final visible = widget.options
        .where((o) =>
            _query.isEmpty || widget.labelOf(o).toLowerCase().contains(_query))
        .toList();

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 360,
        height: 420,
        child: Column(
          children: [
            if (widget.searchable)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search...',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _query = v.toLowerCase()),
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final option = visible[index];
                  return CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _picked.contains(option),
                    title: Text(widget.labelOf(option)),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _picked.add(option);
                      } else {
                        _picked.remove(option);
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
          onPressed: () => setState(_picked.clear),
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_picked),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
