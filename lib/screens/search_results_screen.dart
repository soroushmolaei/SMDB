import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';

import '../providers/providers.dart';
import '../utils/search_index.dart';
import '../widgets/poster_card.dart';
import '../widgets/smart_image.dart';
import 'movie_detail_screen.dart';
import 'person_detail_screen.dart';
import 'show_detail_screen.dart';

/// The "See all results" destination from [GlobalSearchBox] -- shows every
/// match (not just the top 3), grouped into Movies & Shows and People.
class SearchResultsScreen extends ConsumerStatefulWidget {
  final String query;
  const SearchResultsScreen({super.key, required this.query});

  @override
  ConsumerState<SearchResultsScreen> createState() =>
      _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  late final TextEditingController _controller;
  late String _query;

  @override
  void initState() {
    super.initState();
    _query = widget.query;
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moviesAsync = ref.watch(moviesStreamProvider);
    final shows = ref.watch(showsStreamProvider).value ?? [];
    final people = ref.watch(peopleStreamProvider).value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          style: const TextStyle(fontSize: 16),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Search movies, shows, people',
          ),
          onSubmitted: (v) => setState(() => _query = v.trim()),
        ),
      ),
      body: moviesAsync.when(
        data: (movies) {
          if (_query.trim().isEmpty) {
            return Center(
              child: Text(
                'Type something to search.',
                style: TextStyle(
                    color: context.appColors.textSecondary),
              ),
            );
          }

          final results = searchLibrary(
            query: _query,
            movies: movies,
            shows: shows,
            people: people,
            onTapMovie: (id) => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MovieDetailScreen(movieId: id),
              ),
            ),
            onTapShow: (id) => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ShowDetailScreen(showId: id),
              ),
            ),
            onTapPerson: (id) => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PersonDetailScreen(personId: id),
              ),
            ),
          );

          if (results.isEmpty) {
            return Center(
              child: Text(
                'No results for "$_query".',
                style: TextStyle(
                    color: context.appColors.textSecondary),
              ),
            );
          }

          final movieShowHits =
              results.where((r) => r.kind != SearchHitKind.person).toList();
          final personHits =
              results.where((r) => r.kind == SearchHitKind.person).toList();

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    '${results.length} result'
                    '${results.length == 1 ? '' : 's'} for "$_query"',
                    style: TextStyle(
                        color:
                            context.appColors.textSecondary,
                        fontSize: 13),
                  ),
                ),
              ),
              if (movieShowHits.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'MOVIES & SHOWS (${movieShowHits.length})',
                      style: _sectionHeaderStyle(context),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 150,
                      childAspectRatio: 0.55,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final hit = movieShowHits[index];
                        return PosterCard(
                          title: hit.title,
                          posterUrl: hit.imagePath,
                          thumbnailBytes: hit.thumbnail,
                          watched: false,
                          onTap: hit.onTap,
                        );
                      },
                      childCount: movieShowHits.length,
                    ),
                  ),
                ),
              ],
              if (personHits.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'PEOPLE (${personHits.length})',
                      style: _sectionHeaderStyle(context),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: personHits
                          .map((hit) => _PersonResultTile(hit: hit))
                          .toList(),
                    ),
                  ),
                ),
              ],
              const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

TextStyle _sectionHeaderStyle(BuildContext context) => TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: context.appColors.textSecondary,
      letterSpacing: 0.5,
    );

class _PersonResultTile extends StatelessWidget {
  final SearchHit hit;
  const _PersonResultTile({required this.hit});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: hit.onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 88,
        child: Column(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor:
                  context.appColors.surfaceSubtle,
              backgroundImage: hit.imagePath != null
                  ? smartImageProvider(hit.imagePath!)
                  : null,
              child: hit.imagePath == null
                  ? Icon(Icons.person,
                      color: context.appColors.textHint,
                      size: 32)
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              hit.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
