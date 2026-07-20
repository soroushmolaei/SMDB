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
  TextColumn get imdbId => text().nullable()();
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
  TextColumn get trailerFilePath => text().nullable()();
  TextColumn get folderPath => text()();
  DateTimeColumn get dateAdded => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get watched => boolean().withDefault(const Constant(false))();
  DateTimeColumn get watchedDate => dateTime().nullable()();
  RealColumn get personalRating => real().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get awardsChecked =>
      boolean().withDefault(const Constant(false))();
}

@DataClassName('Show')
class Shows extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get originalTitle => text().nullable()();
  IntColumn get tmdbId => integer().nullable()();
  TextColumn get imdbId => text().nullable()();
  TextColumn get overview => text().nullable()();
  TextColumn get posterPath => text().nullable()();
  TextColumn get backdropPath => text().nullable()();
  RealColumn get rating => real().nullable()();
  TextColumn get genres => text().nullable()();
  TextColumn get contentRating => text().nullable()(); // e.g. TV-14, TV-MA
  TextColumn get status => text().nullable()();
  TextColumn get folderPath => text()();
  DateTimeColumn get dateAdded => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get awardsChecked =>
      boolean().withDefault(const Constant(false))();
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
  RealColumn get rating => real().nullable()();
  TextColumn get guestStars => text().nullable()(); // comma separated
  TextColumn get filePath => text()();
  BoolColumn get watched => boolean().withDefault(const Constant(false))();
  DateTimeColumn get watchedDate => dateTime().nullable()();
}

@DataClassName('Person')
class People extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get photoPath => text().nullable()();
  IntColumn get tmdbPersonId => integer().nullable()();
  TextColumn get biography => text().nullable()();
  TextColumn get birthday => text().nullable()();
  TextColumn get placeOfBirth => text().nullable()();
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

@DataClassName('EpisodeCredit')
class EpisodeCredits extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get episodeId => integer().references(Episodes, #id)();
  IntColumn get personId => integer().references(People, #id)();
  TextColumn get character => text().nullable()(); // guest star role
}

@DataClassName('AppSetting')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('Collection')
class Collections extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get dateCreated =>
      dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('CollectionMovie')
class CollectionMovies extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get collectionId => integer().references(Collections, #id)();
  IntColumn get movieId => integer().references(Movies, #id)();
}

@DataClassName('CollectionShow')
class CollectionShows extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get collectionId => integer().references(Collections, #id)();
  IntColumn get showId => integer().references(Shows, #id)();
}

/// One award/nomination for a movie or show, sourced from Wikidata (looked
/// up by IMDb id, lazily when the detail page is opened — TMDB/OMDb do not
/// provide structured award data). [itemType] is 'movie' or 'show';
/// [itemId] is the corresponding Movies/Shows row id. Not a foreign key
/// since it can point to either table.
@DataClassName('Award')
class Awards extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get itemType => text()(); // 'movie' or 'show'
  IntColumn get itemId => integer()();
  TextColumn get name => text()(); // e.g. "Academy Award for Best Picture"
  TextColumn get result => text()(); // 'Won' or 'Nominated'
  IntColumn get year => integer().nullable()();
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

/// Plain input for [AppDatabase.setAwardsFor].
class AwardInput {
  final String name;
  final String result; // 'Won' or 'Nominated'
  final int? year;
  AwardInput({required this.name, required this.result, this.year});
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
    EpisodeCredits,
    Collections,
    CollectionMovies,
    CollectionShows,
    Awards,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 10;

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
          if (from < 6) {
            await m.addColumn(movies, movies.imdbId);
            await m.addColumn(movies, movies.isFavorite);
            await m.addColumn(shows, shows.imdbId);
            await m.addColumn(shows, shows.isFavorite);
          }
          if (from < 7) {
            await m.addColumn(movies, movies.trailerFilePath);
          }
          if (from < 8) {
            await m.addColumn(people, people.tmdbPersonId);
            await m.addColumn(people, people.biography);
            await m.addColumn(people, people.birthday);
            await m.addColumn(people, people.placeOfBirth);
          }
          if (from < 9) {
            await m.addColumn(episodes, episodes.rating);
            await m.addColumn(episodes, episodes.guestStars);
            await m.createTable(collections);
            await m.createTable(collectionMovies);
            await m.createTable(collectionShows);
          }
          if (from < 10) {
            await m.createTable(episodeCredits);
            await m.createTable(awards);
            await m.addColumn(movies, movies.awardsChecked);
            await m.addColumn(shows, shows.awardsChecked);
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

  Future<Movie?> getMovieById(int id) =>
      (select(movies)..where((m) => m.id.equals(id))).getSingleOrNull();

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

  Future<void> setMovieFavorite(int id, bool favorite) =>
      (update(movies)..where((m) => m.id.equals(id)))
          .write(MoviesCompanion(isFavorite: Value(favorite)));

  Future<void> setShowFavorite(int id, bool favorite) =>
      (update(shows)..where((s) => s.id.equals(id)))
          .write(ShowsCompanion(isFavorite: Value(favorite)));

  /// Applies an arbitrary set of field edits to an existing movie (used by
  /// the manual edit screen). Only fields set on [data] are changed.
  Future<void> updateMovieDetails(int id, MoviesCompanion data) =>
      (update(movies)..where((m) => m.id.equals(id))).write(data);

  Future<void> deleteMovie(int id) async {
    await (delete(movieCredits)..where((c) => c.movieId.equals(id))).go();
    await (delete(collectionMovies)..where((c) => c.movieId.equals(id))).go();
    await (delete(movies)..where((m) => m.id.equals(id))).go();
  }

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

  /// Fills in biography/birthday/place-of-birth/photo for a person, found
  /// lazily (only when their detail page is opened) rather than during
  /// bulk scanning, to avoid a large number of extra API calls per movie.
  Future<void> updatePersonBio(
    int personId, {
    int? tmdbPersonId,
    String? photoPath,
    String? biography,
    String? birthday,
    String? placeOfBirth,
  }) =>
      (update(people)..where((p) => p.id.equals(personId))).write(
        PeopleCompanion(
          tmdbPersonId: tmdbPersonId != null
              ? Value(tmdbPersonId)
              : const Value.absent(),
          photoPath:
              photoPath != null ? Value(photoPath) : const Value.absent(),
          biography:
              biography != null ? Value(biography) : const Value.absent(),
          birthday:
              birthday != null ? Value(birthday) : const Value.absent(),
          placeOfBirth: placeOfBirth != null
              ? Value(placeOfBirth)
              : const Value.absent(),
        ),
      );

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

  Future<Show?> getShowById(int id) =>
      (select(shows)..where((s) => s.id.equals(id))).getSingleOrNull();

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

  Stream<List<Episode>> watchAllEpisodes() => select(episodes).watch();

  Future<List<Episode>> getEpisodesForShowOnce(int showId) =>
      (select(episodes)..where((e) => e.showId.equals(showId))).get();

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
  /// (title, overview, air date, thumbnail, rating, guest stars), matched
  /// by season/episode number within a show.
  Future<void> updateEpisodeMetadata(
    int showId,
    int seasonNumber,
    int episodeNumber, {
    String? title,
    String? overview,
    String? airDate,
    String? stillPath,
    double? rating,
    String? guestStars,
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
      rating: Value(rating),
      guestStars: Value(guestStars),
    ));
  }

  /// Applies arbitrary field edits to an existing show.
  Future<void> updateShowDetails(int id, ShowsCompanion data) =>
      (update(shows)..where((s) => s.id.equals(id))).write(data);

  /// Deletes a show along with its episodes and cast/crew links.
  Future<void> deleteShow(int id) async {
    await (delete(episodes)..where((e) => e.showId.equals(id))).go();
    await (delete(showCredits)..where((c) => c.showId.equals(id))).go();
    await (delete(collectionShows)..where((c) => c.showId.equals(id))).go();
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

  // --- Episode credits (guest stars) ----------------------------------------

  Stream<List<EpisodeCredit>> watchEpisodeCredits(int episodeId) =>
      (select(episodeCredits)..where((c) => c.episodeId.equals(episodeId)))
          .watch();

  Future<int?> getEpisodeId(
    int showId,
    int seasonNumber,
    int episodeNumber,
  ) async {
    final row = await (select(episodes)
          ..where((e) =>
              e.showId.equals(showId) &
              e.seasonNumber.equals(seasonNumber) &
              e.episodeNumber.equals(episodeNumber)))
        .getSingleOrNull();
    return row?.id;
  }

  /// Replaces all guest-star credits for [episodeId] (find-or-create the
  /// person for each, then link). Safe to call on re-scan.
  Future<void> setEpisodeCredits(
    int episodeId,
    List<MovieCreditInput> credits,
  ) async {
    await (delete(episodeCredits)
          ..where((c) => c.episodeId.equals(episodeId)))
        .go();
    for (final credit in credits) {
      if (credit.name.trim().isEmpty) continue;
      final personId = await findOrCreatePerson(
        credit.name,
        photoPath: credit.photoPath,
      );
      await into(episodeCredits).insert(EpisodeCreditsCompanion.insert(
        episodeId: episodeId,
        personId: personId,
        character: Value(credit.character),
      ));
    }
  }

  // --- Collections (custom groups) -----------------------------------------

  Stream<List<Collection>> watchAllCollections() =>
      (select(collections)
            ..orderBy([(c) => OrderingTerm(expression: c.name)]))
          .watch();

  Future<int> createCollection(String name) => into(collections).insert(
        CollectionsCompanion.insert(name: name.trim()),
      );

  Future<void> renameCollection(int id, String name) =>
      (update(collections)..where((c) => c.id.equals(id)))
          .write(CollectionsCompanion(name: Value(name.trim())));

  Future<void> deleteCollection(int id) async {
    await (delete(collectionMovies)..where((c) => c.collectionId.equals(id)))
        .go();
    await (delete(collectionShows)..where((c) => c.collectionId.equals(id)))
        .go();
    await (delete(collections)..where((c) => c.id.equals(id))).go();
  }

  Stream<List<CollectionMovie>> watchCollectionMovieLinks(int collectionId) =>
      (select(collectionMovies)
            ..where((c) => c.collectionId.equals(collectionId)))
          .watch();

  Stream<List<CollectionShow>> watchCollectionShowLinks(int collectionId) =>
      (select(collectionShows)
            ..where((c) => c.collectionId.equals(collectionId)))
          .watch();

  Future<bool> isMovieInCollection(int collectionId, int movieId) async {
    final row = await (select(collectionMovies)
          ..where((c) =>
              c.collectionId.equals(collectionId) &
              c.movieId.equals(movieId)))
        .getSingleOrNull();
    return row != null;
  }

  Future<void> addMovieToCollection(int collectionId, int movieId) async {
    final exists = await isMovieInCollection(collectionId, movieId);
    if (exists) return;
    await into(collectionMovies).insert(
      CollectionMoviesCompanion.insert(
        collectionId: collectionId,
        movieId: movieId,
      ),
    );
  }

  Future<void> removeMovieFromCollection(
    int collectionId,
    int movieId,
  ) =>
      (delete(collectionMovies)
            ..where((c) =>
                c.collectionId.equals(collectionId) &
                c.movieId.equals(movieId)))
          .go();

  Future<bool> isShowInCollection(int collectionId, int showId) async {
    final row = await (select(collectionShows)
          ..where((c) =>
              c.collectionId.equals(collectionId) & c.showId.equals(showId)))
        .getSingleOrNull();
    return row != null;
  }

  Future<void> addShowToCollection(int collectionId, int showId) async {
    final exists = await isShowInCollection(collectionId, showId);
    if (exists) return;
    await into(collectionShows).insert(
      CollectionShowsCompanion.insert(
        collectionId: collectionId,
        showId: showId,
      ),
    );
  }

  Future<void> removeShowFromCollection(int collectionId, int showId) =>
      (delete(collectionShows)
            ..where((c) =>
                c.collectionId.equals(collectionId) & c.showId.equals(showId)))
          .go();

  // --- Awards (lazily fetched from Wikidata) --------------------------------

  Stream<List<Award>> watchAwardsFor(String itemType, int itemId) =>
      (select(awards)
            ..where((a) =>
                a.itemType.equals(itemType) & a.itemId.equals(itemId)))
          .watch();

  Future<bool> hasAwardsFetched(String itemType, int itemId) async {
    if (itemType == 'movie') {
      final movie = await getMovieById(itemId);
      return movie?.awardsChecked ?? true;
    } else {
      final show = await getShowById(itemId);
      return show?.awardsChecked ?? true;
    }
  }

  Future<void> markAwardsChecked(String itemType, int itemId) async {
    if (itemType == 'movie') {
      await (update(movies)..where((m) => m.id.equals(itemId)))
          .write(MoviesCompanion(awardsChecked: Value(true)));
    } else {
      await (update(shows)..where((s) => s.id.equals(itemId)))
          .write(ShowsCompanion(awardsChecked: Value(true)));
    }
  }

  /// Replaces all awards for a movie/show. Called at most once per item
  /// (lazily, when its detail page is first opened) since award data
  /// rarely changes and Wikidata lookups are relatively slow.
  Future<void> setAwardsFor(
    String itemType,
    int itemId,
    List<AwardInput> items,
  ) async {
    await (delete(awards)
          ..where((a) =>
              a.itemType.equals(itemType) & a.itemId.equals(itemId)))
        .go();
    for (final award in items) {
      await into(awards).insert(AwardsCompanion.insert(
        itemType: itemType,
        itemId: itemId,
        name: award.name,
        result: award.result,
        year: Value(award.year),
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
