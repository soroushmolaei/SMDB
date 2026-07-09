# SMDB

A personal, local movie & TV show library manager for Windows — an
alternative to the discontinued Movie Label. Point it at your hard drive,
and it scans your folders, matches titles against TMDB, and gives you a
poster-grid library with watch-status tracking. Everything is stored
locally (SQLite); nothing is uploaded anywhere.

## Status: early build (v0.1)

Working:
- Add a folder and scan it for movies (`Movie Name (Year)/file.mkv` or
  loose video files)
- Auto-match against TMDB for poster, overview, cast, director, rating,
  runtime, genres
- Poster-grid library with search and watched/unwatched toggling
- Movie detail screen
- TV show folder scanning (show → season/episode files) and basic matching
- Optional HTTP proxy setting, for networks where TMDB is filtered

Not built yet:
- Show detail screen (season/episode browsing, per-episode watched toggle)
- Manual re-match / fix wrong TMDB match
- Sorting options, collections/tags, duplicate detection
- Editing metadata by hand

## How builds work

There's no local Windows/`.NET` environment in this workflow, so the app
is built entirely by GitHub Actions:

1. Push to `main` (or run the workflow manually).
2. `.github/workflows/build-windows.yml` spins up a `windows-latest`
   runner, installs Flutter, scaffolds the native Windows platform files,
   generates the database code, and runs `flutter build windows --release`.
3. The result is zipped and uploaded as a workflow artifact
   (**Actions tab → latest run → Artifacts → SMDB-Windows**).

Expect a few rounds of fixes after the first run — this is normal for a
freshly scaffolded Flutter Windows project built entirely through CI
without a local test cycle.

## First run

1. Get a free TMDB API key: https://www.themoviedb.org/settings/api
2. Open the app → Settings → paste the key → Save.
3. If TMDB doesn't load on your network, put your VPN client's local
   proxy host/port in Settings too.
4. Tap **Add Folder** and pick a folder with your movies (or shows).

## Project layout

```
lib/
  database/database.dart     Drift schema + queries (movies, shows,
                              episodes, folders, settings)
  services/tmdb_service.dart TMDB API client (with optional proxy)
  services/library_scanner.dart  Folder walking + filename parsing
  providers/providers.dart   Riverpod wiring + the scan controller
  screens/                   Library grid, movie detail, settings
  widgets/poster_card.dart   Shared poster tile
```
