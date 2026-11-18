# SMDB

A personal, local movie & TV show library manager for Windows — an
alternative to the discontinued Movie Label. Point it at your hard drive,
and it scans your folders, matches titles against TMDB, and gives you a
poster-grid library with watch-status tracking. Everything is stored
locally (SQLite); nothing is uploaded anywhere.

## What it does

**Library & scanning**
- Add a folder and scan it for movies (`Movie Name (Year)/file.mkv` or
  loose video files) and TV shows (show → season/episode files)
- Filename parsing for titles, years (`The.Matrix.1999.1080p` →
  “The Matrix”, 1999) and episodes (`S01E02`, `1x02`)
- Auto-match against TMDB for poster, backdrop, overview, cast,
  director/writers, rating, runtime, genres, original title and
  language, and content rating (MPA)
- Optional OMDb lookup and awards from Wikidata
- Duplicate detection on scan, with a prompt to keep or skip
- Scan exclusions: skip folders you do not want indexed

**Browsing & discovery**
- Poster-grid library with global search, watched/unwatched and
  favorites filters, and per-item personal ratings
- Movie and show detail screens, including season/episode browsing
  and per-episode watched toggles, cast/credits, and watch history
- People pages with biographies and shared filmography
  (e.g. films two people made together)
- Browse by genre, language, content rating, and year (timeline
  histogram + range filter)
- Advanced filter: combine type, genre, year, language, content
  rating, rating and people on one page — every filter is
  multi-select
- Collections / groups, A–Z alphabet index on list pages, and
  sort-exclusion words (so “The Matrix” sorts under M, not T)
- Statistics view for the library

**Editing & maintenance**
- Edit movie/show metadata by hand and manually re-match a wrong
  TMDB match from the edit screens
- Refresh metadata (full, without poster/backdrop, or images only),
  including awards; thumbnail backfill and an original-quality
  poster/backdrop download option
- Settings for appearance (light/dark, accent colour), TMDB/OMDb
  API keys, an optional HTTP proxy (for networks where TMDB is
  filtered), database location (move / switch / import), and
  storage

## How builds work

There is no local Windows/`.NET` environment in this workflow, so the app
is built entirely by GitHub Actions:

1. Push to `main` (or run the workflow manually).
2. `.github/workflows/build-windows.yml` spins up a `windows-latest`
   runner, installs Flutter, scaffolds the native Windows platform files,
   generates the database code, and runs `flutter build windows --release`.
3. The result is zipped and uploaded as a workflow artifact
   (**Actions tab → latest run → Artifacts → SMDB-Windows**).

The `windows/` folder and Drift generated files (`*.g.dart`) are not
committed — they are regenerated on every CI run (`flutter create
--platforms=windows .` and `dart run build_runner build`).
`flutter analyze` runs as a gate before the build.

## First run

1. Get a free TMDB API key: https://www.themoviedb.org/settings/api
2. Open the app → Settings → paste the key → Save. (An OMDb key is
   optional.)
3. If TMDB does not load on your network, put your VPN client’s local
   proxy host/port in Settings too.
4. Tap **Add Movies** / **Add Shows** and pick a folder with your
   movies (or shows).

API keys and other settings are stored in `smdb_config.json` next to
the app’s `.exe`; the library database defaults to
`Documents/SMDB/library.sqlite` and can be moved from Settings.

## Project layout

```
lib/
  main.dart                  App entry point, window setup, Riverpod scope
  database/database.dart     Drift schema + queries (movies, shows,
                             episodes, people, credits, collections,
                             awards, watch history, folders, settings)
  services/
    tmdb_service.dart        TMDB API client (with optional proxy)
    omdb_service.dart        OMDb API client
    wikidata_service.dart    Awards lookup via Wikidata SPARQL
    library_scanner.dart     Folder walking + filename parsing
    thumbnail_service.dart   Poster/backdrop thumbnail handling
    app_config_service.dart  smdb_config.json (keys, proxy, DB path, theme)
  providers/providers.dart   Riverpod wiring, scan controller, refresh
                             and download controllers
  screens/                   Library grid, movie/show/person detail,
                             edit screens, genres, people, year,
                             statistics, advanced filter, settings
  widgets/                   Poster tiles, media grid, filters,
                             A–Z index, awards, watch history, search
  theme/app_theme.dart       Light/dark themes and accent colours
  utils/                     Donation options, language names,
                             search index, metadata-refresh modes
```

## Tests

There is no automated test suite yet — `test/widget_test.dart` is a
placeholder that exists so the CI scaffold step does not overwrite it
with the Flutter template. The filename-parsing functions in
`lib/services/library_scanner.dart` are the easiest place to start
adding real tests.
