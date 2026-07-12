import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../providers/providers.dart';
import '../services/omdb_service.dart';
import '../services/tmdb_service.dart';

class _Candidate {
  final String source;
  final String id;
  final String title;
  final String? year;
  final String? posterUrl;
  _Candidate({
    required this.source,
    required this.id,
    required this.title,
    this.year,
    this.posterUrl,
  });
}

class EditMovieScreen extends ConsumerStatefulWidget {
  final int movieId;
  const EditMovieScreen({super.key, required this.movieId});

  @override
  ConsumerState<EditMovieScreen> createState() => _EditMovieScreenState();
}

class _EditMovieScreenState extends ConsumerState<EditMovieScreen> {
  final _title = TextEditingController();
  final _year = TextEditingController();
  final _overview = TextEditingController();
  final _genres = TextEditingController();
  final _director = TextEditingController();
  final _writer = TextEditingController();
  final _cast = TextEditingController();
  final _rating = TextEditingController();
  final _personalRating = TextEditingController();
  final _rematchQuery = TextEditingController();
  bool _loaded = false;
  bool _saving = false;
  bool _searching = false;
  List<_Candidate> _candidates = [];
  String? _pendingPosterUrl;
  String? _pendingBackdropUrl;
  int? _pendingTmdbId;

  @override
  void dispose() {
    _title.dispose();
    _year.dispose();
    _overview.dispose();
    _genres.dispose();
    _director.dispose();
    _writer.dispose();
    _cast.dispose();
    _rating.dispose();
    _personalRating.dispose();
    _rematchQuery.dispose();
    super.dispose();
  }

  void _loadIfNeeded(Movie movie) {
    if (_loaded) return;
    _title.text = movie.title;
    _year.text = movie.year?.toString() ?? '';
    _overview.text = movie.overview ?? '';
    _genres.text = movie.genres ?? '';
    _director.text = movie.director ?? '';
    _writer.text = movie.writer ?? '';
    _cast.text = movie.castNames ?? '';
    _rating.text = movie.rating?.toString() ?? '';
    _personalRating.text = movie.personalRating?.toString() ?? '';
    _rematchQuery.text = movie.title;
    _pendingPosterUrl = movie.posterPath;
    _pendingBackdropUrl = movie.backdropPath;
    _pendingTmdbId = movie.tmdbId;
    _loaded = true;
  }

  Future<void> _searchForRematch() async {
    final query = _rematchQuery.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _candidates = [];
    });

    final omdb = ref.read(omdbServiceProvider);
    final tmdb = ref.read(tmdbServiceProvider);
    final results = <_Candidate>[];

    if (omdb != null) {
      try {
        final omdbResults = await omdb.searchTitles(query);
        results.addAll(omdbResults.map((r) => _Candidate(
              source: 'OMDb',
              id: r.imdbId,
              title: r.title,
              year: r.year,
              posterUrl: r.posterUrl,
            )));
      } catch (_) {
        // Ignore search errors for one source; the other may still work.
      }
    }
    if (tmdb != null) {
      try {
        final tmdbResults = await tmdb.searchMovie(query);
        results.addAll(tmdbResults.map((r) => _Candidate(
              source: 'TMDB',
              id: '${r.id}',
              title: r.title,
              year: r.year?.toString(),
              posterUrl: TmdbService.imageUrl(r.posterPath, size: 'w92'),
            )));
      } catch (_) {
        // Ignore search errors for one source; the other may still work.
      }
    }

    if (!mounted) return;
    setState(() {
      _searching = false;
      _candidates = results;
    });
  }

  Future<void> _applyCandidate(_Candidate c) async {
    setState(() => _searching = true);
    try {
      if (c.source == 'OMDb') {
        final omdb = ref.read(omdbServiceProvider);
        final data = await omdb!.getByImdbId(c.id);
        if (data != null) {
          _title.text = (data['Title'] as String?) ?? _title.text;
          final yearMatch =
              RegExp(r'\d{4}').firstMatch(data['Year'] as String? ?? '');
          if (yearMatch != null) _year.text = yearMatch.group(0)!;
          _overview.text = OmdbService.cleanText(data['Plot'] as String?) ?? '';
          _genres.text = OmdbService.cleanText(data['Genre'] as String?) ?? '';
          _director.text =
              OmdbService.cleanText(data['Director'] as String?) ?? '';
          _writer.text = OmdbService.cleanText(data['Writer'] as String?) ?? '';
          _cast.text = OmdbService.cleanText(data['Actors'] as String?) ?? '';
          _rating.text = data['imdbRating'] as String? ?? '';
          _pendingPosterUrl = OmdbService.posterUrl(data['Poster'] as String?);
          _pendingTmdbId = null;
        }
      } else {
        final tmdb = ref.read(tmdbServiceProvider);
        final tmdbId = int.parse(c.id);
        final details = await tmdb!.getMovieDetails(tmdbId);
        _title.text = (details['title'] as String?) ?? _title.text;
        final releaseDate = details['release_date'] as String?;
        if (releaseDate != null && releaseDate.length >= 4) {
          _year.text = releaseDate.substring(0, 4);
        }
        _overview.text = details['overview'] as String? ?? '';
        final genreList = (details['genres'] as List<dynamic>?) ?? [];
        _genres.text = genreList.map((g) => g['name']).join(', ');
        final rating = (details['vote_average'] as num?)?.toDouble();
        _rating.text = rating?.toString() ?? '';

        final credits = details['credits'] as Map<String, dynamic>?;
        if (credits != null) {
          final crew = (credits['crew'] as List<dynamic>?) ?? [];
          final directorEntry = crew.firstWhere(
            (c2) => c2['job'] == 'Director',
            orElse: () => null,
          );
          _director.text =
              directorEntry != null ? (directorEntry['name'] as String? ?? '') : '';
          final writerEntry = crew.firstWhere(
            (c2) =>
                c2['job'] == 'Writer' ||
                c2['job'] == 'Screenplay' ||
                c2['job'] == 'Author',
            orElse: () => null,
          );
          _writer.text =
              writerEntry != null ? (writerEntry['name'] as String? ?? '') : '';
          final cast = (credits['cast'] as List<dynamic>?) ?? [];
          _cast.text = cast.take(6).map((c2) => c2['name']).join(', ');
        }

        _pendingPosterUrl =
            TmdbService.imageUrl(details['poster_path'] as String?);
        _pendingBackdropUrl = TmdbService.imageUrl(
          details['backdrop_path'] as String?,
          size: 'w1280',
        );
        _pendingTmdbId = tmdbId;
      }
      if (!mounted) return;
      setState(() {
        _candidates = [];
        _searching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Applied — review the fields, then tap Save'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _searching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch details: $e')),
      );
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title cannot be empty')),
      );
      return;
    }
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    await db.updateMovieDetails(
      widget.movieId,
      MoviesCompanion(
        title: Value(_title.text.trim()),
        year: Value(int.tryParse(_year.text.trim())),
        overview: Value(_nullIfEmpty(_overview.text)),
        genres: Value(_nullIfEmpty(_genres.text)),
        director: Value(_nullIfEmpty(_director.text)),
        writer: Value(_nullIfEmpty(_writer.text)),
        castNames: Value(_nullIfEmpty(_cast.text)),
        rating: Value(double.tryParse(_rating.text.trim())),
        personalRating: Value(double.tryParse(_personalRating.text.trim())),
        posterPath: Value(_pendingPosterUrl),
        backdropPath: Value(_pendingBackdropUrl),
        tmdbId: Value(_pendingTmdbId),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  String? _nullIfEmpty(String s) => s.trim().isEmpty ? null : s.trim();

  @override
  Widget build(BuildContext context) {
    final moviesAsync = ref.watch(moviesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Movie'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: moviesAsync.when(
        data: (movies) {
          final matches = movies.where((m) => m.id == widget.movieId);
          if (matches.isEmpty) {
            return const Center(child: Text('Movie not found'));
          }
          _loadIfNeeded(matches.first);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Wrong match?',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Search and pick the correct title. This fills in '
                      'the fields below — tap Save to apply.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _rematchQuery,
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: 'Search title...',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _searchForRematch(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _searching ? null : _searchForRematch,
                          child: _searching
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Text('Search'),
                        ),
                      ],
                    ),
                    if (_candidates.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 140,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _candidates.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final c = _candidates[index];
                            return InkWell(
                              onTap: () => _applyCandidate(c),
                              child: SizedBox(
                                width: 90,
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(6),
                                        child: c.posterUrl != null
                                            ? Image.network(
                                                c.posterUrl!,
                                                fit: BoxFit.cover,
                                                width: 90,
                                                errorBuilder:
                                                    (context, error, st) =>
                                                        Container(
                                                  color: Colors.white10,
                                                ),
                                              )
                                            : Container(
                                                color: Colors.white10,
                                                alignment: Alignment.center,
                                                child: const Icon(
                                                  Icons.movie_outlined,
                                                  color: Colors.white24,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${c.title}${c.year != null ? ' (${c.year})' : ''}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11),
                                      textAlign: TextAlign.center,
                                    ),
                                    Text(
                                      c.source,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white38,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _year,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Year',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _overview,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Overview',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _genres,
                decoration: const InputDecoration(
                  labelText: 'Genres (comma separated)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _director,
                decoration: const InputDecoration(
                  labelText: 'Director',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _writer,
                decoration: const InputDecoration(
                  labelText: 'Writer',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cast,
                decoration: const InputDecoration(
                  labelText: 'Cast (comma separated)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _rating,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Rating (0-10)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _personalRating,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Your rating (0-10)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
