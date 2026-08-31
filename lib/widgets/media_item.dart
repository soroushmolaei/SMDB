import 'dart:typed_data';

import 'package:flutter/material.dart';

/// A unified, display-ready representation of either a movie or a show,
/// so grids/lists/sorting/filtering code can be written once and used
/// everywhere (Movies, Shows, Favorites, Latest Additions, Watched, Genre
/// and MPA drill-downs, custom Collections, etc).
class MediaItem {
  final String kind; // 'movie' or 'show'
  final int id;
  final String title;
  final int? year;
  final String? posterPath;
  final Uint8List? posterThumbnail;
  final double? rating;
  final String? genres;
  final bool watched;
  final bool isFavorite;
  final DateTime dateAdded;
  final VoidCallback onTap;

  MediaItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.year,
    required this.posterPath,
    this.posterThumbnail,
    required this.rating,
    required this.genres,
    required this.watched,
    required this.isFavorite,
    required this.dateAdded,
    required this.onTap,
  });

  /// Unique key for multi-select tracking -- movie and show ids share the
  /// same integer space, so the kind must be part of the key.
  String get selectionKey => '$kind:$id';
}

enum SortOption {
  titleAsc,
  titleDesc,
  yearNewest,
  yearOldest,
  ratingHigh,
  ratingLow,
  dateAddedNewest,
  dateAddedOldest,
}

extension SortOptionLabel on SortOption {
  String get label {
    switch (this) {
      case SortOption.titleAsc:
        return 'Title (A-Z)';
      case SortOption.titleDesc:
        return 'Title (Z-A)';
      case SortOption.yearNewest:
        return 'Year (newest)';
      case SortOption.yearOldest:
        return 'Year (oldest)';
      case SortOption.ratingHigh:
        return 'Rating (high-low)';
      case SortOption.ratingLow:
        return 'Rating (low-high)';
      case SortOption.dateAddedNewest:
        return 'Date added (newest)';
      case SortOption.dateAddedOldest:
        return 'Date added (oldest)';
    }
  }
}

/// Strips a single leading word from [title] if it case-insensitively
/// matches one of [exclusionWords] followed by a space (e.g. "The Matrix"
/// -> "Matrix" when "The" is excluded, but "Apple" is untouched even if
/// "A" is excluded, since "A" isn't followed by a space there). Returns
/// [title] unchanged if no leading word matches. Used for both sorting
/// and the A-Z alphabet index, so "The Matrix" sorts and groups under M
/// the way library catalogs conventionally do.
String sortableTitle(String title, List<String> exclusionWords) {
  if (exclusionWords.isEmpty) return title;
  for (final word in exclusionWords) {
    if (word.isEmpty) continue;
    final prefix = '$word ';
    if (title.length > prefix.length &&
        title.substring(0, prefix.length).toLowerCase() ==
            prefix.toLowerCase()) {
      return title.substring(prefix.length);
    }
  }
  return title;
}

void sortMediaItems(
  List<MediaItem> items,
  SortOption option, {
  List<String> exclusionWords = const [],
}) {
  switch (option) {
    case SortOption.titleAsc:
      items.sort((a, b) => sortableTitle(a.title, exclusionWords)
          .compareTo(sortableTitle(b.title, exclusionWords)));
      break;
    case SortOption.titleDesc:
      items.sort((a, b) => sortableTitle(b.title, exclusionWords)
          .compareTo(sortableTitle(a.title, exclusionWords)));
      break;
    case SortOption.yearNewest:
      items.sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
      break;
    case SortOption.yearOldest:
      items.sort((a, b) => (a.year ?? 9999).compareTo(b.year ?? 9999));
      break;
    case SortOption.ratingHigh:
      items.sort((a, b) => (b.rating ?? -1).compareTo(a.rating ?? -1));
      break;
    case SortOption.ratingLow:
      items.sort((a, b) => (a.rating ?? 999).compareTo(b.rating ?? 999));
      break;
    case SortOption.dateAddedNewest:
      items.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      break;
    case SortOption.dateAddedOldest:
      items.sort((a, b) => a.dateAdded.compareTo(b.dateAdded));
      break;
  }
}
