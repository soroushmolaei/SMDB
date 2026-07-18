import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../providers/providers.dart';
import '../services/omdb_service.dart';
import '../services/tmdb_service.dart';
import '../widgets/smart_image.dart';

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

class EditShowScreen extends ConsumerStatefulWidget {
  final int showId;
  const EditShowScreen({super.key, required this.showId});

  @override
  ConsumerState<EditShowScreen> createState() => _EditShowScreenState();
}

class _EditShowScreenState extends ConsumerState<EditShowScreen> {
  final _title = TextEditingController();
  final _overview = TextEditingController();
  final _genres = TextEditingController();
  final _contentRating = TextEditingController();
  final _status = TextEditingController();
  final _rating = TextEditingController();
  final _rematchQuery = TextEditingController();
  final _folderPath = TextEditingController();
  final _posterPath = TextEditingController();
  final _backdropPath = TextEditingController();
  bool _loaded = false;
  bool _saving = false;
  bool _searching = false;
  List<_Candidate> _candidates = [];
  int? _pendingTmdbId;

  @override
  void dispose() {
    _title.dispose();
    _overview.dispose();
    _genres.dispose();
    _contentRating.dispose();
    _status.dispose();
    _rating.dispose();
    _rematchQuery.dispose();
    _folderPath.dispose();
    _posterPath.dispose();
    _backdropPath.dispose();
    super.dispose();
  }

  void _loadIfNeeded(Show show) {
    if (_loaded) return;
    _title.text = show.title;
    _overview.text = show.overview ?? '';
    _genres.text = show.genres ?? '';
    _contentRating.text = show.contentRating ?? '';
    _status.text = show.status ?? '';
    _rating.text = show.rating?.toString() ?? '';
    _rematchQuery.text = show.title;
    _folderPath.text = show.folderPath;
    _posterPath.text = show.posterPath ?? '';
    _backdropPath.text = show.backdropPath ?? '';
    _pendingTmdbId = show.tmdbId;
    _loaded = true;
  }

  Future<void> _browseFolder() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path != null) setState(() => _folderPath.text = path);
  }

  Future<void> _browseImageFile(TextEditingController controller) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final path = result?.files.single.path;
    if (path != null) setState(() => controller.text = path);
  }

  String? _nullIfEmpty(String s) => s.trim().isEmpty ? null : s.trim();

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
        final omdbResults = await omdb.searchTitles(query, type: 'series');
        results.addAll(omdbResults.map((r) => _Candidate(
              source: 'OMDb',
              id: r.imdbId,
              title: r.title,
              year: r.year,
              posterUrl: r.posterUrl,
            )));
      } catch (_) {}
    }
    if (tmdb != null) {
      try {
        final tmdbResults = await tmdb.searchTvShow(query);
        results.addAll(tmdbResults.map((r) => _Candidate(
              source: 'TMDB',
              id: '${r.id}',
              title: r.name,
              year: r.firstAirDate != null && r.firstAirDate!.length >= 4
                  ? r.firstAirDate!.substring(0, 4)
                  : null,
              posterUrl: TmdbService.imageUrl(r.posterPath, size: 'w92'),
            )));
      } catch (_) {}
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
          _overview.text = OmdbService.cleanText(data['Plot'] as String?) ?? '';
          _genres.text = OmdbService.cleanText(data['Genre'] as String?) ?? '';
          _contentRating.text =
              OmdbService.cleanText(data['Rated'] as String?) ?? '';
          _rating.text = data['imdbRating'] as String? ?? '';
          final totalSeasons = data['totalSeasons'];
          _status.text = (data['Status'] as String?) ??
              (totalSeasons != null ? '$totalSeasons seasons' : '');
          _posterPath.text =
              OmdbService.posterUrl(data['Poster'] as String?) ?? '';
          _pendingTmdbId = null;
        }
      } else {
        final tmdb = ref.read(tmdbServiceProvider);
        final tmdbId = int.parse(c.id);
        final details = await tmdb!.getShowDetails(tmdbId);
        _title.text = (details['name'] as String?) ?? _title.text;
        _overview.text = details['overview'] as String? ?? '';
        final genreList = (details['genres'] as List<dynamic>?) ?? [];
        _genres.text = genreList.map((g) => g['name']).join(', ');
        _contentRating.text =
            TmdbService.extractShowCertification(details) ?? '';
        _status.text = details['status'] as String? ?? '';
        final rating = (details['vote_average'] as num?)?.toDouble();
        _rating.text = rating?.toString() ?? '';
        _posterPath.text =
            TmdbService.imageUrl(details['poster_path'] as String?) ?? '';
        _backdropPath.text = TmdbService.imageUrl(
              details['backdrop_path'] as String?,
              size: 'w1280',
            ) ??
            '';
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
    if (_folderPath.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Folder path cannot be empty')),
      );
      return;
    }
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    await db.updateShowDetails(
      widget.showId,
      ShowsCompanion(
        title: Value(_title.text.trim()),
        overview: Value(_nullIfEmpty(_overview.text)),
        genres: Value(_nullIfEmpty(_genres.text)),
        contentRating: Value(_nullIfEmpty(_contentRating.text)),
        status: Value(_nullIfEmpty(_status.text)),
        rating: Value(double.tryParse(_rating.text.trim())),
        folderPath: Value(_folderPath.text.trim()),
        posterPath: Value(_nullIfEmpty(_posterPath.text)),
        backdropPath: Value(_nullIfEmpty(_backdropPath.text)),
        tmdbId: Value(_pendingTmdbId),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final showsAsync = ref.watch(showsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Show'),
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
      body: showsAsync.when(
        data: (shows) {
          final matches = shows.where((s) => s.id == widget.showId);
          if (matches.isEmpty) {
            return const Center(child: Text('Show not found'));
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
                                                  Icons.tv_outlined,
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
                controller: _contentRating,
                decoration: const InputDecoration(
                  labelText: 'Content rating (e.g. TV-14, TV-MA)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _status,
                decoration: const InputDecoration(
                  labelText: 'Status (e.g. Ended, Returning Series)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _rating,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Rating (0-10)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Poster & Backdrop',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 60,
                      height: 90,
                      child: _posterPath.text.isNotEmpty
                          ? SmartImage(
                              path: _posterPath.text,
                              fit: BoxFit.cover,
                              errorBuilder: (c) =>
                                  Container(color: Colors.white10),
                            )
                          : Container(color: Colors.white10),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _posterPath,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Poster (URL or local file)',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.folder_open),
                          tooltip: 'Browse for image file',
                          onPressed: () => _browseImageFile(_posterPath),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 90,
                      height: 50,
                      child: _backdropPath.text.isNotEmpty
                          ? SmartImage(
                              path: _backdropPath.text,
                              fit: BoxFit.cover,
                              errorBuilder: (c) =>
                                  Container(color: Colors.white10),
                            )
                          : Container(color: Colors.white10),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _backdropPath,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Backdrop (URL or local file)',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.folder_open),
                          tooltip: 'Browse for image file',
                          onPressed: () => _browseImageFile(_backdropPath),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Files',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _folderPath,
                decoration: InputDecoration(
                  labelText: 'Show folder',
                  helperText: 'The folder containing this show\'s episodes',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.folder_open),
                    tooltip: 'Browse for folder',
                    onPressed: _browseFolder,
                  ),
                ),
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
