import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../services/library_scanner.dart';
import '../services/omdb_service.dart';
import '../services/tmdb_service.dart';

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
  final db = ref.watch(databaseProvider);
  final apiKey = await db.getSetting('tmdb_api_key');
  final omdbKey = await db.getSetting('omdb_api_key');
  final proxyHost = await db.getSetting('proxy_host');
  final proxyPortStr = await db.getSetting('proxy_port');
  return AppSettingsData(
    tmdbApiKey: (apiKey != null && apiKey.isNotEmpty) ? apiKey : null,
    omdbApiKey: (omdbKey != null && omdbKey.isNotEmpty) ? omdbKey : null,
    proxyHost: (proxyHost != null && proxyHost.isNotEmpty) ? proxyHost : null,
    proxyPort:
        (proxyPortStr != null) ? int.tryParse(proxyPortStr) : null,
  );
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

// ---------------------------------------------------------------------------
// Scan controller
// ---------------------------------------------------------------------------

enum ScanStatus { idle, scanning, matching, done, error }

class ScanState {
  final ScanStatus status;
  final String? currentItem;
  final int processed;
  final int total;
  final int matched;
  final int networkErrors;
  final String? lastError;

  const ScanState({
    this.status = ScanStatus.idle,
    this.currentItem,
    this.processed = 0,
    this.total = 0,
    this.matched = 0,
    this.networkErrors = 0,
    this.lastError,
  });

  ScanState copyWith({
    ScanStatus? status,
    String? currentItem,
    int? processed,
    int? total,
    int? matched,
    int? networkErrors,
    String? lastError,
  }) {
    return ScanState(
      status: status ?? this.status,
      currentItem: currentItem ?? this.currentItem,
      processed: processed ?? this.processed,
      total: total ?? this.total,
      matched: matched ?? this.matched,
      networkErrors: networkErrors ?? this.networkErrors,
      lastError: lastError ?? this.lastError,
    );
  }
}

class _MovieMatch {
  final int? tmdbId;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final double? rating;
  final int? runtimeMinutes;
  final String? genres;
  final String? director;
  final String? writer;
  final String? castNames;

  _MovieMatch({
    this.tmdbId,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.rating,
    this.runtimeMinutes,
    this.genres,
    this.director,
    this.writer,
    this.castNames,
  });
}

class ScanController extends StateNotifier<ScanState> {
  final AppDatabase db;
  final Ref ref;

  ScanController(this.db, this.ref) : super(const ScanState());

  /// Holds extracted metadata regardless of which source it came from, so
  /// the main loop doesn't need to care which API supplied it.
  Future<void> scanMovieFolder(String path) async {
    final tmdb = ref.read(tmdbServiceProvider);
    final omdb = ref.read(omdbServiceProvider);
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

    for (final item in items) {
      state = state.copyWith(currentItem: item.title);

      // Always save the basic scanned info first, so the file shows up in
      // the library even if no metadata source is reachable.
      try {
        await db.upsertMovie(MoviesCompanion.insert(
          title: item.title,
          filePath: item.filePath,
          folderPath: item.folderPath,
          year: Value(item.year),
        ));
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
          match = await _matchMovieOmdb(omdb, item.title, item.year);
        } catch (e) {
          state = state.copyWith(
            networkErrors: state.networkErrors + 1,
            lastError: 'OMDb: $e',
          );
        }
      }

      if (match == null && tmdb != null) {
        try {
          match = await _matchMovieTmdb(tmdb, item.title, item.year);
        } catch (e) {
          state = state.copyWith(
            networkErrors: state.networkErrors + 1,
            lastError: 'TMDB: $e',
          );
        }
      }

      if (match != null) {
        await db.upsertMovie(MoviesCompanion.insert(
          title: item.title,
          filePath: item.filePath,
          folderPath: item.folderPath,
          year: Value(item.year),
          tmdbId: Value(match.tmdbId),
          overview: Value(match.overview),
          posterPath: Value(match.posterPath),
          backdropPath: Value(match.backdropPath),
          rating: Value(match.rating),
          runtimeMinutes: Value(match.runtimeMinutes),
          genres: Value(match.genres),
          director: Value(match.director),
          writer: Value(match.writer),
          castNames: Value(match.castNames),
        ));
        state = state.copyWith(matched: state.matched + 1);
      }

      state = state.copyWith(processed: state.processed + 1);
    }

    state = state.copyWith(status: ScanStatus.done);
  }

  Future<_MovieMatch?> _matchMovieOmdb(
    OmdbService omdb,
    String title,
    int? year,
  ) async {
    final data = await omdb.lookupMovie(title, year: year);
    if (data == null) return null;
    return _MovieMatch(
      overview: OmdbService.cleanText(data['Plot'] as String?),
      posterPath: OmdbService.posterUrl(data['Poster'] as String?),
      rating: OmdbService.parseRating(data['imdbRating'] as String?),
      runtimeMinutes:
          OmdbService.parseRuntimeMinutes(data['Runtime'] as String?),
      genres: OmdbService.cleanText(data['Genre'] as String?),
      director: OmdbService.cleanText(data['Director'] as String?),
      writer: OmdbService.cleanText(data['Writer'] as String?),
      castNames: OmdbService.cleanText(data['Actors'] as String?),
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

    String? director;
    String? writer;
    String? castNames;
    final credits = details['credits'] as Map<String, dynamic>?;
    if (credits != null) {
      final crew = (credits['crew'] as List<dynamic>?) ?? [];
      final directorEntry = crew.firstWhere(
        (c) => c['job'] == 'Director',
        orElse: () => null,
      );
      director =
          directorEntry != null ? directorEntry['name'] as String? : null;

      final writerEntry = crew.firstWhere(
        (c) =>
            c['job'] == 'Writer' ||
            c['job'] == 'Screenplay' ||
            c['job'] == 'Author',
        orElse: () => null,
      );
      writer = writerEntry != null ? writerEntry['name'] as String? : null;

      final cast = (credits['cast'] as List<dynamic>?) ?? [];
      castNames = cast.take(6).map((c) => c['name']).join(', ');
    }

    return _MovieMatch(
      tmdbId: best.id,
      overview: details['overview'] as String?,
      posterPath: TmdbService.imageUrl(details['poster_path'] as String?),
      backdropPath: TmdbService.imageUrl(
        details['backdrop_path'] as String?,
        size: 'w1280',
      ),
      rating: (details['vote_average'] as num?)?.toDouble(),
      runtimeMinutes: details['runtime'] as int?,
      genres: genres,
      director: director,
      writer: writer,
      castNames: castNames,
    );
  }

  Future<void> scanShowFolder(String path) async {
    final tmdb = ref.read(tmdbServiceProvider);
    final omdb = ref.read(omdbServiceProvider);
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

      var matchedThisItem = false;

      if (omdb != null) {
        try {
          final data = await omdb.lookupShow(show.title);
          if (data != null) {
            final totalSeasons = data['totalSeasons'];
            final statusText = (data['Status'] as String?) ??
                (totalSeasons != null ? '$totalSeasons seasons' : null);
            await db.upsertShow(ShowsCompanion.insert(
              title: show.title,
              folderPath: show.folderPath,
              overview: Value(OmdbService.cleanText(data['Plot'] as String?)),
              posterPath:
                  Value(OmdbService.posterUrl(data['Poster'] as String?)),
              rating: Value(
                  OmdbService.parseRating(data['imdbRating'] as String?)),
              genres: Value(OmdbService.cleanText(data['Genre'] as String?)),
              status: Value(statusText),
            ));
            matchedThisItem = true;
            state = state.copyWith(matched: state.matched + 1);
          }
        } catch (e) {
          state = state.copyWith(
            networkErrors: state.networkErrors + 1,
            lastError: 'OMDb: $e',
          );
        }
      }

      if (!matchedThisItem && tmdb != null) {
        try {
          final results = await tmdb.searchTvShow(show.title);
          if (results.isNotEmpty) {
            final best = results.first;
            final details = await tmdb.getShowDetails(best.id);
            final overview = details['overview'] as String?;
            final posterPath = details['poster_path'] as String?;
            final backdropPath = details['backdrop_path'] as String?;
            final rating = (details['vote_average'] as num?)?.toDouble();
            final showStatus = details['status'] as String?;
            final genreList = (details['genres'] as List<dynamic>?) ?? [];
            final genres = genreList.map((g) => g['name']).join(', ');

            await db.upsertShow(ShowsCompanion.insert(
              title: show.title,
              folderPath: show.folderPath,
              tmdbId: Value(best.id),
              overview: Value(overview),
              posterPath: Value(TmdbService.imageUrl(posterPath)),
              backdropPath:
                  Value(TmdbService.imageUrl(backdropPath, size: 'w1280')),
              rating: Value(rating),
              genres: Value(genres),
              status: Value(showStatus),
            ));
            matchedThisItem = true;
            state = state.copyWith(matched: state.matched + 1);
          }
        } catch (e) {
          state = state.copyWith(
            networkErrors: state.networkErrors + 1,
            lastError: 'TMDB: $e',
          );
        }
      }

      state = state.copyWith(processed: state.processed + 1);
    }

    state = state.copyWith(status: ScanStatus.done);
  }
}

final scanControllerProvider =
    StateNotifierProvider<ScanController, ScanState>((ref) {
  final db = ref.watch(databaseProvider);
  return ScanController(db, ref);
});
