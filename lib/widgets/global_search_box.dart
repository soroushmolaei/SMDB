import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../screens/movie_detail_screen.dart';
import '../screens/person_detail_screen.dart';
import '../screens/search_results_screen.dart';
import '../screens/show_detail_screen.dart';
import '../utils/search_index.dart';
import 'smart_image.dart';

/// A compact, pill-shaped search box for the custom title bar (the same
/// idea as the search box centered in Word/Excel's title bar). Shows the
/// top 3 matches in a dropdown as the person types, with a "See all
/// results" row underneath that opens [SearchResultsScreen].
class GlobalSearchBox extends ConsumerStatefulWidget {
  const GlobalSearchBox({super.key});

  @override
  ConsumerState<GlobalSearchBox> createState() => _GlobalSearchBoxState();
}

class _GlobalSearchBoxState extends ConsumerState<GlobalSearchBox> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  final _overlayController = OverlayPortalController();
  // Shared identity so the search box and its dropdown are treated as one
  // region: a tap on either doesn't count as "outside" the other.
  final Object _groupId = Object();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final query = _controller.text.trim();
      setState(() => _query = query);
      if (query.isEmpty) {
        _overlayController.hide();
      } else {
        _overlayController.show();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _closeAndClear() {
    _overlayController.hide();
    _controller.clear();
    _query = '';
    _focusNode.unfocus();
  }

  void _openSeeAll(String query) {
    if (query.isEmpty) return;
    _closeAndClear();
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => SearchResultsScreen(query: query)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: _groupId,
      onTapOutside: (event) => _overlayController.hide(),
      child: OverlayPortal(
        controller: _overlayController,
        overlayChildBuilder: (context) => Positioned(
          width: 340,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            offset: const Offset(-10, 6),
            child: TapRegion(
              groupId: _groupId,
              child: _SearchDropdown(
                query: _query,
                onSelect: _closeAndClear,
                onSeeAll: () => _openSeeAll(_query),
              ),
            ),
          ),
        ),
        child: CompositedTransformTarget(
          link: _layerLink,
          child: Container(
            width: 300,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onTap: () {
                if (_query.isNotEmpty) _overlayController.show();
              },
              style: const TextStyle(color: Colors.white, fontSize: 12),
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                prefixIcon: const Icon(Icons.search,
                    size: 14, color: Colors.white54),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 26, minHeight: 24),
                hintText: 'Search movies, shows, people',
                hintStyle:
                    const TextStyle(color: Colors.white38, fontSize: 12),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close,
                            size: 12, color: Colors.white54),
                        onPressed: () {
                          _controller.clear();
                          _focusNode.requestFocus();
                        },
                        constraints:
                            const BoxConstraints(minWidth: 24, minHeight: 24),
                        padding: EdgeInsets.zero,
                      ),
              ),
              onSubmitted: (value) => _openSeeAll(value.trim()),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchDropdown extends ConsumerWidget {
  final String query;
  final VoidCallback onSelect;
  final VoidCallback onSeeAll;

  const _SearchDropdown({
    required this.query,
    required this.onSelect,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moviesAsync = ref.watch(moviesStreamProvider);
    final shows = ref.watch(showsStreamProvider).value ?? [];
    final people = ref.watch(peopleStreamProvider).value ?? [];

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      color: const Color(0xFF23232B),
      child: moviesAsync.when(
        data: (movies) {
          final results = searchLibrary(
            query: query,
            movies: movies,
            shows: shows,
            people: people,
            onTapMovie: (id) {
              onSelect();
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => MovieDetailScreen(movieId: id),
                ),
              );
            },
            onTapShow: (id) {
              onSelect();
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => ShowDetailScreen(showId: id),
                ),
              );
            },
            onTapPerson: (id) {
              onSelect();
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => PersonDetailScreen(personId: id),
                ),
              );
            },
          );

          if (results.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'No results',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            );
          }

          final top = results.take(3).toList();

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final hit in top) _SearchHitRow(hit: hit),
              InkWell(
                onTap: onSeeAll,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Text(
                        'See all results',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(14),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (e, st) => const SizedBox.shrink(),
      ),
    );
  }
}

class _SearchHitRow extends StatelessWidget {
  final SearchHit hit;
  const _SearchHitRow({required this.hit});

  IconData get _fallbackIcon {
    switch (hit.kind) {
      case SearchHitKind.movie:
        return Icons.movie_outlined;
      case SearchHitKind.show:
        return Icons.tv_outlined;
      case SearchHitKind.person:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: hit.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(
                  hit.kind == SearchHitKind.person ? 16 : 4),
              child: SizedBox(
                width: 32,
                height: 32,
                child: hit.imagePath != null && hit.imagePath!.isNotEmpty
                    ? SmartImage(
                        path: hit.imagePath!,
                        fit: BoxFit.cover,
                        thumbnailBytes: hit.thumbnail,
                        errorBuilder: (context) => Container(
                          color: Colors.white10,
                          child: Icon(_fallbackIcon,
                              size: 16, color: Colors.white38),
                        ),
                      )
                    : Container(
                        color: Colors.white10,
                        child: Icon(_fallbackIcon,
                            size: 16, color: Colors.white38),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hit.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (hit.subtitle != null && hit.subtitle!.isNotEmpty)
                    Text(
                      hit.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white38,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
