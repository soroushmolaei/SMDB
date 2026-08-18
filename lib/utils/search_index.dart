import 'package:flutter/foundation.dart';

import '../database/database.dart';

enum SearchHitKind { movie, show, person }

/// A single global-search result. [subtitle] is used to show *why* it
/// matched when that isn't obvious from [title] alone -- the original
/// title, when that's what matched and it differs from the display
/// title.
@immutable
class SearchHit {
  final SearchHitKind kind;
  final int id;
  final String title;
  final String? subtitle;
  final String? imagePath;
  final Uint8List? thumbnail;
  final VoidCallback onTap;

  const SearchHit({
    required this.kind,
    required this.id,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.imagePath,
    this.thumbnail,
  });
}

class _Scored {
  final int score;
  final SearchHit hit;
  _Scored(this.score, this.hit);
}

/// Lower is better: 0 = exact match, 1 = starts with the query, 2 =
/// contains the query anywhere, -1 = no match at all.
int _matchScore(String candidate, String query) {
  final c = candidate.toLowerCase();
  if (c == query) return 0;
  if (c.startsWith(query)) return 1;
  if (c.contains(query)) return 2;
  return -1;
}

/// Searches Movie title, Movie original title, Show title, Show original
/// title, and Person name against [query], returning every match ranked
/// exact-match-first, then starts-with, then contains, alphabetical
/// within each tier. Empty query returns no results.
List<SearchHit> searchLibrary({
  required String query,
  required List<Movie> movies,
  required List<Show> shows,
  required List<Person> people,
  required void Function(int movieId) onTapMovie,
  required void Function(int showId) onTapShow,
  required void Function(int personId) onTapPerson,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];

  final scored = <_Scored>[];

  for (final m in movies) {
    final titleScore = _matchScore(m.title, q);
    final originalScore =
        m.originalTitle != null ? _matchScore(m.originalTitle!, q) : -1;
    final candidates =
        [titleScore, originalScore].where((s) => s >= 0).toList();
    if (candidates.isEmpty) continue;

    final matchedViaOriginalOnly = originalScore >= 0 &&
        (titleScore < 0 || originalScore < titleScore) &&
        m.originalTitle != m.title;

    scored.add(_Scored(
      candidates.reduce((a, b) => a < b ? a : b),
      SearchHit(
        kind: SearchHitKind.movie,
        id: m.id,
        title: m.title,
        subtitle: matchedViaOriginalOnly
            ? m.originalTitle
            : (m.year != null ? '${m.year}' : null),
        imagePath: m.posterPath,
        thumbnail: m.posterThumbnail,
        onTap: () => onTapMovie(m.id),
      ),
    ));
  }

  for (final s in shows) {
    final titleScore = _matchScore(s.title, q);
    final originalScore =
        s.originalTitle != null ? _matchScore(s.originalTitle!, q) : -1;
    final candidates =
        [titleScore, originalScore].where((sc) => sc >= 0).toList();
    if (candidates.isEmpty) continue;

    final matchedViaOriginalOnly = originalScore >= 0 &&
        (titleScore < 0 || originalScore < titleScore) &&
        s.originalTitle != s.title;

    scored.add(_Scored(
      candidates.reduce((a, b) => a < b ? a : b),
      SearchHit(
        kind: SearchHitKind.show,
        id: s.id,
        title: s.title,
        subtitle: matchedViaOriginalOnly
            ? s.originalTitle
            : (s.year != null ? '${s.year}' : null),
        imagePath: s.posterPath,
        thumbnail: s.posterThumbnail,
        onTap: () => onTapShow(s.id),
      ),
    ));
  }

  for (final p in people) {
    final nameScore = _matchScore(p.name, q);
    if (nameScore < 0) continue;
    scored.add(_Scored(
      nameScore,
      SearchHit(
        kind: SearchHitKind.person,
        id: p.id,
        title: p.name,
        subtitle: 'Person',
        imagePath: p.photoPath,
        onTap: () => onTapPerson(p.id),
      ),
    ));
  }

  scored.sort((a, b) {
    final byScore = a.score.compareTo(b.score);
    if (byScore != 0) return byScore;
    return a.hit.title.toLowerCase().compareTo(b.hit.title.toLowerCase());
  });

  return scored.map((s) => s.hit).toList();
}
