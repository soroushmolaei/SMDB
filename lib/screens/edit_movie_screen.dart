import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../providers/providers.dart';

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
  bool _loaded = false;
  bool _saving = false;

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
    _loaded = true;
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
