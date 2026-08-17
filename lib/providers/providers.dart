import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../database/database.dart';
import '../services/app_config_service.dart';
import '../services/library_scanner.dart';
import '../services/omdb_service.dart';
import '../services/thumbnail_service.dart';
import '../services/tmdb_service.dart';
import '../services/wikidata_service.dart';
import '../theme/app_theme.dart';
import '../utils/language_names.dart';
import '../utils/metadata_refresh_mode.dart';

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final moviesStreamProvider = StreamProvider<List<Movie>>((ref) {
  return ref.watch(databaseProvider).watchAllMovies();
});

final showsStreamProvider = StreamProvider<List<Show>>((ref) {
  return ref.watch(databaseProvider).watchAllShows();
});

final foldersStreamProvider = StreamProvider<List<LibraryFolder>>((ref) {
  return ref.watch(databaseProvider).watchAllFolders();
});

final peopleStreamProvider = StreamProvider<List<Person>>((ref) {
  return ref.watch(databaseProvider).watchAllPeople();
});

final allCreditsStreamProvider = StreamProvider<List<MovieCredit>>((ref) {
  return ref.watch(databaseProvider).watchAllCredits();
});

final allShowCreditsStreamProvider = StreamProvider<List<ShowCredit>>((ref) {
  return ref.watch(databaseProvider).watchAllShowCredits();
});

final collectionsStreamProvider = StreamProvider<List<Collection>>((ref) {
  return ref.watch(databaseProvider).watchAllCollections();
});

final allEpisodesStreamProvider = StreamProvider<List<Episode>>((ref) {
  return ref.watch(databaseProvider).watchAllEpisodes();
});

final collectionMovieLinksProvider =
    StreamProvider.family<List<CollectionMovie>, int>((ref, collectionId) {
  return ref.watch(databaseProvider).watchCollectionMovieLinks(collectionId);
});

final collectionShowLinksProvider =
    StreamProvider.family<List<CollectionShow>, int>((ref, collectionId) {
  return ref.watch(databaseProvider).watchCollectionShowLinks(collectionId);
});

final episodesForShowProvider =
    StreamProvider.family<List<Episode>, int>((ref, showId) {
  return ref.watch(databaseProvider).watchEpisodesForShow(showId);
});

final episodeCreditsProvider =
    StreamProvider.family<List<EpisodeCredit>, int>((ref, episodeId) {
  return ref.watch(databaseProvider).watchEpisodeCredits(episodeId);
});

final allEpisodeCreditsStreamProvider =
    StreamProvider<List<EpisodeCredit>>((ref) {
  return ref.watch(databaseProvider).watchAllEpisodeCredits();
});

/// The resolved, absolute path to library.sqlite (default location or a
/// user-chosen override), for display in Settings.
final databasePathProvider = FutureProvider<String>((ref) {
  return resolveDbFilePath();
});

/// Key is (itemType, itemId) e.g. ('movie', 42) or ('show', 7).
final awardsProvider =
    StreamProvider.family<List<Award>, (String, int)>((ref, key) {
  return ref.watch(databaseProvider).watchAwardsFor(key.$1, key.$2);
});

/// Key is (itemType, itemId) e.g. ('movie', 42) or ('episode', 108).
final watchHistoryProvider =
    StreamProvider.family<List<WatchEvent>, (String, int)>((ref, key) {
  return ref.watch(databaseProvider).watchHistoryFor(key.$1, key.$2);
});

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

class AppSettingsData {
  final String? tmdbApiKey;
  final String? omdbApiKey;
  final String? proxyHost;
  final int? proxyPort;
  AppSettingsData({
    this.tmdbApiKey,
    this.omdbApiKey,
    this.proxyHost,
    this.proxyPort,
  });
}

final appSettingsProvider = FutureProvider<AppSettingsData>((ref) async {
  final config = await AppConfigService.load();
  final apiKey = config.tmdbApiKey;
  final omdbKey = config.omdbApiKey;
  final proxyHost = config.proxyHost;
  return AppSettingsData(
    tmdbApiKey: (apiKey != null && apiKey.isNotEmpty) ? apiKey : null,
    omdbApiKey: (omdbKey != null && omdbKey.isNotEmpty) ? omdbKey : null,
    proxyHost: (proxyHost != null && proxyHost.isNotEmpty) ? proxyHost : null,
    proxyPort: config.proxyPort,
  );
});

// ---------------------------------------------------------------------------
// Theme (color + light/dark), persisted via AppConfigService
// ---------------------------------------------------------------------------

/// Overridden in main() with the config loaded before runApp(), so the
/// correct theme is already active on the very first frame — no flash of
/// a default theme while the config file loads asynchronously.
final initialAppConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError(
    'initialAppConfigProvider must be overridden in main()',
  );
});

class ThemeController extends StateNotifier<ThemeSettings> {
  ThemeController(AppConfig initial)
      : super(ThemeSettings(
          color: AppThemeColor.fromKey(initial.themeColor),
          mode: ThemeModeStorage.fromKey(initial.themeMode),
          backdropOverlayOpacity: initial.backdropOverlayOpacity ?? 0.5,
        ));

  Future<void> setColor(AppThemeColor color) async {
    state = state.copyWith(color: color);
    await AppConfigService.update(themeColor: color.storageKey);
  }

  Future<void> setMode(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    await AppConfigService.update(themeMode: mode.storageKey);
  }

  /// Updates in-memory only, for smooth live feedback while a Slider is
  /// being dragged. Call [setBackdropOverlayOpacity] once the drag ends
  /// to actually persist the value.
  void previewBackdropOverlayOpacity(double value) {
    state = state.copyWith(backdropOverlayOpacity: value);
  }

  Future<void> setBackdropOverlayOpacity(double value) async {
    state = state.copyWith(backdropOverlayOpacity: value);
    await AppConfigService.update(backdropOverlayOpacity: value);
  }
}

final themeControllerProvider =
    StateNotifierProvider<ThemeController, ThemeSettings>((ref) {
  final initial = ref.watch(initialAppConfigProvider);
  return ThemeController(initial);
});

final tmdbServiceProvider = Provider<TmdbService?>((ref) {
  final settings = ref.watch(appSettingsProvider).value;
  final apiKey = settings?.tmdbApiKey;
  if (apiKey == null || apiKey.isEmpty) return null;
  return TmdbService(
    apiKey: apiKey,
    proxyHost: settings?.proxyHost,
    proxyPort: settings?.proxyPort,
  );
});

final omdbServiceProvider = Provider<OmdbService?>((ref) {
  final settings = ref.watch(appSettingsProvider).value;
  final apiKey = settings?.omdbApiKey;
  if (apiKey == null || apiKey.isEmpty) return null;
  return OmdbService(
    apiKey: apiKey,
    proxyHost: settings?.proxyHost,
    proxyPort: settings?.proxyPort,
  );
});

/// No API key needed — Wikidata's query service is public.
final wikidataServiceProvider = Provider<WikidataService>((ref) {
  final settings = ref.watch(appSettingsProvider).value;
  return WikidataService(
    proxyHost: settings?.proxyHost,
    proxyPort: settings?.proxyPort,
  );
});

// ---------------------------------------------------------------------------
// Scan controller
// ---------------------------------------------------------------------------

enum ScanStatus { idle, scanning, matching, done, error }

/// A movie the scanner found that looks like a duplicate of one already
/// in the library (same title + year, different file) -- surfaced so the
/// UI can ask whether to add it as a separate entry or replace the
/// existing one. The scan is paused while this is set.
class PendingMovieDuplicate {
  final Movie existing;
  final String incomingTitle;
  final int? incomingYear;
  final String incomingFilePath;
  const PendingMovieDuplicate({
    required this.existing,
    required this.incomingTitle,
    required this.incomingYear,
    required this.incomingFilePath,
  });
}

class ScanState {
  final ScanStatus status;
  final String? currentItem;
  final int processed;
  final int total;
  final int matched;
  final int networkErrors;
  final String? lastError;
  final PendingMovieDuplicate? pendingDuplicate;

  const ScanState({
    this.status = ScanStatus.idle,
    this.currentItem,
    this.processed = 0,
    this.total = 0,
    this.matched = 0,
    this.networkErrors = 0,
    this.lastError,
    this.pendingDuplicate,
  });

  ScanState copyWith({
    ScanStatus? status,
    String? currentItem,
    int? processed,
    int? total,
    int? matched,
    int? networkErrors,
    String? lastError,
    PendingMovieDuplicate? pendingDuplicate,
    bool clearPendingDuplicate = false,
  }) {
    return ScanState(
      status: status ?? this.status,
      currentItem: currentItem ?? this.currentItem,
      processed: processed ?? this.processed,
      total: total ?? this.total,
      matched: matched ?? this.matched,
      networkErrors: networkErrors ?? this.networkErrors,
      lastError: lastError ?? this.lastError,
      pendingDuplicate: clearPendingDuplicate
          ? null
          : (pendingDuplicate ?? this.pendingDuplicate),
    );
  }
}

class _MovieMatch {
  final int? tmdbId;
  final String? imdbId;
  final String? originalTitle;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final double? rating;
  final int? runtimeMinutes;
  final String? genres;
  final String? contentRating;
  final String? director;
  final String? writer;
  final String? castNames;
  final String? originalLanguage;
  final List<MovieCreditInput> credits;

  _MovieMatch({
    this.tmdbId,
    this.imdbId,
    this.originalTitle,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.rating,
    this.runtimeMinutes,
    this.genres,
    this.contentRating,
    this.director,
    this.writer,
    this.castNames,
    this.originalLanguage,
    this.credits = const [],
  });
}

class _ShowMatch {
  final int? tmdbId;
  final String? imdbId;
  final String? originalTitle;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final double? rating;
  final String? genres;
  final String? contentRating;
  final String? status;
  final String? originalLanguage;
  final int? year;
  final List<MovieCreditInput> credits;

  _ShowMatch({
    this.tmdbId,
    this.imdbId,
    this.originalTitle,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.rating,
    this.genres,
    this.contentRating,
    this.status,
    this.originalLanguage,
    this.year,
    this.credits = const [],
  });
}

class _TmdbCreditsExtract {
  final String? director;
  final String? writer;
  final String? castNames;
  final List<MovieCreditInput> credits;
  _TmdbCreditsExtract({
    this.director,
    this.writer,
    this.castNames,
    required this.credits,
  });
}

/// OMDb's `Language` field is a comma-separated list (e.g. "English,
/// Spanish"), already human-readable, listed primary-language-first.
/// Statistics groups by a single language per title, so just the first
/// one is kept -- mirrors how [languageNameForCode] reduces TMDB's single
/// `original_language` code to one display name.
String? _primaryLanguageFromOmdb(String? raw) {
  final cleaned = OmdbService.cleanText(raw);
  if (cleaned == null) return null;
  final first = cleaned.split(',').first.trim();
  return first.isEmpty ? null : first;
}

/// TMDB's `first_air_date` is "YYYY-MM-DD" (or empty/absent for an
/// unannounced show); only the year is kept, to match `Movies.year`'s
/// granularity.
int? _yearFromTmdbDate(String? date) {
  if (date == null || date.length < 4) return null;
  return int.tryParse(date.substring(0, 4));
}

/// OMDb's `Year` field for a TV show is often a range, e.g. "2008–2013"
/// or "2008–" for one still airing -- using an en-dash, not a hyphen --
/// so this pulls out the first 4-digit run rather than assuming a
/// particular separator.
int? _yearFromOmdb(String? raw) {
  if (raw == null) return null;
  final match = RegExp(r'(\d{4})').firstMatch(raw);
  return match == null ? null : int.tryParse(match.group(1)!);
}

_TmdbCreditsExtract _extractTmdbCredits(Map<String, dynamic>? creditsMap) {
  String? director;
  String? writer;
  String? castNames;
  final creditsList = <MovieCreditInput>[];
  if (creditsMap != null) {
    final crew = (creditsMap['crew'] as List<dynamic>?) ?? [];
    final directorEntry = crew.firstWhere(
      (c) => c['job'] == 'Director',
      orElse: () => null,
    );
    director = directorEntry != null ? directorEntry['name'] as String? : null;
    if (director != null) {
      creditsList.add(MovieCreditInput(name: director, role: 'director'));
    }

    final writerEntry = crew.firstWhere(
      (c) =>
          c['job'] == 'Writer' ||
          c['job'] == 'Screenplay' ||
          c['job'] == 'Author',
      orElse: () => null,
    );
    writer = writerEntry != null ? writerEntry['name'] as String? : null;
    if (writer != null) {
      creditsList.add(MovieCreditInput(name: writer, role: 'writer'));
    }

    // Grab most of the credited cast (not just the top handful) so the
    // People tab reflects close to the full cast list.
    final cast = (creditsMap['cast'] as List<dynamic>?) ?? [];
    castNames = cast.take(6).map((c) => c['name']).join(', ');
    for (final c in cast.take(30)) {
      final name = c['name'] as String?;
      if (name == null || name.isEmpty) continue;
      creditsList.add(MovieCreditInput(
        name: name,
        role: 'actor',
        character: c['character'] as String?,
        photoPath:
            TmdbService.imageUrl(c['profile_path'] as String?, size: 'w185'),
      ));
    }
  }
  return _TmdbCreditsExtract(
    director: director,
    writer: writer,
    castNames: castNames,
    credits: creditsList,
  );
}

class ScanController extends StateNotifier<ScanState> {
  final AppDatabase db;
  final Ref ref;
  int _tmdbConsecutiveFailures = 0;
  int _thumbnailConsecutiveFailures = 0;
  static const _thumbnailCircuitBreakerThreshold = 3;
  static const _tmdbCircuitBreakerThreshold = 3;

  ScanController(this.db, this.ref) : super(const ScanState());

  Completer<bool>? _duplicateResolution;

  /// Called by the UI once the person picks "Add as New" (false) or
  /// "Replace Existing" (true) in response to a
  /// [ScanState.pendingDuplicate]. Unblocks the paused scan loop.
  void resolveDuplicate(bool replace) {
    _duplicateResolution?.complete(replace);
    _duplicateResolution = null;
    state = state.copyWith(clearPendingDuplicate: true);
  }

  Future<bool> _askAboutDuplicate(
    Movie existing,
    ScannedMovie item,
  ) async {
    final completer = Completer<bool>();
    _duplicateResolution = completer;
    state = state.copyWith(
      pendingDuplicate: PendingMovieDuplicate(
        existing: existing,
        incomingTitle: item.title,
        incomingYear: item.year,
        incomingFilePath: item.filePath,
      ),
    );
    return completer.future;
  }

  /// A movie already in the library with the same title + year as [item]
  /// but a different file -- same file path just means this is an update
  /// to something already scanned, not a duplicate to ask about.
  Movie? _findDuplicate(List<Movie> knownMovies, ScannedMovie item) {
    final normalizedTitle = item.title.trim().toLowerCase();
    for (final m in knownMovies) {
      if (m.filePath == item.filePath) continue;
      if (m.title.trim().toLowerCase() != normalizedTitle) continue;
      if (m.year != item.year) continue;
      return m;
    }
    return null;
  }

  /// Holds extracted metadata regardless of which source it came from, so
  /// the main loop doesn't need to care which API supplied it.
  Future<void> scanMovieFolder(String path) async {
    final tmdb = ref.read(tmdbServiceProvider);
    final omdb = ref.read(omdbServiceProvider);
    _tmdbConsecutiveFailures = 0;
    state = const ScanState(status: ScanStatus.scanning);

    final items = await LibraryScanner.scanMovies(path);
    state = state.copyWith(
      status: ScanStatus.matching,
      total: items.length,
      processed: 0,
      matched: 0,
      networkErrors: 0,
      lastError: null,
    );

    // Snapshot of existing movies, kept in sync as this scan adds or
    // replaces entries, so later items in the same scan can also be
    // recognized as duplicates of ones found earlier in it.
    var knownMovies = await db.getAllMovies();
    final knownFilePaths = knownMovies.map((m) => m.filePath).toSet();

    for (final item in items) {
      state = state.copyWith(currentItem: item.title);

      // Already in the library from a previous scan of this exact file --
      // leave it alone: no re-fetch, no overwriting anything that might
      // have been edited by hand since (title, personal rating, etc.).
      if (knownFilePaths.contains(item.filePath)) {
        state = state.copyWith(processed: state.processed + 1);
        continue;
      }

      int? replaceId;
      final duplicate = _findDuplicate(knownMovies, item);
      if (duplicate != null) {
        final replace = await _askAboutDuplicate(duplicate, item);
        if (replace) replaceId = duplicate.id;
      }

      // Always save the basic scanned info first, so the file shows up in
      // the library even if no metadata source is reachable.
      int movieId;
      try {
        if (replaceId != null) {
          await db.updateMovieDetails(
            replaceId,
            MoviesCompanion(
              filePath: Value(item.filePath),
              folderPath: Value(item.folderPath),
              year: Value(item.year),
              trailerFilePath: Value(item.trailerFilePath),
            ),
          );
          movieId = replaceId;
        } else {
          movieId = await db.upsertMovie(MoviesCompanion.insert(
            title: item.title,
            filePath: item.filePath,
            folderPath: item.folderPath,
            year: Value(item.year),
            trailerFilePath: Value(item.trailerFilePath),
          ));
        }
      } catch (_) {
        state = state.copyWith(processed: state.processed + 1);
        continue;
      }

      _MovieMatch? match;

      // OMDb first: on this app's typical network conditions it tends to be
      // reachable more reliably than TMDB, and trying it first avoids
      // waiting out a doomed TMDB attempt on every single item.
      if (omdb != null) {
        try {
          final tmdbForEnrichment =
              _tmdbConsecutiveFailures < _tmdbCircuitBreakerThreshold
                  ? tmdb
                  : null;
          match = await _matchMovieOmdb(
            omdb,
            tmdbForEnrichment,
            item.title,
            item.year,
          );
        } catch (e) {
          state = state.copyWith(
            networkErrors: state.networkErrors + 1,
            lastError: 'OMDb: $e',
          );
        }
      }

      if (match == null &&
          tmdb != null &&
          _tmdbConsecutiveFailures < _tmdbCircuitBreakerThreshold) {
        try {
          match = await _matchMovieTmdb(tmdb, item.title, item.year);
          _tmdbConsecutiveFailures = 0;
        } catch (e) {
          _tmdbConsecutiveFailures++;
          state = state.copyWith(
            networkErrors: state.networkErrors + 1,
            lastError: 'TMDB: $e',
          );
        }
      }

      if (match != null) {
        await db.updateMovieDetails(
          movieId,
          MoviesCompanion(
            title: Value(item.title),
            filePath: Value(item.filePath),
            folderPath: Value(item.folderPath),
            year: Value(item.year),
            trailerFilePath: Value(item.trailerFilePath),
            tmdbId: Value(match.tmdbId),
            imdbId: Value(match.imdbId),
            originalTitle: Value(match.originalTitle),
            overview: Value(match.overview),
            posterPath: Value(match.posterPath),
            backdropPath: Value(match.backdropPath),
            rating: Value(match.rating),
            runtimeMinutes: Value(match.runtimeMinutes),
            genres: Value(match.genres),
            contentRating: Value(match.contentRating),
            director: Value(match.director),
            writer: Value(match.writer),
            castNames: Value(match.castNames),
            originalLanguage: Value(match.originalLanguage),
          ),
        );
        try {
          await db.setMovieCredits(movieId, match.credits);
        } catch (_) {
          // Credits are a nice-to-have; don't fail the whole item over it.
        }
        unawaited(_saveMovieThumbnails(movieId, match));
        state = state.copyWith(matched: state.matched + 1);
      }

      // Keep the snapshot in sync so a later item in this same scan can
      // still be recognized as a duplicate of this one.
      final saved = await db.getMovieById(movieId);
      if (saved != null) {
        knownMovies = [
          for (final m in knownMovies)
            if (m.id != movieId) m,
          saved,
        ];
      }

      state = state.copyWith(processed: state.processed + 1);
    }

    state = state.copyWith(status: ScanStatus.done);
  }

  Future<_MovieMatch?> _matchMovieOmdb(
    OmdbService omdb,
    TmdbService? tmdbForEnrichment,
    String title,
    int? year,
  ) async {
    final data = await omdb.lookupMovie(title, year: year);
    if (data == null) return null;

    final credits = <MovieCreditInput>[];
    void addNames(String? raw, String role) {
      final cleaned = OmdbService.cleanText(raw);
      if (cleaned == null) return;
      for (final name in cleaned.split(',')) {
        final trimmed = name.trim();
        if (trimmed.isNotEmpty) {
          credits.add(MovieCreditInput(name: trimmed, role: role));
        }
      }
    }

    addNames(data['Director'] as String?, 'director');
    addNames(data['Writer'] as String?, 'writer');
    addNames(data['Actors'] as String?, 'actor');

    int? tmdbId;
    String? backdropPath;
    String? originalTitle;
    var contentRating = OmdbService.cleanText(data['Rated'] as String?);

    // Supplementary: OMDb has no backdrop image and its basic response only
    // lists a handful of actors with no photos. If TMDB is reachable, use
    // it for a fuller, photo-backed cast/crew list and the backdrop — the
    // movie's own metadata still comes from OMDb above.
    if (tmdbForEnrichment != null) {
      try {
        final tmdbResults =
            await tmdbForEnrichment.searchMovie(title, year: year);
        if (tmdbResults.isNotEmpty) {
          final tmdbDetails =
              await tmdbForEnrichment.getMovieDetails(tmdbResults.first.id);
          backdropPath = TmdbService.imageUrl(
            tmdbDetails['backdrop_path'] as String?,
            size: 'w1280',
          );
          originalTitle = tmdbDetails['original_title'] as String?;
          final extracted = _extractTmdbCredits(
            tmdbDetails['credits'] as Map<String, dynamic>?,
          );
          if (extracted.credits.isNotEmpty) {
            credits
              ..clear()
              ..addAll(extracted.credits);
          }
          contentRating ??= TmdbService.extractCertification(tmdbDetails);
          tmdbId = tmdbResults.first.id;
        }
      } catch (_) {
        // Keep the OMDb-derived names as a fallback; this enrichment step
        // is optional.
      }
    }

    return _MovieMatch(
      tmdbId: tmdbId,
      imdbId: data['imdbID'] as String?,
      originalTitle: originalTitle,
      overview: OmdbService.cleanText(data['Plot'] as String?),
      posterPath: OmdbService.posterUrl(data['Poster'] as String?),
      backdropPath: backdropPath,
      rating: OmdbService.parseRating(data['imdbRating'] as String?),
      runtimeMinutes:
          OmdbService.parseRuntimeMinutes(data['Runtime'] as String?),
      genres: OmdbService.cleanText(data['Genre'] as String?),
      contentRating: contentRating,
      director: OmdbService.cleanText(data['Director'] as String?),
      writer: OmdbService.cleanText(data['Writer'] as String?),
      castNames: OmdbService.cleanText(data['Actors'] as String?),
      originalLanguage: _primaryLanguageFromOmdb(data['Language'] as String?),
      credits: credits,
    );
  }

  /// Fetches a movie by a known IMDb id directly (no title search) -- used
  /// once a movie's imdbId is pinned, either by the original match or a
  /// manual correction in Edit, so a refresh can never drift to a
  /// different title.
  Future<_MovieMatch?> _matchMovieOmdbById(
    OmdbService omdb,
    String imdbId,
  ) async {
    final data = await omdb.getByImdbId(imdbId);
    if (data == null) return null;

    final credits = <MovieCreditInput>[];
    void addNames(String? raw, String role) {
      final cleaned = OmdbService.cleanText(raw);
      if (cleaned == null) return;
      for (final name in cleaned.split(',')) {
        final trimmed = name.trim();
        if (trimmed.isNotEmpty) {
          credits.add(MovieCreditInput(name: trimmed, role: role));
        }
      }
    }

    addNames(data['Director'] as String?, 'director');
    addNames(data['Writer'] as String?, 'writer');
    addNames(data['Actors'] as String?, 'actor');

    return _MovieMatch(
      tmdbId: null,
      imdbId: imdbId,
      overview: OmdbService.cleanText(data['Plot'] as String?),
      posterPath: OmdbService.posterUrl(data['Poster'] as String?),
      rating: OmdbService.parseRating(data['imdbRating'] as String?),
      runtimeMinutes:
          OmdbService.parseRuntimeMinutes(data['Runtime'] as String?),
      genres: OmdbService.cleanText(data['Genre'] as String?),
      contentRating: OmdbService.cleanText(data['Rated'] as String?),
      director: OmdbService.cleanText(data['Director'] as String?),
      writer: OmdbService.cleanText(data['Writer'] as String?),
      castNames: OmdbService.cleanText(data['Actors'] as String?),
      originalLanguage: _primaryLanguageFromOmdb(data['Language'] as String?),
      credits: credits,
    );
  }

  Future<_MovieMatch?> _matchMovieTmdb(
    TmdbService tmdb,
    String title,
    int? year,
  ) async {
    final results = await tmdb.searchMovie(title, year: year);
    if (results.isEmpty) return null;
    return _matchMovieTmdbById(tmdb, results.first.id);
  }

  /// Fetches a movie by a known TMDB id directly (no title search) -- the
  /// TMDB counterpart to [_matchMovieOmdbById].
  Future<_MovieMatch?> _matchMovieTmdbById(TmdbService tmdb, int tmdbId) async {
    final details = await tmdb.getMovieDetails(tmdbId);

    final genreList = (details['genres'] as List<dynamic>?) ?? [];
    final genres = genreList.map((g) => g['name']).join(', ');
    final extracted =
        _extractTmdbCredits(details['credits'] as Map<String, dynamic>?);

    return _MovieMatch(
      tmdbId: tmdbId,
      imdbId: details['imdb_id'] as String?,
      originalTitle: details['original_title'] as String?,
      overview: details['overview'] as String?,
      posterPath: TmdbService.imageUrl(details['poster_path'] as String?),
      backdropPath: TmdbService.imageUrl(
        details['backdrop_path'] as String?,
        size: 'w1280',
      ),
      rating: (details['vote_average'] as num?)?.toDouble(),
      runtimeMinutes: details['runtime'] as int?,
      genres: genres,
      contentRating: TmdbService.extractCertification(details),
      director: extracted.director,
      writer: extracted.writer,
      castNames: extracted.castNames,
      originalLanguage: languageNameForCode(details['original_language'] as String?),
      credits: extracted.credits,
    );
  }

  /// Downloads a small local copy of the poster/backdrop in the background
  /// so it still shows with no internet. Never awaited by callers — must
  /// not slow down scanning, and must never throw.
  Future<void> _saveMovieThumbnails(int movieId, _MovieMatch match) async {
    if (_thumbnailConsecutiveFailures >= _thumbnailCircuitBreakerThreshold) {
      return;
    }
    if (match.posterPath == null && match.backdropPath == null) return;
    final results = await Future.wait([
      ThumbnailService.fetch(match.posterPath),
      ThumbnailService.fetch(match.backdropPath),
    ]);
    final poster = results[0];
    final backdrop = results[1];
    if (poster == null && backdrop == null) {
      _thumbnailConsecutiveFailures++;
      return;
    }
    _thumbnailConsecutiveFailures = 0;
    try {
      await db.updateMovieThumbnails(movieId, poster: poster, backdrop: backdrop);
    } catch (_) {
      // Nice-to-have; never let this surface as a scan error.
    }
  }

  Future<void> _saveShowThumbnails(int showId, _ShowMatch match) async {
    if (_thumbnailConsecutiveFailures >= _thumbnailCircuitBreakerThreshold) {
      return;
    }
    if (match.posterPath == null && match.backdropPath == null) return;
    final results = await Future.wait([
      ThumbnailService.fetch(match.posterPath),
      ThumbnailService.fetch(match.backdropPath),
    ]);
    final poster = results[0];
    final backdrop = results[1];
    if (poster == null && backdrop == null) {
      _thumbnailConsecutiveFailures++;
      return;
    }
    _thumbnailConsecutiveFailures = 0;
    try {
      await db.updateShowThumbnails(showId, poster: poster, backdrop: backdrop);
    } catch (_) {
      // Nice-to-have; never let this surface as a scan error.
    }
  }

  Future<void> scanShowFolder(String path) async {
    final tmdb = ref.read(tmdbServiceProvider);
    final omdb = ref.read(omdbServiceProvider);
    _tmdbConsecutiveFailures = 0;
    state = const ScanState(status: ScanStatus.scanning);

    final shows = await LibraryScanner.scanShows(path);
    final knownEpisodePaths =
        (await db.getAllEpisodesOnce()).map((e) => e.filePath).toSet();

    state = state.copyWith(
      status: ScanStatus.matching,
      total: shows.length,
      processed: 0,
      matched: 0,
      networkErrors: 0,
      lastError: null,
    );

    for (final show in shows) {
      state = state.copyWith(currentItem: show.title);

      final newEpisodes = show.episodes
          .where((ep) => !knownEpisodePaths.contains(ep.filePath))
          .toList();

      // Nothing new under this title since the last scan -- leave the show
      // and its episodes exactly as they are, no re-fetch.
      if (newEpisodes.isEmpty) {
        state = state.copyWith(processed: state.processed + 1);
        continue;
      }

      final existingShow = await db.getShowByTitle(show.title);

      int showId;
      try {
        showId = existingShow?.id ??
            await db.upsertShow(ShowsCompanion.insert(
              title: show.title,
              folderPath: show.folderPath,
            ));
        for (final ep in newEpisodes) {
          await db.upsertEpisode(EpisodesCompanion.insert(
            showId: showId,
            seasonNumber: ep.season,
            episodeNumber: ep.episode,
            filePath: ep.filePath,
          ));
        }
      } catch (_) {
        state = state.copyWith(processed: state.processed + 1);
        continue;
      }

      _ShowMatch? match;
      final alreadyMatched =
          existingShow?.tmdbId != null || existingShow?.imdbId != null;

      // Only spend a fresh API match on this show if it hasn't been
      // matched before -- an already-matched show keeps its existing
      // info untouched and just gets its new episodes enriched below.
      if (!alreadyMatched) {
        if (omdb != null) {
          try {
            final tmdbForEnrichment =
                _tmdbConsecutiveFailures < _tmdbCircuitBreakerThreshold
                    ? tmdb
                    : null;
            match =
                await _matchShowOmdb(omdb, tmdbForEnrichment, show.title);
          } catch (e) {
            state = state.copyWith(
              networkErrors: state.networkErrors + 1,
              lastError: 'OMDb: $e',
            );
          }
        }

        if (match == null &&
            tmdb != null &&
            _tmdbConsecutiveFailures < _tmdbCircuitBreakerThreshold) {
          try {
            match = await _matchShowTmdb(tmdb, show.title);
            _tmdbConsecutiveFailures = 0;
          } catch (e) {
            _tmdbConsecutiveFailures++;
            state = state.copyWith(
              networkErrors: state.networkErrors + 1,
              lastError: 'TMDB: $e',
            );
          }
        }

        if (match != null) {
          await db.upsertShow(ShowsCompanion.insert(
            title: show.title,
            folderPath: show.folderPath,
            tmdbId: Value(match.tmdbId),
            imdbId: Value(match.imdbId),
            originalTitle: Value(match.originalTitle),
            overview: Value(match.overview),
            posterPath: Value(match.posterPath),
            backdropPath: Value(match.backdropPath),
            rating: Value(match.rating),
            genres: Value(match.genres),
            contentRating: Value(match.contentRating),
            status: Value(match.status),
            originalLanguage: Value(match.originalLanguage),
            year: Value(match.year),
          ));
          try {
            await db.setShowCredits(showId, match.credits);
          } catch (_) {
            // Credits are a nice-to-have; don't fail the whole item over it.
          }
          unawaited(_saveShowThumbnails(showId, match));
          state = state.copyWith(matched: state.matched + 1);
        }
      }

      // Enrich only the seasons the new episodes belong to, using
      // whichever tmdbId/imdbId the show has -- freshly matched above, or
      // already on file from a previous scan.
      final tmdbIdForEpisodes = match?.tmdbId ?? existingShow?.tmdbId;
      final imdbIdForEpisodes = match?.imdbId ?? existingShow?.imdbId;
      if (tmdbIdForEpisodes != null || imdbIdForEpisodes != null) {
        final seasonNumbers = newEpisodes.map((e) => e.season).toSet();
        final tmdbForEpisodes =
            _tmdbConsecutiveFailures < _tmdbCircuitBreakerThreshold
                ? tmdb
                : null;
        try {
          await _enrichEpisodes(
            showId,
            seasonNumbers,
            tmdbId: tmdbIdForEpisodes,
            imdbId: imdbIdForEpisodes,
            tmdb: tmdbForEpisodes,
            omdb: omdb,
          );
        } catch (_) {
          // Episode-level enrichment is best-effort.
        }
      }

      state = state.copyWith(processed: state.processed + 1);
    }

    state = state.copyWith(status: ScanStatus.done);
  }

  Future<_ShowMatch?> _matchShowOmdb(
    OmdbService omdb,
    TmdbService? tmdbForEnrichment,
    String title,
  ) async {
    final data = await omdb.lookupShow(title);
    if (data == null) return null;

    final credits = <MovieCreditInput>[];
    void addNames(String? raw, String role) {
      final cleaned = OmdbService.cleanText(raw);
      if (cleaned == null) return;
      for (final name in cleaned.split(',')) {
        final trimmed = name.trim();
        if (trimmed.isNotEmpty) {
          credits.add(MovieCreditInput(name: trimmed, role: role));
        }
      }
    }

    addNames(data['Writer'] as String?, 'creator');
    addNames(data['Actors'] as String?, 'actor');

    final totalSeasons = data['totalSeasons'];
    final statusText = (data['Status'] as String?) ??
        (totalSeasons != null ? '$totalSeasons seasons' : null);

    int? tmdbId;
    String? backdropPath;
    String? originalTitle;
    var contentRating = OmdbService.cleanText(data['Rated'] as String?);

    // Supplementary: OMDb has no backdrop image and only a handful of
    // actors with no photos. If TMDB is reachable, use it for a fuller,
    // photo-backed cast list and the backdrop — the show's own metadata
    // (poster, overview, rating) still comes from OMDb above.
    if (tmdbForEnrichment != null) {
      try {
        final tmdbResults = await tmdbForEnrichment.searchTvShow(title);
        if (tmdbResults.isNotEmpty) {
          final tmdbDetails =
              await tmdbForEnrichment.getShowDetails(tmdbResults.first.id);
          backdropPath = TmdbService.imageUrl(
            tmdbDetails['backdrop_path'] as String?,
            size: 'w1280',
          );
          originalTitle = tmdbDetails['original_name'] as String?;
          final tmdbCredits = <MovieCreditInput>[];
          final createdBy =
              (tmdbDetails['created_by'] as List<dynamic>?) ?? [];
          for (final c in createdBy) {
            final name = c['name'] as String?;
            if (name != null && name.isNotEmpty) {
              tmdbCredits.add(MovieCreditInput(
                name: name,
                role: 'creator',
                photoPath: TmdbService.imageUrl(
                  c['profile_path'] as String?,
                  size: 'w185',
                ),
              ));
            }
          }
          final creditsMap = tmdbDetails['credits'] as Map<String, dynamic>?;
          if (creditsMap != null) {
            final cast = (creditsMap['cast'] as List<dynamic>?) ?? [];
            for (final c in cast.take(30)) {
              final name = c['name'] as String?;
              if (name == null || name.isEmpty) continue;
              tmdbCredits.add(MovieCreditInput(
                name: name,
                role: 'actor',
                character: c['character'] as String?,
                photoPath: TmdbService.imageUrl(
                  c['profile_path'] as String?,
                  size: 'w185',
                ),
              ));
            }
          }
          if (tmdbCredits.isNotEmpty) {
            credits
              ..clear()
              ..addAll(tmdbCredits);
          }
          contentRating ??= TmdbService.extractShowCertification(tmdbDetails);
          tmdbId = tmdbResults.first.id;
        }
      } catch (_) {
        // Keep the OMDb-derived names/no-backdrop as a fallback; this
        // enrichment step is optional.
      }
    }

    return _ShowMatch(
      tmdbId: tmdbId,
      imdbId: data['imdbID'] as String?,
      originalTitle: originalTitle,
      overview: OmdbService.cleanText(data['Plot'] as String?),
      posterPath: OmdbService.posterUrl(data['Poster'] as String?),
      backdropPath: backdropPath,
      rating: OmdbService.parseRating(data['imdbRating'] as String?),
      genres: OmdbService.cleanText(data['Genre'] as String?),
      contentRating: contentRating,
      status: statusText,
      originalLanguage: _primaryLanguageFromOmdb(data['Language'] as String?),
      year: _yearFromOmdb(data['Year'] as String?),
      credits: credits,
    );
  }

  /// Fetches a show by a known IMDb id directly (no title search) --
  /// mirrors [_matchMovieOmdbById] for shows.
  Future<_ShowMatch?> _matchShowOmdbById(
    OmdbService omdb,
    String imdbId,
  ) async {
    final data = await omdb.getByImdbId(imdbId);
    if (data == null) return null;

    final credits = <MovieCreditInput>[];
    void addNames(String? raw, String role) {
      final cleaned = OmdbService.cleanText(raw);
      if (cleaned == null) return;
      for (final name in cleaned.split(',')) {
        final trimmed = name.trim();
        if (trimmed.isNotEmpty) {
          credits.add(MovieCreditInput(name: trimmed, role: role));
        }
      }
    }

    addNames(data['Writer'] as String?, 'creator');
    addNames(data['Actors'] as String?, 'actor');

    final totalSeasons = data['totalSeasons'];
    final statusText = (data['Status'] as String?) ??
        (totalSeasons != null ? '$totalSeasons seasons' : null);

    return _ShowMatch(
      tmdbId: null,
      imdbId: imdbId,
      overview: OmdbService.cleanText(data['Plot'] as String?),
      posterPath: OmdbService.posterUrl(data['Poster'] as String?),
      rating: OmdbService.parseRating(data['imdbRating'] as String?),
      genres: OmdbService.cleanText(data['Genre'] as String?),
      contentRating: OmdbService.cleanText(data['Rated'] as String?),
      status: statusText,
      originalLanguage: _primaryLanguageFromOmdb(data['Language'] as String?),
      year: _yearFromOmdb(data['Year'] as String?),
      credits: credits,
    );
  }

  Future<_ShowMatch?> _matchShowTmdb(TmdbService tmdb, String title) async {
    final results = await tmdb.searchTvShow(title);
    if (results.isEmpty) return null;
    return _matchShowTmdbById(tmdb, results.first.id);
  }

  /// Fetches a show by a known TMDB id directly (no title search) -- the
  /// TMDB counterpart to [_matchShowOmdbById].
  Future<_ShowMatch?> _matchShowTmdbById(TmdbService tmdb, int tmdbId) async {
    final details = await tmdb.getShowDetails(tmdbId);

    final genreList = (details['genres'] as List<dynamic>?) ?? [];
    final genres = genreList.map((g) => g['name']).join(', ');

    final credits = <MovieCreditInput>[];
    final createdBy = (details['created_by'] as List<dynamic>?) ?? [];
    for (final c in createdBy) {
      final name = c['name'] as String?;
      if (name != null && name.isNotEmpty) {
        credits.add(MovieCreditInput(
          name: name,
          role: 'creator',
          photoPath: TmdbService.imageUrl(
            c['profile_path'] as String?,
            size: 'w185',
          ),
        ));
      }
    }
    final creditsMap = details['credits'] as Map<String, dynamic>?;
    if (creditsMap != null) {
      final cast = (creditsMap['cast'] as List<dynamic>?) ?? [];
      for (final c in cast.take(30)) {
        final name = c['name'] as String?;
        if (name == null || name.isEmpty) continue;
        credits.add(MovieCreditInput(
          name: name,
          role: 'actor',
          character: c['character'] as String?,
          photoPath: TmdbService.imageUrl(
            c['profile_path'] as String?,
            size: 'w185',
          ),
        ));
      }
    }

    final externalIds = details['external_ids'] as Map<String, dynamic>?;

    return _ShowMatch(
      tmdbId: tmdbId,
      imdbId: externalIds?['imdb_id'] as String?,
      originalTitle: details['original_name'] as String?,
      overview: details['overview'] as String?,
      posterPath: TmdbService.imageUrl(details['poster_path'] as String?),
      backdropPath: TmdbService.imageUrl(
        details['backdrop_path'] as String?,
        size: 'w1280',
      ),
      rating: (details['vote_average'] as num?)?.toDouble(),
      genres: genres,
      contentRating: TmdbService.extractShowCertification(details),
      status: details['status'] as String?,
      originalLanguage: languageNameForCode(details['original_language'] as String?),
      year: _yearFromTmdbDate(details['first_air_date'] as String?),
      credits: credits,
    );
  }

  /// Fetches per-episode title/overview/air date/thumbnail one season at a
  /// time and writes them onto the already-inserted episode rows.
  Future<void> _enrichEpisodes(
    int showId,
    Set<int> seasonNumbers, {
    int? tmdbId,
    String? imdbId,
    required TmdbService? tmdb,
    required OmdbService? omdb,
  }) async {
    for (final seasonNum in seasonNumbers) {
      var gotFromTmdb = false;
      if (tmdbId != null && tmdb != null) {
        try {
          final seasonData = await tmdb.getSeasonDetails(tmdbId, seasonNum);
          final episodesList =
              (seasonData['episodes'] as List<dynamic>?) ?? [];
          for (final ep in episodesList) {
            final epNum = ep['episode_number'] as int?;
            if (epNum == null) continue;
            final guestStars =
                (ep['guest_stars'] as List<dynamic>?) ?? [];
            await db.updateEpisodeMetadata(
              showId,
              seasonNum,
              epNum,
              title: ep['name'] as String?,
              overview: ep['overview'] as String?,
              airDate: ep['air_date'] as String?,
              stillPath: TmdbService.imageUrl(
                ep['still_path'] as String?,
                size: 'w300',
              ),
              rating: (ep['vote_average'] as num?)?.toDouble(),
              guestStars:
                  guestStars.take(10).map((g) => g['name']).join(', '),
              runtimeMinutes: ep['runtime'] as int?,
            );

            if (guestStars.isNotEmpty) {
              try {
                final episodeId =
                    await db.getEpisodeId(showId, seasonNum, epNum);
                if (episodeId != null) {
                  final credits = guestStars.take(20).map((g) {
                    return MovieCreditInput(
                      name: (g['name'] as String?) ?? '',
                      role: 'actor',
                      character: g['character'] as String?,
                      photoPath: TmdbService.imageUrl(
                        g['profile_path'] as String?,
                        size: 'w185',
                      ),
                    );
                  }).where((c) => c.name.isNotEmpty).toList();
                  await db.setEpisodeCredits(episodeId, credits);
                }
              } catch (_) {
                // Guest star linking is best-effort.
              }
            }
          }
          gotFromTmdb = episodesList.isNotEmpty;
        } catch (_) {
          // Fall through to try OMDb for this season.
        }
      }

      if (!gotFromTmdb && imdbId != null && omdb != null) {
        try {
          final episodesList = await omdb.getSeasonEpisodes(
            imdbId,
            seasonNum,
          );
          for (final ep in episodesList) {
            final epNum = int.tryParse(ep['Episode'] as String? ?? '');
            if (epNum == null) continue;
            await db.updateEpisodeMetadata(
              showId,
              seasonNum,
              epNum,
              title: OmdbService.cleanText(ep['Title'] as String?),
              airDate: OmdbService.cleanText(ep['Released'] as String?),
              rating: OmdbService.parseRating(ep['imdbRating'] as String?),
            );
          }
        } catch (_) {
          // Episode enrichment is best-effort; skip silently.
        }
      }
    }
  }

  /// Re-runs matching for a single already-scanned movie (the "Update"
  /// button on the movie detail screen). If the movie already has a
  /// tmdbId or imdbId -- from the original match, or a manual correction
  /// in Edit -- this fetches that exact id and nothing else, so a refresh
  /// can never drift to a different title. Only a movie with neither id
  /// set falls back to a fresh title/year search.
  Future<bool> refreshMovie(
    int movieId, {
    MetadataRefreshMode mode = MetadataRefreshMode.full,
  }) async {
    final movie = await db.getMovieById(movieId);
    if (movie == null) return false;

    state = ScanState(
      status: ScanStatus.matching,
      total: 1,
      processed: 0,
      currentItem: movie.title,
    );

    final success = await _refreshMovieCore(movie, mode);

    state = state.copyWith(
      status: ScanStatus.done,
      processed: 1,
      matched: success ? 1 : 0,
    );
    return success;
  }

  /// The actual match-and-save logic shared by [refreshMovie] (single
  /// item, from the detail screen's Update button) and [refreshMultiple]
  /// (bulk, from multi-select) -- neither touches [state] here, so the
  /// caller's own progress reporting (single-item vs. batch) is never
  /// clobbered mid-loop.
  Future<bool> _refreshMovieCore(Movie movie, MetadataRefreshMode mode) async {
    final movieId = movie.id;
    final tmdb = ref.read(tmdbServiceProvider);
    final omdb = ref.read(omdbServiceProvider);

    _MovieMatch? match;
    if (movie.tmdbId != null && tmdb != null) {
      try {
        match = await _matchMovieTmdbById(tmdb, movie.tmdbId!);
      } catch (e) {
        state = state.copyWith(
          networkErrors: state.networkErrors + 1,
          lastError: 'TMDB: $e',
        );
      }
    } else if (movie.imdbId != null && omdb != null) {
      try {
        match = await _matchMovieOmdbById(omdb, movie.imdbId!);
      } catch (e) {
        state = state.copyWith(
          networkErrors: state.networkErrors + 1,
          lastError: 'OMDb: $e',
        );
      }
    } else {
      if (omdb != null) {
        try {
          match = await _matchMovieOmdb(omdb, tmdb, movie.title, movie.year);
        } catch (e) {
          state = state.copyWith(
            networkErrors: state.networkErrors + 1,
            lastError: 'OMDb: $e',
          );
        }
      }
      if (match == null && tmdb != null) {
        try {
          match = await _matchMovieTmdb(tmdb, movie.title, movie.year);
        } catch (e) {
          state = state.copyWith(
            networkErrors: state.networkErrors + 1,
            lastError: 'TMDB: $e',
          );
        }
      }
    }

    var success = false;
    final trailerPath = movie.trailerFilePath ??
        await LibraryScanner.findTrailerInFolder(
            movie.folderPath, movie.filePath);
    if (match != null) {
      final includeImages = mode != MetadataRefreshMode.skipImages;
      final includeOtherFields = mode != MetadataRefreshMode.imagesOnly;
      await db.upsertMovie(MoviesCompanion.insert(
        title: movie.title,
        filePath: movie.filePath,
        folderPath: movie.folderPath,
        year: Value(movie.year),
        trailerFilePath: Value(trailerPath),
        tmdbId: Value(match.tmdbId ?? movie.tmdbId),
        imdbId: Value(match.imdbId ?? movie.imdbId),
        originalTitle: includeOtherFields
            ? Value(match.originalTitle)
            : const Value.absent(),
        overview:
            includeOtherFields ? Value(match.overview) : const Value.absent(),
        posterPath:
            includeImages ? Value(match.posterPath) : const Value.absent(),
        backdropPath:
            includeImages ? Value(match.backdropPath) : const Value.absent(),
        rating:
            includeOtherFields ? Value(match.rating) : const Value.absent(),
        runtimeMinutes: includeOtherFields
            ? Value(match.runtimeMinutes)
            : const Value.absent(),
        genres:
            includeOtherFields ? Value(match.genres) : const Value.absent(),
        contentRating: includeOtherFields
            ? Value(match.contentRating)
            : const Value.absent(),
        director:
            includeOtherFields ? Value(match.director) : const Value.absent(),
        writer:
            includeOtherFields ? Value(match.writer) : const Value.absent(),
        castNames: includeOtherFields
            ? Value(match.castNames)
            : const Value.absent(),
        originalLanguage: includeOtherFields
            ? Value(match.originalLanguage)
            : const Value.absent(),
      ));
      if (includeOtherFields) {
        try {
          await db.setMovieCredits(movieId, match.credits);
        } catch (_) {
          // Non-fatal.
        }
      }
      if (includeImages) {
        unawaited(_saveMovieThumbnails(movieId, match));
      }
      success = true;
    } else if (trailerPath != movie.trailerFilePath) {
      // Even if no metadata match was found, still save a newly detected
      // trailer.
      await db.updateMovieDetails(
        movieId,
        MoviesCompanion(trailerFilePath: Value(trailerPath)),
      );
    }

    return success;
  }

  /// Re-runs matching for a single already-scanned show, including
  /// re-enriching its episodes (the "Update" button on the show detail
  /// screen). Same "trust a pinned id" contract as [refreshMovie].
  Future<bool> refreshShow(
    int showId, {
    MetadataRefreshMode mode = MetadataRefreshMode.full,
  }) async {
    final show = await db.getShowById(showId);
    if (show == null) return false;

    state = ScanState(
      status: ScanStatus.matching,
      total: 1,
      processed: 0,
      currentItem: show.title,
    );

    final success = await _refreshShowCore(show, mode);

    state = state.copyWith(
      status: ScanStatus.done,
      processed: 1,
      matched: success ? 1 : 0,
    );
    return success;
  }

  /// The actual match-and-save logic shared by [refreshShow] and
  /// [refreshMultiple]; see [_refreshMovieCore] for why [state] is left
  /// alone here.
  Future<bool> _refreshShowCore(Show show, MetadataRefreshMode mode) async {
    final showId = show.id;
    final tmdb = ref.read(tmdbServiceProvider);
    final omdb = ref.read(omdbServiceProvider);

    _ShowMatch? match;
    if (show.tmdbId != null && tmdb != null) {
      try {
        match = await _matchShowTmdbById(tmdb, show.tmdbId!);
      } catch (e) {
        state = state.copyWith(
          networkErrors: state.networkErrors + 1,
          lastError: 'TMDB: $e',
        );
      }
    } else if (show.imdbId != null && omdb != null) {
      try {
        match = await _matchShowOmdbById(omdb, show.imdbId!);
      } catch (e) {
        state = state.copyWith(
          networkErrors: state.networkErrors + 1,
          lastError: 'OMDb: $e',
        );
      }
    } else {
      if (omdb != null) {
        try {
          match = await _matchShowOmdb(omdb, tmdb, show.title);
        } catch (e) {
          state = state.copyWith(
            networkErrors: state.networkErrors + 1,
            lastError: 'OMDb: $e',
          );
        }
      }
      if (match == null && tmdb != null) {
        try {
          match = await _matchShowTmdb(tmdb, show.title);
        } catch (e) {
          state = state.copyWith(
            networkErrors: state.networkErrors + 1,
            lastError: 'TMDB: $e',
          );
        }
      }
    }

    var success = false;
    if (match != null) {
      final includeImages = mode != MetadataRefreshMode.skipImages;
      final includeOtherFields = mode != MetadataRefreshMode.imagesOnly;
      await db.upsertShow(ShowsCompanion.insert(
        title: show.title,
        folderPath: show.folderPath,
        tmdbId: Value(match.tmdbId ?? show.tmdbId),
        imdbId: Value(match.imdbId ?? show.imdbId),
        originalTitle: includeOtherFields
            ? Value(match.originalTitle)
            : const Value.absent(),
        overview:
            includeOtherFields ? Value(match.overview) : const Value.absent(),
        posterPath:
            includeImages ? Value(match.posterPath) : const Value.absent(),
        backdropPath:
            includeImages ? Value(match.backdropPath) : const Value.absent(),
        rating:
            includeOtherFields ? Value(match.rating) : const Value.absent(),
        genres:
            includeOtherFields ? Value(match.genres) : const Value.absent(),
        contentRating: includeOtherFields
            ? Value(match.contentRating)
            : const Value.absent(),
        status:
            includeOtherFields ? Value(match.status) : const Value.absent(),
        originalLanguage: includeOtherFields
            ? Value(match.originalLanguage)
            : const Value.absent(),
        year: includeOtherFields ? Value(match.year) : const Value.absent(),
      ));
      if (includeOtherFields) {
        try {
          await db.setShowCredits(showId, match.credits);
        } catch (_) {
          // Non-fatal.
        }
      }
      if (includeImages) {
        unawaited(_saveShowThumbnails(showId, match));
      }

      if (includeOtherFields) {
        try {
          final episodes = await db.getEpisodesForShowOnce(showId);
          final seasonNumbers = episodes.map((e) => e.seasonNumber).toSet();
          await _enrichEpisodes(
            showId,
            seasonNumbers,
            tmdbId: match.tmdbId ?? show.tmdbId,
            imdbId: match.imdbId ?? show.imdbId,
            tmdb: tmdb,
            omdb: omdb,
          );
        } catch (_) {
          // Non-fatal.
        }
      }
      success = true;
    }

    return success;
  }

  /// Bulk "Refresh Metadata" for movies/shows selected via multi-select
  /// on any list page. Reuses the same [ScanState] progress reporting as
  /// folder scans, so the existing progress bar in the app shell just
  /// works for this too.
  Future<void> refreshMultiple(
    List<({String kind, int id})> targets,
    MetadataRefreshMode mode,
  ) async {
    state = ScanState(
      status: ScanStatus.matching,
      total: targets.length,
      processed: 0,
    );
    var matched = 0;
    for (var i = 0; i < targets.length; i++) {
      final target = targets[i];
      bool ok;
      if (target.kind == 'movie') {
        final movie = await db.getMovieById(target.id);
        state = state.copyWith(currentItem: movie?.title);
        ok = movie == null ? false : await _refreshMovieCore(movie, mode);
      } else {
        final show = await db.getShowById(target.id);
        state = state.copyWith(currentItem: show?.title);
        ok = show == null ? false : await _refreshShowCore(show, mode);
      }
      if (ok) matched++;
      state = state.copyWith(processed: i + 1, matched: matched);
    }
    state = state.copyWith(status: ScanStatus.done);
  }

  /// Re-fetches a person's bio/photo from TMDB -- unlike the lazy
  /// first-fetch-only lookup on the person detail screen, this always
  /// re-fetches, so it can also be used to pull in newly-added details.
  /// Prefers the pinned [Person.tmdbPersonId] when present, otherwise
  /// searches by name.
  Future<bool> refreshPerson(
    int personId, {
    MetadataRefreshMode mode = MetadataRefreshMode.full,
  }) async {
    final person = await db.getPersonById(personId);
    if (person == null) return false;
    final tmdb = ref.read(tmdbServiceProvider);
    if (tmdb == null) return false;

    try {
      var tmdbPersonId = person.tmdbPersonId;
      if (tmdbPersonId == null) {
        final results = await tmdb.searchPerson(person.name);
        if (results.isEmpty) return false;
        tmdbPersonId = results.first['id'] as int?;
      }
      if (tmdbPersonId == null) return false;

      final details = await tmdb.getPersonDetails(tmdbPersonId);
      final includeImages = mode != MetadataRefreshMode.skipImages;
      final includeOtherFields = mode != MetadataRefreshMode.imagesOnly;
      final bio = details['biography'] as String?;

      await db.updatePersonBio(
        personId,
        tmdbPersonId: tmdbPersonId,
        photoPath: includeImages
            ? TmdbService.imageUrl(
                details['profile_path'] as String?,
                size: 'w300',
              )
            : null,
        biography: includeOtherFields && bio != null && bio.trim().isNotEmpty
            ? bio
            : null,
        birthday: includeOtherFields ? details['birthday'] as String? : null,
        placeOfBirth:
            includeOtherFields ? details['place_of_birth'] as String? : null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        networkErrors: state.networkErrors + 1,
        lastError: 'TMDB: $e',
      );
      return false;
    }
  }

  /// Bulk "Refresh Metadata" for people selected via multi-select on the
  /// People tab.
  Future<void> refreshMultiplePeople(
    List<int> personIds,
    MetadataRefreshMode mode,
  ) async {
    state = ScanState(
      status: ScanStatus.matching,
      total: personIds.length,
      processed: 0,
    );
    var matched = 0;
    for (var i = 0; i < personIds.length; i++) {
      final person = await db.getPersonById(personIds[i]);
      state = state.copyWith(currentItem: person?.name);
      final ok = await refreshPerson(personIds[i], mode: mode);
      if (ok) matched++;
      state = state.copyWith(processed: i + 1, matched: matched);
    }
    state = state.copyWith(status: ScanStatus.done);
  }
}

final scanControllerProvider =
    StateNotifierProvider<ScanController, ScanState>((ref) {
  final db = ref.watch(databaseProvider);
  return ScanController(db, ref);
});

// -----------------------------------------------------------------------
// Offline thumbnail backfill
// -----------------------------------------------------------------------
//
// One-off job (triggered from Settings) that fetches thumbnails for every
// movie/show that was already in the library before the offline-thumbnail
// feature existed. Ongoing scans/rematches pick up their own thumbnails
// automatically via ScanController; this just catches everything older.

class ThumbnailBackfillState {
  final bool running;
  final int total;
  final int processed;
  final int downloaded;

  const ThumbnailBackfillState({
    this.running = false,
    this.total = 0,
    this.processed = 0,
    this.downloaded = 0,
  });

  ThumbnailBackfillState copyWith({
    bool? running,
    int? total,
    int? processed,
    int? downloaded,
  }) {
    return ThumbnailBackfillState(
      running: running ?? this.running,
      total: total ?? this.total,
      processed: processed ?? this.processed,
      downloaded: downloaded ?? this.downloaded,
    );
  }
}

class ThumbnailBackfillController extends StateNotifier<ThumbnailBackfillState> {
  final AppDatabase db;

  ThumbnailBackfillController(this.db) : super(const ThumbnailBackfillState());

  Future<void> run() async {
    if (state.running) return;

    final movies = await db.getMoviesNeedingThumbnails();
    final shows = await db.getShowsNeedingThumbnails();
    state = ThumbnailBackfillState(
      running: true,
      total: movies.length + shows.length,
    );

    for (final movie in movies) {
      final results = await Future.wait([
        ThumbnailService.fetch(movie.posterPath),
        ThumbnailService.fetch(movie.backdropPath),
      ]);
      final poster = results[0];
      final backdrop = results[1];
      if (poster != null || backdrop != null) {
        try {
          await db.updateMovieThumbnails(
            movie.id,
            poster: poster,
            backdrop: backdrop,
          );
          state = state.copyWith(downloaded: state.downloaded + 1);
        } catch (_) {
          // Nice-to-have; keep going with the rest of the library.
        }
      }
      state = state.copyWith(processed: state.processed + 1);
    }

    for (final show in shows) {
      final results = await Future.wait([
        ThumbnailService.fetch(show.posterPath),
        ThumbnailService.fetch(show.backdropPath),
      ]);
      final poster = results[0];
      final backdrop = results[1];
      if (poster != null || backdrop != null) {
        try {
          await db.updateShowThumbnails(
            show.id,
            poster: poster,
            backdrop: backdrop,
          );
          state = state.copyWith(downloaded: state.downloaded + 1);
        } catch (_) {
          // Nice-to-have; keep going with the rest of the library.
        }
      }
      state = state.copyWith(processed: state.processed + 1);
    }

    state = state.copyWith(running: false);
  }
}

final thumbnailBackfillProvider = StateNotifierProvider<
    ThumbnailBackfillController, ThumbnailBackfillState>((ref) {
  final db = ref.watch(databaseProvider);
  return ThumbnailBackfillController(db);
});

/// Given an already-built TMDB image URL (e.g. ".../t/p/w500/abc.jpg"),
/// swaps in TMDB's "original" size so a full-resolution copy can be
/// downloaded instead of the smaller display size normally used in the
/// app. URLs from other sources (e.g. an OMDb-sourced poster) are
/// returned as-is, since there's no general way to request a
/// higher-resolution version of those.
String _originalQualityUrl(String url) {
  if (!url.contains('image.tmdb.org')) return url;
  return url.replaceFirst(RegExp(r'/t/p/[^/]+/'), '/t/p/original/');
}

class OriginalImageDownloadState {
  final bool running;
  final int total;
  final int processed;
  final int saved;
  final int failed;

  const OriginalImageDownloadState({
    this.running = false,
    this.total = 0,
    this.processed = 0,
    this.saved = 0,
    this.failed = 0,
  });

  OriginalImageDownloadState copyWith({
    bool? running,
    int? total,
    int? processed,
    int? saved,
    int? failed,
  }) {
    return OriginalImageDownloadState(
      running: running ?? this.running,
      total: total ?? this.total,
      processed: processed ?? this.processed,
      saved: saved ?? this.saved,
      failed: failed ?? this.failed,
    );
  }
}

/// Downloads full-resolution poster/backdrop images and saves them as
/// poster.jpg / backdrop.jpg next to each movie's file or show's folder
/// -- unlike the small thumbnails cached in the database for offline
/// grid display, these are meant to be kept as real files (for use in
/// another app, backup, printing, etc).
class OriginalImageDownloadController
    extends StateNotifier<OriginalImageDownloadState> {
  final AppDatabase db;

  OriginalImageDownloadController(this.db)
      : super(const OriginalImageDownloadState());

  Future<void> run() async {
    if (state.running) return;

    final movies = await db.getAllMovies();
    final shows = await db.getAllShows();
    state = OriginalImageDownloadState(
      running: true,
      total: movies.length + shows.length,
    );

    for (final movie in movies) {
      final ok = await _saveOriginals(
        folderPath: movie.folderPath,
        posterUrl: movie.posterPath,
        backdropUrl: movie.backdropPath,
      );
      state = state.copyWith(
        processed: state.processed + 1,
        saved: state.saved + (ok ? 1 : 0),
        failed: state.failed + (ok ? 0 : 1),
      );
    }

    for (final show in shows) {
      final ok = await _saveOriginals(
        folderPath: show.folderPath,
        posterUrl: show.posterPath,
        backdropUrl: show.backdropPath,
      );
      state = state.copyWith(
        processed: state.processed + 1,
        saved: state.saved + (ok ? 1 : 0),
        failed: state.failed + (ok ? 0 : 1),
      );
    }

    state = state.copyWith(running: false);
  }

  /// Saves whichever of poster/backdrop are available; counts as "saved"
  /// if at least one of the two succeeded.
  Future<bool> _saveOriginals({
    required String folderPath,
    required String? posterUrl,
    required String? backdropUrl,
  }) async {
    var savedAny = false;
    if (posterUrl != null && posterUrl.isNotEmpty) {
      final ok = await _downloadTo(
        _originalQualityUrl(posterUrl),
        '$folderPath${Platform.pathSeparator}poster.jpg',
      );
      if (ok) savedAny = true;
    }
    if (backdropUrl != null && backdropUrl.isNotEmpty) {
      final ok = await _downloadTo(
        _originalQualityUrl(backdropUrl),
        '$folderPath${Platform.pathSeparator}backdrop.jpg',
      );
      if (ok) savedAny = true;
    }
    return savedAny;
  }

  Future<bool> _downloadTo(String url, String filePath) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return false;
      final directory = Directory(File(filePath).parent.path);
      if (!await directory.exists()) return false;
      await File(filePath).writeAsBytes(response.bodyBytes);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final originalImageDownloadProvider = StateNotifierProvider<
    OriginalImageDownloadController, OriginalImageDownloadState>((ref) {
  final db = ref.watch(databaseProvider);
  return OriginalImageDownloadController(db);
});
