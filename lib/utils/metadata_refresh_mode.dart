/// The three ways a "refresh metadata" action can touch an already-scanned
/// movie, show, or person: everything, everything except the visual
/// asset(s), or only the visual asset(s). Used both for the single-item
/// refresh button on detail screens and for bulk refresh from multi-select
/// on list pages.
enum MetadataRefreshMode { full, skipImages, imagesOnly }

extension MetadataRefreshModeLabel on MetadataRefreshMode {
  /// [imageLabel] names whatever visual asset(s) this mode controls --
  /// "poster & backdrop" for movies/shows, "photo" for people.
  String label({String imageLabel = 'poster & backdrop'}) {
    switch (this) {
      case MetadataRefreshMode.full:
        return 'Refresh all metadata';
      case MetadataRefreshMode.skipImages:
        return 'Refresh all without $imageLabel';
      case MetadataRefreshMode.imagesOnly:
        return 'Refresh only $imageLabel';
    }
  }
}
