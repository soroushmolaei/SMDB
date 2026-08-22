import 'dart:io';

import 'package:path/path.dart' as p;

const Set<String> videoExtensions = {
  '.mp4',
  '.mkv',
  '.avi',
  '.mov',
  '.wmv',
  '.flv',
  '.m4v',
  '.ts',
  '.webm',
};

bool isVideoFile(String path) {
  return videoExtensions.contains(p.extension(path).toLowerCase());
}

// ---------------------------------------------------------------------------
// Name parsing
// ---------------------------------------------------------------------------

class ParsedName {
  final String title;
  final int? year;
  ParsedName(this.title, this.year);
}

/// Extracts a clean title and an optional release year from a raw folder or
/// file name, e.g. "The.Matrix.1999.1080p.BluRay" -> ("The Matrix", 1999).
ParsedName parseTitleAndYear(String rawName) {
  var name = rawName.replaceAll(RegExp(r'[._]'), ' ');

  final yearMatch = RegExp(r'[\(\[]?((19|20)\d{2})[\)\]]?').firstMatch(name);

  String title;
  int? year;

  if (yearMatch != null) {
    year = int.tryParse(yearMatch.group(1)!);
    title = name.substring(0, yearMatch.start);
  } else {
    title = name;
  }

  title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
  title = title.replaceAll(RegExp(r'[-\s]+$'), '').trim();

  if (title.isEmpty) title = rawName.trim();

  return ParsedName(title, year);
}

class ParsedEpisode {
  final int season;
  final int episode;
  ParsedEpisode(this.season, this.episode);
}

/// Extracts season/episode numbers from a name using common conventions:
/// "S01E02", "s1e2", or "1x02".
ParsedEpisode? parseSeasonEpisode(String name) {
  final seMatch = RegExp(r'[Ss](\d{1,2})[ ._-]?[Ee](\d{1,3})').firstMatch(name);
  if (seMatch != null) {
    return ParsedEpisode(
      int.parse(seMatch.group(1)!),
      int.parse(seMatch.group(2)!),
    );
  }
  final xMatch = RegExp(r'(?<!\d)(\d{1,2})x(\d{2,3})(?!\d)').firstMatch(name);
  if (xMatch != null) {
    return ParsedEpisode(
      int.parse(xMatch.group(1)!),
      int.parse(xMatch.group(2)!),
    );
  }
  return null;
}

class ParsedShowEpisode {
  final String title;
  final int season;
  final int episode;
  ParsedShowEpisode(this.title, this.season, this.episode);
}

/// Extracts a show title together with its season/episode numbers from a
/// single episode file name, e.g. "24 S01E01" -> ("24", 1, 1), or
/// "Breaking Bad - S01E05 - Gray Matter" -> ("Breaking Bad", 1, 5), with
/// the trailing per-episode subtitle ignored. Everything before the
/// season/episode marker is taken as the title, so this only works when
/// the file name itself starts with the show's name -- which is the
/// standard convention this app expects episode files to follow. Returns
/// null if no season/episode marker is found at all, or if nothing is
/// left before it to use as a title.
ParsedShowEpisode? parseShowTitleAndEpisode(String rawName) {
  final name = rawName.replaceAll(RegExp(r'[._]'), ' ');

  final seMatch = RegExp(r'[Ss](\d{1,2})[ ._-]?[Ee](\d{1,3})').firstMatch(name);
  final match = seMatch ??
      RegExp(r'(?<!\d)(\d{1,2})x(\d{2,3})(?!\d)').firstMatch(name);
  if (match == null) return null;

  var title = name.substring(0, match.start);
  title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
  title = title.replaceAll(RegExp(r'[-\s]+$'), '').trim();
  if (title.isEmpty) return null;

  return ParsedShowEpisode(
    title,
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
  );
}

// ---------------------------------------------------------------------------
// Scan results
// ---------------------------------------------------------------------------

class ScannedMovie {
  final String title;
  final int? year;
  final String filePath;
  final String? trailerFilePath;
  final String folderPath;
  ScannedMovie({
    required this.title,
    required this.year,
    required this.filePath,
    this.trailerFilePath,
    required this.folderPath,
  });
}

class ScannedEpisode {
  final int season;
  final int episode;
  final String filePath;
  ScannedEpisode({
    required this.season,
    required this.episode,
    required this.filePath,
  });
}

class ScannedShow {
  final String title;
  final String folderPath;
  final List<ScannedEpisode> episodes;
  ScannedShow({
    required this.title,
    required this.folderPath,
    required this.episodes,
  });
}

class _ShowAccumulator {
  final String title;
  final List<ScannedEpisode> episodes = [];
  _ShowAccumulator(this.title);
}

// ---------------------------------------------------------------------------
// Scanner
// ---------------------------------------------------------------------------

class LibraryScanner {
  /// Scans [rootPath] recursively, at any folder depth, for video files.
  /// Each qualifying file becomes its own movie, with the title and year
  /// parsed from the file's own name -- not any parent folder -- so how
  /// the files happen to be organized into subfolders (one folder per
  /// movie, movies grouped by genre, loose files, or anything else)
  /// doesn't matter.
  static Future<List<ScannedMovie>> scanMovies(
    String rootPath, {
    Set<String> excludedPaths = const {},
  }) async {
    final root = Directory(rootPath);
    if (!await root.exists()) return [];

    final found = <ScannedMovie>[];
    // Caches the trailer lookup per folder so a folder holding more than
    // one movie file isn't re-listed once per movie found in it.
    final trailerCache = <String, String?>{};

    await for (final entity
        in root.list(recursive: true, followLinks: false)) {
      if (entity is! File || !isVideoFile(entity.path)) continue;
      if (excludedPaths.contains(entity.path)) continue;
      final nameNoExt = p.basenameWithoutExtension(entity.path);
      if (_looksLikeTrailer(nameNoExt)) continue;

      final parsed = parseTitleAndYear(nameNoExt);
      final folder = p.dirname(entity.path);
      if (!trailerCache.containsKey(folder)) {
        trailerCache[folder] = await findTrailerInFolder(folder, entity.path);
      }

      found.add(ScannedMovie(
        title: parsed.title,
        year: parsed.year,
        filePath: entity.path,
        trailerFilePath: trailerCache[folder],
        folderPath: folder,
      ));
    }
    return found;
  }

  static bool _looksLikeTrailer(String fileName) {
    return RegExp(r'\btrailer\b', caseSensitive: false).hasMatch(fileName);
  }

  /// Scans [rootPath] recursively, at any folder depth, for episode video
  /// files. The show title, season, and episode number are all parsed
  /// from each file's own name (e.g. "24 S01E01.mkv" -> show "24",
  /// S01E01) -- never a parent folder -- so episodes are grouped into the
  /// same show by that title regardless of how they're organized into
  /// subfolders (one folder per season, everything loose, or anything
  /// else). A file whose name has no recognizable season/episode marker
  /// is skipped rather than guessed at.
  static Future<List<ScannedShow>> scanShows(
    String rootPath, {
    Set<String> excludedPaths = const {},
  }) async {
    final root = Directory(rootPath);
    if (!await root.exists()) return [];

    // Keyed by a normalized (trimmed, lowercased) title so e.g. "24" and
    // " 24 " group together; the first-seen casing is kept as the title
    // shown to the user.
    final byKey = <String, _ShowAccumulator>{};

    await for (final entity
        in root.list(recursive: true, followLinks: false)) {
      if (entity is! File || !isVideoFile(entity.path)) continue;
      if (excludedPaths.contains(entity.path)) continue;
      final parsed =
          parseShowTitleAndEpisode(p.basenameWithoutExtension(entity.path));
      if (parsed == null) continue;

      final key = parsed.title.toLowerCase();
      final acc = byKey.putIfAbsent(key, () => _ShowAccumulator(parsed.title));
      acc.episodes.add(ScannedEpisode(
        season: parsed.season,
        episode: parsed.episode,
        filePath: entity.path,
      ));
    }

    return byKey.values
        .map((acc) => ScannedShow(
              title: acc.title,
              folderPath: _commonAncestorFolder(
                acc.episodes.map((e) => e.filePath).toList(),
              ),
              episodes: acc.episodes,
            ))
        .toList();
  }

  /// The deepest folder that contains every one of [filePaths]. Used as a
  /// show's stored folder path when its episodes are parsed from
  /// filenames rather than assumed to share one dedicated folder --
  /// display-only (e.g. shown in Settings), not a dedup key, since a
  /// show's identity now comes from its title.
  static String _commonAncestorFolder(List<String> filePaths) {
    if (filePaths.isEmpty) return '';
    var common = p.dirname(filePaths.first).split(p.separator);
    for (final path in filePaths.skip(1)) {
      final parts = p.dirname(path).split(p.separator);
      var i = 0;
      while (i < common.length && i < parts.length && common[i] == parts[i]) {
        i++;
      }
      if (i < common.length) common = common.sublist(0, i);
    }
    return common.join(p.separator);
  }

  /// Looks for a trailer-named video file anywhere under [folderPath]
  /// (recursively, e.g. a "Trailers" subfolder inside the movie's own
  /// folder), excluding [mainFilePath] itself. [folderPath] is always the
  /// movie's own specific folder -- never a shared parent like a "2008"
  /// category folder above it -- so this can't cross into a different
  /// movie's files. Used both by [scanMovies] and by the per-item
  /// "Update" action, so a trailer added after the initial scan can be
  /// picked up without re-scanning the whole library folder.
  static Future<String?> findTrailerInFolder(
    String folderPath,
    String mainFilePath,
  ) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return null;
    await for (final entity
        in dir.list(recursive: true, followLinks: false)) {
      if (entity is File &&
          entity.path != mainFilePath &&
          isVideoFile(entity.path)) {
        final name = p.basenameWithoutExtension(entity.path);
        if (_looksLikeTrailer(name)) return entity.path;
      }
    }
    return null;
  }
}
