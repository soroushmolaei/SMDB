import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

part 'database.g.dart';

// ---------------------------------------------------------------------------
// Tables
// ---------------------------------------------------------------------------

/// A root folder on disk that the user has added as a movie or show library.
@DataClassName('LibraryFolder')
class LibraryFolders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text()();
  TextColumn get type => text()(); // 'movie' or 'show'
  DateTimeColumn get lastScanned => dateTime().nullable()();
}

@DataClassName('Movie')
class Movies extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get originalTitle => text().nullable()();
  IntColumn get year => integer().nullable()();
  IntColumn get tmdbId => integer().nullable()();
  TextColumn get overview => text().nullable()();
  TextColumn get posterPath => text().nullable()();
  TextColumn get backdropPath => text().nullable()();
  RealColumn get rating => real().nullable()();
  IntColumn get runtimeMinutes => integer().nullable()();
  TextColumn get genres => text().nullable()(); // comma separated
  TextColumn get director => text().nullable()();
  TextColumn get writer => text().nullable()();
  TextColumn get castNames => text().nullable()(); // comma separated
  TextColumn get filePath => text()();
  TextColumn get folderPath => text()();
  DateTimeColumn get dateAdded => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get watched => boolean().withDefault(const Constant(false))();
  DateTimeColumn get watchedDate => dateTime().nullable()();
  RealColumn get personalRating => real().nullable()();
}

@DataClassName('Show')
class Shows extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get originalTitle => text().nullable()();
  IntColumn get tmdbId => integer().nullable()();
  TextColumn get overview => text().nullable()();
  TextColumn get posterPath => text().nullable()();
  TextColumn get backdropPath => text().nullable()();
  RealColumn get rating => real().nullable()();
  TextColumn get genres => text().nullable()();
  TextColumn get status => text().nullable()();
  TextColumn get folderPath => text()();
  DateTimeColumn get dateAdded => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Episode')
class Episodes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get showId => integer().references(Shows, #id)();
  IntColumn get seasonNumber => integer()();
  IntColumn get episodeNumber => integer()();
  TextColumn get title => text().nullable()();
  TextColumn get overview => text().nullable()();
  TextColumn get airDate => text().nullable()();
  TextColumn get stillPath => text().nullable()();
  TextColumn get filePath => text()();
  BoolColumn get watched => boolean().withDefault(const Constant(false))();
  DateTimeColumn get watchedDate => dateTime().nullable()();
}

@DataClassName('AppSetting')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

@DriftDatabase(tables: [LibraryFolders, Movies, Shows, Episodes, AppSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.addColumn(movies, movies.writer);
          }
        },
      );

  // --- Folders -------------------------------------------------------------

  Stream<List<LibraryFolder>> watchAllFolders() =>
      select(libraryFolders).watch();

  Future<int> addFolder(String path, String type) {
    return into(libraryFolders)
        .insert(LibraryFoldersCompanion.insert(path: path, type: type));
  }

  Future<void> removeFolder(int id) =>
      (delete(libraryFolders)..where((f) => f.id.equals(id))).go();

  Future<void> touchFolderScanTime(int id) =>
      (update(libraryFolders)..where((f) => f.id.equals(id))).write(
        LibraryFoldersCompanion(lastScanned: Value(DateTime.now())),
      );

  // --- Movies ----------------------------------------------------------------

  Stream<List<Movie>> watchAllMovies() =>
      (select(movies)..orderBy([(m) => OrderingTerm(expression: m.title)]))
          .watch();

  Future<Movie?> getMovieByFilePath(String filePath) =>
      (select(movies)..where((m) => m.filePath.equals(filePath)))
          .getSingleOrNull();

  /// Inserts a new movie, or updates the existing row for the same file path.
  Future<void> upsertMovie(MoviesCompanion movie) async {
    final path = movie.filePath.value;
    final existing = await getMovieByFilePath(path);
    if (existing != null) {
      await (update(movies)..where((m) => m.id.equals(existing.id)))
          .write(movie);
    } else {
      await into(movies).insert(movie);
    }
  }

  Future<void> setMovieWatched(int id, bool watched) =>
      (update(movies)..where((m) => m.id.equals(id))).write(
        MoviesCompanion(
          watched: Value(watched),
          watchedDate: Value(watched ? DateTime.now() : null),
        ),
      );

  Future<void> setPersonalRating(int id, double? rating) =>
      (update(movies)..where((m) => m.id.equals(id)))
          .write(MoviesCompanion(personalRating: Value(rating)));

  /// Applies an arbitrary set of field edits to an existing movie (used by
  /// the manual edit screen). Only fields set on [data] are changed.
  Future<void> updateMovieDetails(int id, MoviesCompanion data) =>
      (update(movies)..where((m) => m.id.equals(id))).write(data);

  Future<void> deleteMovie(int id) =>
      (delete(movies)..where((m) => m.id.equals(id))).go();

  // --- Shows & Episodes --------------------------------------------------

  Stream<List<Show>> watchAllShows() =>
      (select(shows)..orderBy([(s) => OrderingTerm(expression: s.title)]))
          .watch();

  Future<Show?> getShowByFolderPath(String folderPath) =>
      (select(shows)..where((s) => s.folderPath.equals(folderPath)))
          .getSingleOrNull();

  /// Inserts a new show, or updates the existing row for the same folder
  /// path. Returns the row id either way.
  Future<int> upsertShow(ShowsCompanion show) async {
    final path = show.folderPath.value;
    final existing = await getShowByFolderPath(path);
    if (existing != null) {
      await (update(shows)..where((s) => s.id.equals(existing.id)))
          .write(show);
      return existing.id;
    } else {
      return into(shows).insert(show);
    }
  }

  Stream<List<Episode>> watchEpisodesForShow(int showId) =>
      (select(episodes)
            ..where((e) => e.showId.equals(showId))
            ..orderBy([
              (e) => OrderingTerm(expression: e.seasonNumber),
              (e) => OrderingTerm(expression: e.episodeNumber),
            ]))
          .watch();

  Future<Episode?> getEpisodeByFilePath(String filePath) =>
      (select(episodes)..where((e) => e.filePath.equals(filePath)))
          .getSingleOrNull();

  Future<void> upsertEpisode(EpisodesCompanion episode) async {
    final path = episode.filePath.value;
    final existing = await getEpisodeByFilePath(path);
    if (existing != null) {
      await (update(episodes)..where((e) => e.id.equals(existing.id)))
          .write(episode);
    } else {
      await into(episodes).insert(episode);
    }
  }

  Future<void> setEpisodeWatched(int id, bool watched) =>
      (update(episodes)..where((e) => e.id.equals(id))).write(
        EpisodesCompanion(
          watched: Value(watched),
          watchedDate: Value(watched ? DateTime.now() : null),
        ),
      );

  // --- Settings ------------------------------------------------------------

  Future<String?> getSetting(String key) async {
    final row = await (select(appSettings)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) async {
    await into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: key, value: value),
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final smdbFolder = Directory(p.join(dbFolder.path, 'SMDB'));
    if (!await smdbFolder.exists()) {
      await smdbFolder.create(recursive: true);
    }
    final file = File(p.join(smdbFolder.path, 'library.sqlite'));

    // sqlite3 needs a writable temp directory; the default one may not be
    // accessible in some sandboxed environments.
    final cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    return NativeDatabase.createInBackground(file);
  });
}
