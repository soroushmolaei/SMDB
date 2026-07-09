import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../services/library_scanner.dart';
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
  final String? proxyHost;
  final int? proxyPort;
  AppSettingsData({this.tmdbApiKey, this.proxyHost, this.proxyPort});
}

final appSettingsProvider = FutureProvider<AppSettingsData>((ref) async {
  final db = ref.watch(databaseProvider);
  final apiKey = await db.getSetting('tmdb_api_key');
  final proxyHost = await db.getSetting('proxy_host');
  final proxyPortStr = await db.getSetting('proxy_port');
  return AppSettingsData(
    tmdbApiKey: (apiKey != null && apiKey.isNotEmpty) ? apiKey : null,
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

// ---------------------------------------------------------------------------
// Scan controller
// ---------------------------------------------------------------------------

enum ScanStatus { idle, scanning, matching, done, error }

class ScanState {
  final ScanStatus status;
  final String? currentItem;
  final int processed;
  final int total;
  final String? error;

  const ScanState({
    this.status = ScanStatus.idle,
    this.currentItem,
    this.processed = 0,
    this.total = 0,
    this.error,
  });

  ScanState copyWith({
    ScanStatus? status,
    String? currentItem,
    int? processed,
    int? total,
    String? error,
  }) {
    return ScanState(
      status: status ?? this.status,
      currentItem: currentItem ?? this.currentItem,
      processed: processed ?? this.processed,
      total: total ?? this.total,
      error: error,
    );
  }
}

class ScanController extends StateNotifier<ScanState> {
  final AppDatabase db;
  final Ref ref;

  ScanController(this.db, this.ref) : super(const ScanState());

  Future<void> scanMovieFolder(String path) async {
    final tmdb = ref.read(tmdbServiceProvider);
    state = const ScanState(status: ScanStatus.scanning);

    final items = await LibraryScanner.scanMovies(path);
    state = state.copyWith(
      status: ScanStatus.matching,
      total: items.length,
      processed: 0,
    );

    for (final item in items) {
      state = state.copyWith(currentItem: item.title);
      try {
        int? tmdbId;
        String? overview, posterPath, backdropPath, genres, director;
        String? castNames;
        double? rating;
        int? runtime;

        if (tmdb != null) {
          final results = await tmdb.searchMovie(item.title, year: item.year);
          if (results.isNotEmpty) {
            final best = results.first;
            tmdbId = best.id;
            final details = await tmdb.getMovieDetails(best.id);
            overview = details['overview'] as String?;
            posterPath = details['poster_path'] as String?;
            backdropPath = details['backdrop_path'] as String?;
            rating = (details['vote_average'] as num?)?.toDouble();
            runtime = details['runtime'] as int?;

            final genreList = (details['genres'] as List<dynamic>?) ?? [];
            genres = genreList.map((g) => g['name']).join(', ');

            final credits = details['credits'] as Map<String, dynamic>?;
            if (credits != null) {
              final crew = (credits['crew'] as List<dynamic>?) ?? [];
              final directorEntry = crew.firstWhere(
                (c) => c['job'] == 'Director',
                orElse: () => null,
              );
              director =
                  directorEntry != null ? directorEntry['name'] as String? : null;

              final cast = (credits['cast'] as List<dynamic>?) ?? [];
              castNames = cast.take(6).map((c) => c['name']).join(', ');
            }
          }
        }

        await db.upsertMovie(MoviesCompanion.insert(
          title: item.title,
          filePath: item.filePath,
          folderPath: item.folderPath,
          year: Value(item.year),
          tmdbId: Value(tmdbId),
          overview: Value(overview),
          posterPath: Value(posterPath),
          backdropPath: Value(backdropPath),
          rating: Value(rating),
          runtimeMinutes: Value(runtime),
          genres: Value(genres),
          director: Value(director),
          castNames: Value(castNames),
        ));
      } catch (_) {
        // Skip items that fail to match/save; continue with the rest.
      }
      state = state.copyWith(processed: state.processed + 1);
    }

    state = state.copyWith(status: ScanStatus.done);
  }

  Future<void> scanShowFolder(String path) async {
    final tmdb = ref.read(tmdbServiceProvider);
    state = const ScanState(status: ScanStatus.scanning);

    final shows = await LibraryScanner.scanShows(path);
    state = state.copyWith(
      status: ScanStatus.matching,
      total: shows.length,
      processed: 0,
    );

    for (final show in shows) {
      state = state.copyWith(currentItem: show.title);
      try {
        int? tmdbId;
        String? overview, posterPath, backdropPath, genres, showStatus;
        double? rating;

        if (tmdb != null) {
          final results = await tmdb.searchTvShow(show.title);
          if (results.isNotEmpty) {
            final best = results.first;
            tmdbId = best.id;
            final details = await tmdb.getShowDetails(best.id);
            overview = details['overview'] as String?;
            posterPath = details['poster_path'] as String?;
            backdropPath = details['backdrop_path'] as String?;
            rating = (details['vote_average'] as num?)?.toDouble();
            showStatus = details['status'] as String?;
            final genreList = (details['genres'] as List<dynamic>?) ?? [];
            genres = genreList.map((g) => g['name']).join(', ');
          }
        }

        final showId = await db.upsertShow(ShowsCompanion.insert(
          title: show.title,
          folderPath: show.folderPath,
          tmdbId: Value(tmdbId),
          overview: Value(overview),
          posterPath: Value(posterPath),
          backdropPath: Value(backdropPath),
          rating: Value(rating),
          genres: Value(genres),
          status: Value(showStatus),
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
        // Skip shows that fail to match/save; continue with the rest.
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
