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
    required this.rating,
    required this.genres,
    required this.watched,
    required this.isFavorite,
    required this.dateAdded,
    required this.onTap,
  });
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

void sortMediaItems(List<MediaItem> items, SortOption option) {
  switch (option) {
    case SortOption.titleAsc:
      items.sort((a, b) => a.title.compareTo(b.title));
      break;
    case SortOption.titleDesc:
      items.sort((a, b) => b.title.compareTo(a.title));
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
