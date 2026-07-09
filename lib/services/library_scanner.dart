import 'dart:io';

import 'package:path/path.dart' as p;

const Set<String> _videoExtensions = {
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
  return _videoExtensions.contains(p.extension(path).toLowerCase());
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

// ---------------------------------------------------------------------------
// Scan results
// ---------------------------------------------------------------------------

class ScannedMovie {
  final String title;
  final int? year;
  final String filePath;
  final String folderPath;
  ScannedMovie({
    required this.title,
    required this.year,
    required this.filePath,
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

// ---------------------------------------------------------------------------
// Scanner
// ---------------------------------------------------------------------------

class LibraryScanner {
  /// Scans [rootPath] for movies. Supports both:
  ///  - one subfolder per movie, e.g. "The Matrix (1999)/The Matrix.mkv"
  ///  - loose video files directly inside [rootPath]
  static Future<List<ScannedMovie>> scanMovies(String rootPath) async {
    final root = Directory(rootPath);
    if (!await root.exists()) return [];

    final found = <ScannedMovie>[];

    await for (final entity in root.list(followLinks: false)) {
      if (entity is Directory) {
        final videoFile = await _largestVideoFile(entity);
        if (videoFile == null) continue;
        final parsed = parseTitleAndYear(p.basename(entity.path));
        found.add(ScannedMovie(
          title: parsed.title,
          year: parsed.year,
          filePath: videoFile.path,
          folderPath: entity.path,
        ));
      } else if (entity is File && isVideoFile(entity.path)) {
        final parsed =
            parseTitleAndYear(p.basenameWithoutExtension(entity.path));
        found.add(ScannedMovie(
          title: parsed.title,
          year: parsed.year,
          filePath: entity.path,
          folderPath: root.path,
        ));
      }
    }
    return found;
  }

  /// Scans [rootPath] for shows: one subfolder per show. Episodes may sit
  /// directly in the show folder or nested under "Season N" subfolders.
  static Future<List<ScannedShow>> scanShows(String rootPath) async {
    final root = Directory(rootPath);
    if (!await root.exists()) return [];

    final shows = <ScannedShow>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final episodes = await _scanShowEpisodes(entity);
      if (episodes.isEmpty) continue;
      shows.add(ScannedShow(
        title: parseTitleAndYear(p.basename(entity.path)).title,
        folderPath: entity.path,
        episodes: episodes,
      ));
    }
    return shows;
  }

  static Future<List<ScannedEpisode>> _scanShowEpisodes(
    Directory showDir,
  ) async {
    final episodes = <ScannedEpisode>[];
    await for (final entity
        in showDir.list(recursive: true, followLinks: false)) {
      if (entity is! File || !isVideoFile(entity.path)) continue;
      final se = parseSeasonEpisode(p.basenameWithoutExtension(entity.path));
      if (se == null) continue;
      episodes.add(ScannedEpisode(
        season: se.season,
        episode: se.episode,
        filePath: entity.path,
      ));
    }
    return episodes;
  }

  static Future<File?> _largestVideoFile(Directory dir) async {
    File? largest;
    int largestSize = -1;
    await for (final entity
        in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && isVideoFile(entity.path)) {
        final size = await entity.length();
        if (size > largestSize) {
          largestSize = size;
          largest = entity;
        }
      }
    }
    return largest;
  }
}
