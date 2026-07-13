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
  TextColumn get contentRating => text().nullable()(); // e.g. PG-13, R
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
  TextColumn get contentRating => text().nullable()(); // e.g. TV-14, TV-MA
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

@DataClassName('Person')
class People extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get photoPath => text().nullable()();
}

@DataClassName('MovieCredit')
class MovieCredits extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get movieId => integer().references(Movies, #id)();
  IntColumn get personId => integer().references(People, #id)();
  TextColumn get role => text()(); // 'actor' | 'director' | 'writer'
  TextColumn get character => text().nullable()();
}

@DataClassName('ShowCredit')
class ShowCredits extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get showId => integer().references(Shows, #id)();
  IntColumn get personId => integer().references(People, #id)();
  TextColumn get role => text()(); // 'actor' | 'creator'
  TextColumn get character => text().nullable()();
}

@DataClassName('AppSetting')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Plain input for [AppDatabase.setMovieCredits] — not a table, just a
/// transfer object from the scanner/matcher to the database layer.
class MovieCreditInput {
  final String name;
  final String role;
  final String? character;
  final String? photoPath;
  MovieCreditInput({
    required this.name,
    required this.role,
    this.character,
    this.photoPath,
  });
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

@DriftDatabase(
  tables: [
    LibraryFolders,
    Movies,
    Shows,
    Episodes,
    AppSettings,
    People,
    MovieCredits,
    ShowCredits,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.addColumn(movies, movies.writer);
          }
          if (from < 3) {
            await m.createTable(people);
            await m.createTable(movieCredits);
          }
          if (from < 4) {
            await m.addColumn(movies, movies.contentRating);
          }
          if (from < 5) {
            await m.addColumn(shows, shows.contentRating);
            await m.createTable(showCredits);
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

  /// Inserts a new movie, or updates the existing row for the same file
  /// path. Returns the row id either way.
  Future<int> upsertMovie(MoviesCompanion movie) async {
    final path = movie.filePath.value;
    final existing = await getMovieByFilePath(path);
    if (existing != null) {
      await (update(movies)..where((m) => m.id.equals(existing.id)))
          .write(movie);
      return existing.id;
    } else {
      return into(movies).insert(movie);
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

  // --- People & credits ------------------------------------------------

  Stream<List<Person>> watchAllPeople() => select(people).watch();

  Stream<List<MovieCredit>> watchAllCredits() => select(movieCredits).watch();

  Future<List<MovieCredit>> getCreditsForMovie(int movieId) =>
      (select(movieCredits)..where((c) => c.movieId.equals(movieId))).get();

  Future<List<MovieCredit>> getCreditsForPerson(int personId) =>
      (select(movieCredits)..where((c) => c.personId.equals(personId))).get();

  Future<int> findOrCreatePerson(String name, {String? photoPath}) async {
    final trimmed = name.trim();
    final existing =
        await (select(people)..where((p) => p.name.equals(trimmed)))
            .getSingleOrNull();
    if (existing != null) {
      if (photoPath != null && existing.photoPath == null) {
        await (update(people)..where((p) => p.id.equals(existing.id)))
            .write(PeopleCompanion(photoPath: Value(photoPath)));
      }
      return existing.id;
    }
    return into(people).insert(
      PeopleCompanion.insert(name: trimmed, photoPath: Value(photoPath)),
    );
  }

  /// Replaces all credits for [movieId] with [credits] (find-or-create the
  /// person for each, then link). Safe to call on re-scan.
  Future<void> setMovieCredits(
    int movieId,
    List<MovieCreditInput> credits,
  ) async {
    await (delete(movieCredits)..where((c) => c.movieId.equals(movieId)))
        .go();
    for (final credit in credits) {
      if (credit.name.trim().isEmpty) continue;
      final personId = await findOrCreatePerson(
        credit.name,
        photoPath: credit.photoPath,
      );
      await into(movieCredits).insert(MovieCreditsCompanion.insert(
        movieId: movieId,
        personId: personId,
        role: credit.role,
        character: Value(credit.character),
      ));
    }
  }

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

  /// Fills in rich per-episode metadata found after the initial file scan
  /// (title, overview, air date, thumbnail), matched by season/episode
  /// number within a show.
  Future<void> updateEpisodeMetadata(
    int showId,
    int seasonNumber,
    int episodeNumber, {
    String? title,
    String? overview,
    String? airDate,
    String? stillPath,
  }) async {
    await (update(episodes)
          ..where((e) =>
              e.showId.equals(showId) &
              e.seasonNumber.equals(seasonNumber) &
              e.episodeNumber.equals(episodeNumber)))
        .write(EpisodesCompanion(
      title: Value(title),
      overview: Value(overview),
      airDate: Value(airDate),
      stillPath: Value(stillPath),
    ));
  }

  /// Applies arbitrary field edits to an existing show.
  Future<void> updateShowDetails(int id, ShowsCompanion data) =>
      (update(shows)..where((s) => s.id.equals(id))).write(data);

  /// Deletes a show along with its episodes and cast/crew links.
  Future<void> deleteShow(int id) async {
    await (delete(episodes)..where((e) => e.showId.equals(id))).go();
    await (delete(showCredits)..where((c) => c.showId.equals(id))).go();
    await (delete(shows)..where((s) => s.id.equals(id))).go();
  }

  Stream<List<ShowCredit>> watchAllShowCredits() =>
      select(showCredits).watch();

  /// Replaces all credits for [showId] with [credits] (find-or-create the
  /// person for each, then link). Safe to call on re-scan.
  Future<void> setShowCredits(
    int showId,
    List<MovieCreditInput> credits,
  ) async {
    await (delete(showCredits)..where((c) => c.showId.equals(showId))).go();
    for (final credit in credits) {
      if (credit.name.trim().isEmpty) continue;
      final personId = await findOrCreatePerson(
        credit.name,
        photoPath: credit.photoPath,
      );
      await into(showCredits).insert(ShowCreditsCompanion.insert(
        showId: showId,
        personId: personId,
        role: credit.role,
        character: Value(credit.character),
      ));
    }
  }

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
