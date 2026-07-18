import 'package:flutter/material.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters =
        selectedGenre != null || selectedYear != null || minRating != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
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
                hint: const Text('Genre', style: TextStyle(fontSize: 13)),
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
                hint: const Text('Year', style: TextStyle(fontSize: 13)),
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
                hint: const Text('Rating', style: TextStyle(fontSize: 13)),
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Any rating')),
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
    );
  }
}

/// Renders a list of [MediaItem]s as either a poster grid or a compact
/// list, with a consistent empty state.
class MediaItemView extends StatelessWidget {
  final List<MediaItem> items;
  final bool gridView;
  final String emptyTitle;
  final String emptySubtitle;

  const MediaItemView({
    super.key,
    required this.items,
    required this.gridView,
    this.emptyTitle = 'Nothing here yet',
    this.emptySubtitle = '',
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
          return ListTile(
            leading: SizedBox(
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
            onTap: item.onTap,
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
        return PosterCard(
          title: item.title,
          posterUrl: item.posterPath,
          watched: item.watched,
          onTap: item.onTap,
        );
      },
    );
  }
}
