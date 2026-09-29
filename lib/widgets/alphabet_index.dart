import 'package:flutter/material.dart';

import 'media_item.dart';

/// Whether [text] belongs under [letter] in the A-Z index. A null [letter]
/// means "no filter" and matches everything; '#' matches anything whose
/// first (sortable) character isn't a-z (digits, Persian titles, ...).
/// Leading [exclusionWords] ("The", "A", ...) are skipped first, exactly
/// like the alphabetical sort does, so "The Matrix" lands under M.
bool matchesLetter(
  String text,
  String? letter,
  List<String> exclusionWords,
) {
  if (letter == null) return true;
  final sortable = sortableTitle(text, exclusionWords);
  final first = sortable.isEmpty ? '#' : sortable[0].toLowerCase();
  if (letter == '#') return !RegExp(r'[a-z]').hasMatch(first);
  return first == letter;
}

/// The narrow vertical A-Z strip shown beside a list. Tapping a letter
/// selects it; tapping the selected letter again clears the filter.
class AlphabetIndex extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelect;
  const AlphabetIndex({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    const letters = [
      'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', //
      'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', '#',
    ];
    return Container(
      width: 26,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        children: letters.map((l) {
          final isSelected = selected == l;
          return InkWell(
            onTap: () => onSelect(isSelected ? null : l),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 3),
              color: isSelected
                  ? const Color(0xFF6C5CE7).withValues(alpha: 0.3)
                  : null,
              alignment: Alignment.center,
              child: Text(
                l,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? Colors.white : Colors.white38,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Puts an [AlphabetIndex] beside whatever [builder] returns and owns the
/// selected-letter state, so a screen only has to filter by the `letter`
/// it is handed.
class LetterIndexed extends StatefulWidget {
  final Widget Function(BuildContext context, String? letter) builder;
  const LetterIndexed({super.key, required this.builder});

  @override
  State<LetterIndexed> createState() => _LetterIndexedState();
}

class _LetterIndexedState extends State<LetterIndexed> {
  String? _letter;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AlphabetIndex(
          selected: _letter,
          onSelect: (l) => setState(() => _letter = l),
        ),
        Expanded(child: widget.builder(context, _letter)),
      ],
    );
  }
}
