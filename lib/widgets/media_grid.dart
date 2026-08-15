import 'package:flutter/material.dart';

import '../utils/metadata_refresh_mode.dart';
import 'media_item.dart';
import 'poster_card.dart';

/// A compact row of sort/filter dropdowns, reusable across any screen that
/// lists movies and/or shows.
class SortFilterBar extends StatelessWidget {
  final SortOption sort;
  final ValueChanged<SortOption> onSortChanged;
  final String? selectedGenre;
  final List<String> availableGenres;
  final ValueChanged<String?>? onGenreChanged;
  final int? selectedYear;
  final List<int> availableYears;
  final ValueChanged<int?>? onYearChanged;
  final double? minRating;
  final ValueChanged<double?>? onMinRatingChanged;
  final Widget? trailing;

  const SortFilterBar({
    super.key,
    required this.sort,
    required this.onSortChanged,
    this.selectedGenre,
    this.availableGenres = const [],
    this.onGenreChanged,
    this.selectedYear,
    this.availableYears = const [],
    this.onYearChanged,
    this.minRating,
    this.onMinRatingChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters =
        selectedGenre != null || selectedYear != null || minRating != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  DropdownButton<SortOption>(
                    value: sort,
                    underline: const SizedBox.shrink(),
                    icon: const Icon(Icons.sort, size: 16),
                    items: SortOption.values
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.label,
                                  style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) onSortChanged(v);
                    },
                  ),
                  if (onGenreChanged != null) ...[
                    const SizedBox(width: 12),
                    DropdownButton<String?>(
                      value: selectedGenre,
                      hint:
                          const Text('Genre', style: TextStyle(fontSize: 13)),
                      underline: const SizedBox.shrink(),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('All genres')),
                        ...availableGenres.map(
                          (g) => DropdownMenuItem(value: g, child: Text(g)),
                        ),
                      ],
                      onChanged: onGenreChanged,
                    ),
                  ],
                  if (onYearChanged != null) ...[
                    const SizedBox(width: 12),
                    DropdownButton<int?>(
                      value: selectedYear,
                      hint:
                          const Text('Year', style: TextStyle(fontSize: 13)),
                      underline: const SizedBox.shrink(),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('All years')),
                        ...availableYears.map(
                          (y) => DropdownMenuItem(value: y, child: Text('$y')),
                        ),
                      ],
                      onChanged: onYearChanged,
                    ),
                  ],
                  if (onMinRatingChanged != null) ...[
                    const SizedBox(width: 12),
                    DropdownButton<double?>(
                      value: minRating,
                      hint: const Text('Rating',
                          style: TextStyle(fontSize: 13)),
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                            value: null, child: Text('Any rating')),
                        DropdownMenuItem(value: 9.0, child: Text('9+')),
                        DropdownMenuItem(value: 8.0, child: Text('8+')),
                        DropdownMenuItem(value: 7.0, child: Text('7+')),
                        DropdownMenuItem(value: 6.0, child: Text('6+')),
                        DropdownMenuItem(value: 5.0, child: Text('5+')),
                      ],
                      onChanged: onMinRatingChanged,
                    ),
                  ],
                  if (hasActiveFilters) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        onGenreChanged?.call(null);
                        onYearChanged?.call(null);
                        onMinRatingChanged?.call(null);
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Renders a list of [MediaItem]s as either a poster grid or a compact
/// list, with a consistent empty state.
///
/// When [selectionMode] is on, tapping an item toggles its selection
/// (via [onToggleSelect]) instead of calling the item's own [MediaItem.onTap].
class MediaItemView extends StatelessWidget {
  final List<MediaItem> items;
  final bool gridView;
  final String emptyTitle;
  final String emptySubtitle;
  final bool selectionMode;
  final Set<String> selectedKeys;
  final ValueChanged<MediaItem>? onToggleSelect;

  const MediaItemView({
    super.key,
    required this.items,
    required this.gridView,
    this.emptyTitle = 'Nothing here yet',
    this.emptySubtitle = '',
    this.selectionMode = false,
    this.selectedKeys = const {},
    this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.video_library_outlined,
                size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            Text(emptyTitle, style: const TextStyle(fontSize: 16)),
            if (emptySubtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(emptySubtitle,
                  style: const TextStyle(color: Colors.white54)),
            ],
          ],
        ),
      );
    }

    if (!gridView) {
      return ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final selected = selectedKeys.contains(item.selectionKey);
          return ListTile(
            leading: selectionMode
                ? Icon(
                    selected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white38,
                  )
                : SizedBox(
                    width: 40,
                    child: item.posterPath != null
                        ? Image.network(item.posterPath!, fit: BoxFit.cover)
                        : Icon(item.kind == 'show'
                            ? Icons.tv_outlined
                            : Icons.movie_outlined),
                  ),
            title: Text(item.title),
            subtitle: Text([
              if (item.year != null) '${item.year}',
              if (item.genres != null) item.genres!,
            ].join(' • ')),
            trailing: item.rating != null
                ? Text(item.rating!.toStringAsFixed(1))
                : null,
            selected: selected,
            onTap: selectionMode
                ? () => onToggleSelect?.call(item)
                : item.onTap,
          );
        },
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        childAspectRatio: 0.55,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final selected = selectedKeys.contains(item.selectionKey);
        return PosterCard(
          title: item.title,
          posterUrl: item.posterPath,
          thumbnailBytes: item.posterThumbnail,
          watched: item.watched,
          selectionMode: selectionMode,
          selected: selected,
          onTap: selectionMode
              ? () => onToggleSelect?.call(item)
              : item.onTap,
        );
      },
    );
  }
}

/// The contextual toolbar shown once one or more items are selected:
/// selection count, Select All / Clear, the metadata-refresh mode menu,
/// and a Cancel button to exit selection mode entirely. Generic over
/// what's selected (movies/shows or people), so it's reused by both the
/// library grid sections and the People tab.
class SelectionActionBar extends StatelessWidget {
  final int selectedCount;
  final int totalCount;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final VoidCallback onCancel;
  final ValueChanged<MetadataRefreshMode> onRefresh;
  final String imageLabel;
  final bool busy;

  const SelectionActionBar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.onSelectAll,
    required this.onClear,
    required this.onCancel,
    required this.onRefresh,
    this.imageLabel = 'poster & backdrop',
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final allSelected = totalCount > 0 && selectedCount == totalCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
      child: Row(
        children: [
          Text(
            '$selectedCount selected',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: allSelected ? onClear : onSelectAll,
            child: Text(allSelected ? 'Clear' : 'Select All'),
          ),
          const Spacer(),
          if (busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            PopupMenuButton<MetadataRefreshMode>(
              enabled: selectedCount > 0,
              onSelected: onRefresh,
              itemBuilder: (context) => MetadataRefreshMode.values
                  .map(
                    (m) => PopupMenuItem(
                      value: m,
                      child: Text(
                        m.label(imageLabel: imageLabel),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  )
                  .toList(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.refresh,
                    size: 18,
                    color: selectedCount > 0
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white24,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Refresh Metadata',
                    style: TextStyle(
                      fontSize: 13,
                      color: selectedCount > 0
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white24,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cancel selection',
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}
