import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';

import 'package:auris_core/auris_core.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../shared/widgets/focusable_poster_card.dart';
import '../../home/widgets/wide_content_row.dart';
import 'providers/search_provider.dart';
import 'widgets/search_widgets.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  String _selectedCategory = 'all';
  Timer? _debounce;
  String _currentQuery = '';
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
    // En móvil, el teclado se abre automático según la spec
    Future.delayed(Duration.zero, () {
      if (mounted && ResponsiveUtils.isMobile(context)) {
        FocusScope.of(context).requestFocus(_focusNode);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _dynamicPlaceholder {
    switch (_selectedCategory) {
      case 'peliculas': return 'Buscar películas...';
      case 'series': return 'Buscar series...';
      case 'anime': return 'Buscar anime...';
      default: return 'Buscar películas, series o anime...';
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _currentQuery = '');
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _currentQuery = value.trim());
    });
  }

  void _onSearchSubmitted(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isNotEmpty) {
      setState(() => _currentQuery = query);
      ref.read(searchHistoryProvider.notifier).addQuery(query);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _currentQuery = '');
  }

  void _performSearch(String query) {
    _searchController.text = query;
    _onSearchSubmitted(query);
  }

  void _onContentTap(SearchResult result) {
    final rawTitle = result.scrapedTitle ?? result.metadataTitle ?? result.title;
    final displayTitle = cleanTitleForDisplay(rawTitle);
    final metaTitle = cleanTitleForDisplay(result.metadataTitle ?? result.scrapedTitle ?? result.title);
    ref.read(searchHistoryProvider.notifier).addQuery(result.title);
    final openCategory = inferOpenCategory(result, _selectedCategory);

    final uri = '/content/${Uri.encodeComponent(displayTitle)}'
        '?source=${Uri.encodeComponent(result.source)}'
        '&url=${Uri.encodeComponent(result.url)}'
        '&metadataTitle=${Uri.encodeComponent(metaTitle)}'
        '&banner=${Uri.encodeComponent(result.banner ?? '')}'
        '&category=${Uri.encodeComponent(openCategory)}'
        '&year=${result.year ?? ''}'
        '&totalSeasons=${result.totalSeasons ?? ''}'
        '${result.kind != null ? '&type=${Uri.encodeComponent(result.kind!)}' : ''}';

    context.push(uri, extra: result);
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(
      searchResultsProvider(
        SearchParams(category: _selectedCategory, query: _currentQuery),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0D),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
        title: Row(
          children: [
            // BARRA DE BÚSQUEDA
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isFocused ? const Color(0xFFEF7A1E) : Colors.white.withOpacity(0.05),
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  textAlign: TextAlign.left,
                  textAlignVertical: TextAlignVertical.center,
                  style: const TextStyle(fontSize: 15, color: Colors.white),
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [CapitalizeFirstLetterFormatter()],
                  decoration: InputDecoration(
                    hintText: _dynamicPlaceholder,
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded, 
                        color: _isFocused ? const Color(0xFFEF7A1E) : Colors.white24, 
                        size: 20),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
                            onPressed: _clearSearch,
                          )
                        : null,
                  ),
                  onChanged: _onSearchChanged,
                  onSubmitted: _onSearchSubmitted,
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // DROPDOWN DE FILTRO
            Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  dropdownColor: const Color(0xFF1A1A1A),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white38, size: 20),
                  borderRadius: BorderRadius.circular(12),
                  style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Todo')),
                    DropdownMenuItem(value: 'peliculas', child: Text('Películas')),
                    DropdownMenuItem(value: 'series', child: Text('Series')),
                    DropdownMenuItem(value: 'anime', child: Text('Anime')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedCategory = v);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _currentQuery.isEmpty 
            ? _buildPreSearchState() 
            : _buildResultsState(resultsAsync),
      ),
    );
  }

  Widget _buildPreSearchState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        children: [
          const _ContinueWatchingSection(),
          SearchHistorySection(onQueryTap: _performSearch),
          SearchGenresGrid(onGenreTap: _performSearch),
          const SizedBox(height: 16),
          SearchTrendingSection(onTrendingTap: _onContentTap),
        ],
      ),
    );
  }

  Widget _buildResultsState(AsyncValue<SearchResponse> resultsAsync) {
    return resultsAsync.when(
      data: (response) {
        final results = _deduplicate(response.results);
        if (results.isEmpty) return _buildNoResultsState();
        
        final isMobile = ResponsiveUtils.isMobile(context);
        final screenWidth = MediaQuery.sizeOf(context).width;

        int crossAxisCount = 3;
        if (!isMobile) {
          if (screenWidth > 1800) crossAxisCount = 8;
          else if (screenWidth > 1400) crossAxisCount = 7;
          else if (screenWidth > 1000) crossAxisCount = 6;
          else crossAxisCount = 5;
        }
        
        return GridView.builder(
          key: const ValueKey('results_grid'),
          padding: EdgeInsets.fromLTRB(
            isMobile ? 16 : 24, 8, isMobile ? 16 : 24, 40
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: isMobile ? 0.54 : 0.58,
            crossAxisSpacing: isMobile ? 12 : 20, 
            mainAxisSpacing: isMobile ? 12 : 16, 
          ),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final result = results[index];
            final meta = result.resolveMetadata(_selectedCategory);

            final historyAsync = ref.watch(playbackHistoryStateProvider);
            double? progress;
            historyAsync.whenData((items) {
              final match = items.firstWhereOrNull((h) => h.contentId == result.url);
              if (match != null) progress = match.progress;
            });

            final card = FocusablePosterCard(
              title: cleanTitleForDisplay(result.scrapedTitle ?? result.metadataTitle ?? result.title),
              posterUrl: ApiEndpoints.proxyImage(result.thumbnail, fallbackUrl: result.tmdbThumbnail),
              badge: meta.label,
              badgeColor: meta.labelColor,
              subtitle: meta.status,
              subtitleColor: meta.statusColor,
              progress: progress,
              onTap: () => _onContentTap(result),
            );

            if (index < 24) {
              return _StaggeredResultItem(
                itemId: '${result.url}_${result.source}',
                sessionKey: '$_currentQuery|$_selectedCategory',
                delay: Duration(milliseconds: index * 35),
                child: card,
              );
            }

            return card;
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFEF7A1E))),
      error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white54))),
    );
  }

  Widget _buildNoResultsState() {
    return SingleChildScrollView(
      key: const ValueKey('no_results_scroll'),
      padding: const EdgeInsets.only(top: 60, bottom: 40),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 80, color: Colors.white10),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'No hemos encontrado resultados para "$_currentQuery"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70, 
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Prueba con otros términos o explora lo más visto hoy',
            style: TextStyle(color: Colors.white30, fontSize: 14),
          ),
          const SizedBox(height: 60),
          SearchTrendingSection(onTrendingTap: _onContentTap),
          const SizedBox(height: 40),
          SearchGenresGrid(onGenreTap: _performSearch),
        ],
      ),
    );
  }
}

class _ContinueWatchingSection extends ConsumerWidget {
  const _ContinueWatchingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final continueWatchingAsync = ref.watch(continueWatchingProvider);

    return continueWatchingAsync.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 24, top: 12),
          child: WideContentRow(
            title: 'Continuar Viendo',
            items: items.map((h) => _mapHistoryToWide(ref, h)).toList(),
            onItemTap: (wideItem) => _onTap(context, wideItem.originalItem as PlaybackHistory),
          ),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.only(bottom: 24, top: 12),
        child: RowSkeleton(isWide: true),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  WideContentItem _mapHistoryToWide(WidgetRef ref, PlaybackHistory h) {
    String displayTitle = h.title ?? 'Contenido';
    final bool isMovie = h.category?.toLowerCase().contains('movie') ?? false;
    if (!isMovie && h.episode != null && h.episode!.isNotEmpty) {
      displayTitle = 'Ep ${h.episode} • $displayTitle';
    }

    String remainingText = '';
    final remainingMs = h.durationInMilliseconds - h.positionInMilliseconds;
    if (remainingMs > 0) {
      final minutes = (remainingMs / 60000).ceil();
      remainingText = 'Quedan $minutes min';
    }

    return WideContentItem(
      id: h.contentId,
      title: displayTitle,
      imageUrl: h.posterUrl ?? h.bannerUrl ?? '',
      progress: h.progress,
      subtitle: remainingText,
      onDelete: () {
        ref.read(playbackHistoryStateProvider.notifier).deleteProgress(h.contentId, h.season, h.episode);
      },
      originalItem: h,
    );
  }

  void _onTap(BuildContext context, PlaybackHistory item) {
    final uri = '/player/${Uri.encodeComponent(item.contentId)}'
        '?url=${Uri.encodeComponent(item.url ?? item.contentId)}'
        '&source=${Uri.encodeComponent(item.source ?? "")}'
        '&episode=${item.episode ?? ""}'
        '&season=${item.season ?? ""}'
        '&startPosition=${item.positionInMilliseconds}'
        '&category=${Uri.encodeComponent(item.category ?? "anime")}'
        '&title=${Uri.encodeComponent(item.title ?? "")}'
        '&posterUrl=${Uri.encodeComponent(item.posterUrl ?? "")}'
        '&bannerUrl=${Uri.encodeComponent(item.bannerUrl ?? "")}'
        '&language=${Uri.encodeComponent(item.language ?? "")}';
    context.push(uri);
  }
}

class _StaggeredResultItem extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final String itemId;
  final String sessionKey;

  const _StaggeredResultItem({
    required this.child,
    required this.delay,
    required this.itemId,
    required this.sessionKey,
  });

  @override
  State<_StaggeredResultItem> createState() => _StaggeredResultItemState();
}

class _StaggeredResultItemState extends State<_StaggeredResultItem> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  Timer? _timer;

  // Senior State Tracking: Registro global para persistencia de scroll
  static final Set<String> _animatedIds = {};
  static String _activeSession = '';

  @override
  void initState() {
    super.initState();

    // Resetear sesión si la búsqueda cambió
    if (_activeSession != widget.sessionKey) {
      _animatedIds.clear();
      _activeSession = widget.sessionKey;
    }

    final bool alreadyAnimated = _animatedIds.contains(widget.itemId);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      value: alreadyAnimated ? 1.0 : 0.0,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
    ));

    if (!alreadyAnimated) {
      _animatedIds.add(widget.itemId);
      _timer = Timer(widget.delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

String _fuseKey(SearchResult r) {
  final t = r.title.toLowerCase();
  final typeRe = RegExp(r'\b(movie|pel[íi]cula|film|ova|special|oav)\b');
  final isMovieish = typeRe.hasMatch(t);
  final franchise = t.replaceAll(typeRe, '').replaceAll(RegExp(r'[^a-z0-9]'), '');
  final cat = inferOpenCategory(r, isMovieish ? 'movie' : 'tv');
  return '$franchise#$cat';
}

List<SearchResult> _deduplicate(List<SearchResult> results) {
  final Map<String, SearchResult> grouped = {};
  for (final r in results) {
    final key = _fuseKey(r);
    final existing = grouped[key];
    if (existing == null) {
      grouped[key] = r;
    } else {
      final mergedSources = List<SourceItem>.from(existing.sources);
      for (final src in r.sources) {
        if (!mergedSources.any((s) => s.source == src.source && s.url == src.url)) {
          mergedSources.add(src);
        }
      }
      SearchResult better = existing;
      if (r.thumbnail.isNotEmpty && existing.thumbnail.isEmpty) {
        better = r;
      } else if ((existing.banner == null || existing.banner!.isEmpty) && (r.banner != null && r.banner!.isNotEmpty)) {
        better = r;
      }
      grouped[key] = SearchResult(
        title: better.title,
        url: better.url,
        quality: better.quality,
        thumbnail: better.thumbnail,
        banner: better.banner,
        source: better.source,
        year: better.year,
        slug: better.slug,
        scrapedTitle: better.scrapedTitle,
        metadataTitle: better.metadataTitle,
        forcedTitle: better.forcedTitle,
        fromDiscovery: better.fromDiscovery,
        score: better.score,
        fullDate: better.fullDate,
        status: better.status,
        kind: better.kind,
        type: better.type,
        sources: mergedSources,
      );
    }
  }
  return grouped.values.toList();
}
