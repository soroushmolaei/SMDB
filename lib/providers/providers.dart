import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../services/app_config_service.dart';
import '../services/library_scanner.dart';
import '../services/omdb_service.dart';
import '../services/thumbnail_service.dart';
import '../services/tmdb_service.dart';
import '../services/wikidata_service.dart';
import '../theme/app_theme.dart';

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
  final List<MovieCreditInput> credits;

  _MovieMatch({
    this.tmdbId,
    this.imdbId,
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
    this.credits = const [],
  });
}

class _ShowMatch {
  final int? tmdbId;
  final String? imdbId;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final double? rating;
  final String? genres;
  final String? contentRating;
  final String? status;
  final List<MovieCreditInput> credits;

  _ShowMatch({
    this.tmdbId,
    this.imdbId,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.rating,
    this.genres,
    this.contentRating,
    this.status,
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

    for (final item in items) {
      state = state.copyWith(currentItem: item.title);

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
    final best = results.first;
    final details = await tmdb.getMovieDetails(best.id);

    final genreList = (details['genres'] as List<dynamic>?) ?? [];
    final genres = genreList.map((g) => g['name']).join(', ');
    final extracted =
        _extractTmdbCredits(details['credits'] as Map<String, dynamic>?);

    return _MovieMatch(
      tmdbId: best.id,
      imdbId: details['imdb_id'] as String?,
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

      int showId;
      try {
        showId = await db.upsertShow(ShowsCompanion.insert(
          title: show.title,
          folderPath: show.folderPath,
        ));
        for (final ep in show.episodes) {
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

      if (omdb != null) {
        try {
          final tmdbForEnrichment =
              _tmdbConsecutiveFailures < _tmdbCircuitBreakerThreshold
                  ? tmdb
                  : null;
          match = await _matchShowOmdb(omdb, tmdbForEnrichment, show.title);
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
          overview: Value(match.overview),
          posterPath: Value(match.posterPath),
          backdropPath: Value(match.backdropPath),
          rating: Value(match.rating),
          genres: Value(match.genres),
          contentRating: Value(match.contentRating),
          status: Value(match.status),
        ));
        try {
          await db.setShowCredits(showId, match.credits);
        } catch (_) {
          // Credits are a nice-to-have; don't fail the whole item over it.
        }
        unawaited(_saveShowThumbnails(showId, match));

        final seasonNumbers = show.episodes.map((e) => e.season).toSet();
        final tmdbForEpisodes =
            _tmdbConsecutiveFailures < _tmdbCircuitBreakerThreshold
                ? tmdb
                : null;
        try {
          await _enrichEpisodes(
            showId,
            seasonNumbers,
            tmdbId: match.tmdbId,
            imdbId: match.imdbId,
            tmdb: tmdbForEpisodes,
            omdb: omdb,
          );
        } catch (_) {
          // Episode-level enrichment is best-effort.
        }

        state = state.copyWith(matched: state.matched + 1);
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
      overview: OmdbService.cleanText(data['Plot'] as String?),
      posterPath: OmdbService.posterUrl(data['Poster'] as String?),
      backdropPath: backdropPath,
      rating: OmdbService.parseRating(data['imdbRating'] as String?),
      genres: OmdbService.cleanText(data['Genre'] as String?),
      contentRating: contentRating,
      status: statusText,
      credits: credits,
    );
  }

  Future<_ShowMatch?> _matchShowTmdb(TmdbService tmdb, String title) async {
    final results = await tmdb.searchTvShow(title);
    if (results.isEmpty) return null;
    final best = results.first;
    final details = await tmdb.getShowDetails(best.id);

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
      tmdbId: best.id,
      imdbId: externalIds?['imdb_id'] as String?,
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
  /// button on the movie detail screen), using its stored title/year.
  Future<bool> refreshMovie(int movieId) async {
    final movie = await db.getMovieById(movieId);
    if (movie == null) return false;
    final tmdb = ref.read(tmdbServiceProvider);
    final omdb = ref.read(omdbServiceProvider);

    state = ScanState(
      status: ScanStatus.matching,
      total: 1,
      processed: 0,
      currentItem: movie.title,
    );

    _MovieMatch? match;
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

    var success = false;
    final trailerPath = movie.trailerFilePath ??
        await LibraryScanner.findTrailerInFolder(
            movie.folderPath, movie.filePath);
    if (match != null) {
      await db.upsertMovie(MoviesCompanion.insert(
        title: movie.title,
        filePath: movie.filePath,
        folderPath: movie.folderPath,
        year: Value(movie.year),
        trailerFilePath: Value(trailerPath),
        tmdbId: Value(match.tmdbId),
          imdbId: Value(match.imdbId),
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
      ));
      try {
        await db.setMovieCredits(movieId, match.credits);
      } catch (_) {
        // Non-fatal.
      }
      unawaited(_saveMovieThumbnails(movieId, match));
      success = true;
    } else if (trailerPath != movie.trailerFilePath) {
      // Even if no metadata match was found, still save a newly detected
      // trailer.
      await db.updateMovieDetails(
        movieId,
        MoviesCompanion(trailerFilePath: Value(trailerPath)),
      );
    }

    state = state.copyWith(
      status: ScanStatus.done,
      processed: 1,
      matched: success ? 1 : 0,
    );
    return success;
  }

  /// Re-runs matching for a single already-scanned show, including
  /// re-enriching its episodes (the "Update" button on the show detail
  /// screen).
  Future<bool> refreshShow(int showId) async {
    final show = await db.getShowById(showId);
    if (show == null) return false;
    final tmdb = ref.read(tmdbServiceProvider);
    final omdb = ref.read(omdbServiceProvider);

    state = ScanState(
      status: ScanStatus.matching,
      total: 1,
      processed: 0,
      currentItem: show.title,
    );

    _ShowMatch? match;
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

    var success = false;
    if (match != null) {
      await db.upsertShow(ShowsCompanion.insert(
        title: show.title,
        folderPath: show.folderPath,
        tmdbId: Value(match.tmdbId),
          imdbId: Value(match.imdbId),
        overview: Value(match.overview),
        posterPath: Value(match.posterPath),
        backdropPath: Value(match.backdropPath),
        rating: Value(match.rating),
        genres: Value(match.genres),
        contentRating: Value(match.contentRating),
        status: Value(match.status),
      ));
      try {
        await db.setShowCredits(showId, match.credits);
      } catch (_) {
        // Non-fatal.
      }
      unawaited(_saveShowThumbnails(showId, match));

      try {
        final episodes = await db.getEpisodesForShowOnce(showId);
        final seasonNumbers = episodes.map((e) => e.seasonNumber).toSet();
        await _enrichEpisodes(
          showId,
          seasonNumbers,
          tmdbId: match.tmdbId,
          imdbId: match.imdbId,
          tmdb: tmdb,
          omdb: omdb,
        );
      } catch (_) {
        // Non-fatal.
      }
      success = true;
    }

    state = state.copyWith(
      status: ScanStatus.done,
      processed: 1,
      matched: success ? 1 : 0,
    );
    return success;
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
