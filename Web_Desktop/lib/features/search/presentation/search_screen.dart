import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';

import 'package:auris_core/auris_core.dart';
import 'package:auristv_web/core/router/app_router.dart';
import 'package:auristv_web/core/utils/responsive_utils.dart';
import 'package:auristv_web/core/utils/url_utils.dart';
import 'package:auristv_web/shared/widgets/focusable_poster_card.dart';
import 'package:auristv_web/features/search/presentation/providers/search_provider.dart';
import 'package:auristv_web/features/search/presentation/widgets/search_widgets.dart';
import 'package:auristv_web/features/home/widgets/unified_section.dart';
import 'package:auristv_web/features/player/presentation/player_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final String initialQuery;
  final String initialCategory;

  const SearchScreen({
    super.key,
    this.initialQuery = '',
    this.initialCategory = 'all',
  });

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> with RouteAware {
  late final TextEditingController _searchController;
  final _focusNode = FocusNode();
  late String _selectedCategory;
  Timer? _debounce;
  late String _currentQuery;
  bool _isFocused = false;
  bool _isNavigating = false;
  bool _isTopRoute = true;

  @override
  void initState() {
    super.initState();
    _currentQuery = widget.initialQuery;
    _selectedCategory = widget.initialCategory;
    _searchController = TextEditingController(text: _currentQuery);
    
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final modal = ModalRoute.of(context);
    if (modal is PageRoute) {
      routeObserver.subscribe(this, modal);
    }
  }

  @override
  void didPushNext() {
    if (mounted) {
      _isTopRoute = false;
      _debounce?.cancel();
      // Senior Fix: Decoplar el desenfoque del ciclo de build para evitar crash 'inactive'
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.unfocus();
          if (mounted) setState(() => _isFocused = false);
        }
      });
    }
  }

  @override
  void didPopNext() {
    if (mounted) {
      setState(() => _isTopRoute = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateUrl();
        }
      });
    }
  }

  void _onFocusChange() {
    // Senior Guard: Solo actualizar si estamos visibles y estables
    if (!mounted || _isNavigating || !_isTopRoute) return;
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialQuery != oldWidget.initialQuery && widget.initialQuery != _currentQuery) {
      _currentQuery = widget.initialQuery;
      _searchController.text = _currentQuery;
    }
    if (widget.initialCategory != oldWidget.initialCategory && widget.initialCategory != _selectedCategory) {
      _selectedCategory = widget.initialCategory;
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChange);
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

  void _updateUrl() {
    if (!mounted || _isNavigating || !_isTopRoute) return;

    final router = GoRouter.of(context);
    final currentUri = router.routeInformationProvider.value.uri;
    
    // Senior Fix: Verificamos que estemos en la ruta de catálogo antes de intentar reemplazar la URL
    if (currentUri.path != '/catalogo') return;

    final newUri = Uri(
      path: '/catalogo',
      queryParameters: {
        if (_currentQuery.isNotEmpty) 'q': _currentQuery,
        if (_selectedCategory != 'all') 'cat': _selectedCategory,
      },
    );
    
    // Senior Web Fix: Solo reemplazamos si los parámetros de búsqueda han cambiado realmente.
    // Esto evita ciclos de actualización infinitos y mantiene el historial del navegador limpio.
    if (currentUri.queryParameters['q'] != newUri.queryParameters['q'] || 
        currentUri.queryParameters['cat'] != newUri.queryParameters['cat']) {
      router.replace(newUri.toString());
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      if (mounted) setState(() => _currentQuery = '');
      _updateUrl();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted && _isTopRoute) {
        setState(() => _currentQuery = value.trim());
        _updateUrl();
      }
    });
  }

  void _onSearchSubmitted(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isNotEmpty) {
      if (mounted) setState(() => _currentQuery = query);
      ref.read(searchHistoryProvider.notifier).addQuery(query);
      _updateUrl();
    }
  }

  void _clearSearch() {
    _searchController.clear();
    if (mounted) setState(() => _currentQuery = '');
    _updateUrl();
  }

  void _performSearch(String query) {
    _searchController.text = query;
    _onSearchSubmitted(query);
  }

  void _onContentTap(SearchResult result) {
    _debounce?.cancel();
    // Bloqueamos el buscador antes de navegar para silenciar eventos residuales
    _isNavigating = true;
    _focusNode.unfocus();

    final displayTitle = result.scrapedTitle ?? result.metadataTitle ?? result.title;
    ref.read(searchHistoryProvider.notifier).addQuery(result.title);
    final openCategory = inferOpenCategory(result, _selectedCategory);
    
    final shareableUri = UrlUtils.buildShareableUri(
      title: displayTitle,
      source: result.source,
      url: result.url,
      category: openCategory,
      year: result.year,
      type: result.kind,
      from: '/catalogo',
    );

    // Senior Web Fix: Usamos context.push para mantener el estado del Shell y permitir un retorno limpio.
    context.push(shareableUri, extra: result).then((_) {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0D),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
        title: Row(
          children: [
            Expanded(
              child: RepaintBoundary(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isFocused ? const Color(0xFFEF7A1E) : Colors.white.withValues(alpha: 0.08),
                      width: _isFocused ? 1.8 : 1.5,
                    ),
                    boxShadow: _isFocused ? [
                      BoxShadow(
                        color: const Color(0xFFEF7A1E).withValues(alpha: 0.12),
                        blurRadius: 15,
                        spreadRadius: 2,
                      )
                    ] : [],
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
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, 
                          color: _isFocused ? const Color(0xFFEF7A1E) : Colors.white24, 
                          size: 20),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16), // Centrado perfecto para Container de 52px
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
            ),
            const SizedBox(width: 12),
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                    if (v != null) {
                      if (mounted) setState(() => _selectedCategory = v);
                      _updateUrl();
                    }
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
            : _SearchResultsGrid(
                query: _currentQuery,
                category: _selectedCategory,
                onContentTap: _onContentTap,
              ),
      ),
    );
  }

  Widget _buildPreSearchState() {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1200;

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 40, right: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _ContinueWatchingSection(),
                  RepaintBoundary(child: SearchGenresGrid(onGenreTap: _performSearch)),
                  const SizedBox(height: 8),
                  RepaintBoundary(
                    child: SearchDiscoveryFeed(
                      category: _selectedCategory,
                      onContentTap: _onContentTap,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1, color: Colors.white.withValues(alpha: 0.05), margin: const EdgeInsets.symmetric(vertical: 24)),
          SizedBox(
            width: 340,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 12),
              child: SearchHistorySection(onQueryTap: _performSearch),
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        children: [
          const _ContinueWatchingSection(),
          RepaintBoundary(child: SearchHistorySection(onQueryTap: _performSearch)),
          RepaintBoundary(child: SearchGenresGrid(onGenreTap: _performSearch)),
          const SizedBox(height: 8),
          RepaintBoundary(
            child: SearchDiscoveryFeed(
              category: _selectedCategory,
              onContentTap: _onContentTap,
            ),
          ),
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
          child: UnifiedSection(
            presentation: SectionPresentation.wide,
            title: 'Continuar Viendo',
            items: items.map((h) => _mapHistoryToMediaItem(h)).toList(),
            onItemTap: (item) => _onTap(context, item.playbackHistory!),
            onItemDelete: (item) {
              final h = item.playbackHistory;
              if (h != null) {
                ref.read(playbackHistoryStateProvider.notifier).deleteProgress(h.contentId, h.season, h.episode);
              }
            },
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.only(bottom: 24, top: 12),
        child: RowSkeleton(isWide: true),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  MediaItem _mapHistoryToMediaItem(PlaybackHistory h) {
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

    return MediaItem(
      id: h.contentId,
      title: displayTitle,
      posterUrl: h.posterUrl ?? '',
      bannerUrl: h.bannerUrl,
      type: isMovie ? MediaType.movie : MediaType.anime,
      subtitle: remainingText,
      playbackHistory: h,
    );
  }

  void _onTap(BuildContext context, PlaybackHistory item) {
    final player = PlayerScreen(
      contentId: item.contentId,
      sourceUrl: item.url ?? item.contentId,
      source: item.source ?? "",
      episode: item.episode ?? "1",
      season: item.season,
      startPosition: item.positionInMilliseconds,
      category: item.category,
      title: item.title,
      posterUrl: item.posterUrl,
      bannerUrl: item.bannerUrl,
      language: item.language,
    );
    UrlUtils.openPlayer(context, player);
  }
}

class _SearchResultsGrid extends ConsumerWidget {
  final String query;
  final String category;
  final Function(SearchResult) onContentTap;

  const _SearchResultsGrid({
    required this.query,
    required this.category,
    required this.onContentTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(
      searchResultsProvider(SearchParams(category: category, query: query)),
    );

    return resultsAsync.when(
      data: (response) {
        final results = _deduplicate(response.results);
        if (results.isEmpty) return _buildNoResultsPlaceholder(context, query, onContentTap);
        
        final isMobile = ResponsiveUtils.isMobile(context);
        final screenWidth = MediaQuery.sizeOf(context).width;

        int crossAxisCount = 3;
        if (!isMobile) {
          if (screenWidth > 1800) {
            crossAxisCount = 8;
          } else if (screenWidth > 1400) {
            crossAxisCount = 7;
          } else if (screenWidth > 1000) {
            crossAxisCount = 6;
          } else {
            crossAxisCount = 5;
          }
        }
        
        return RepaintBoundary(
          child: GridView.builder(
            key: const ValueKey('results_grid'),
            padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, 8, isMobile ? 16 : 24, 40),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: isMobile ? 0.54 : 0.58,
              crossAxisSpacing: isMobile ? 12 : 20, 
              mainAxisSpacing: isMobile ? 12 : 16, 
            ),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final result = results[index];
              final meta = result.resolveMetadata(category);

              final card = FocusablePosterCard(
                key: ValueKey('search_${result.url}_${result.source}'),
                title: cleanTitleForDisplay(result.scrapedTitle ?? result.metadataTitle ?? result.title),
                posterUrl: ApiEndpoints.proxyImage(result.thumbnail),
                badge: meta.label,
                badgeColor: meta.labelColor,
                badgeOverlay: result.season != null && result.season! > 1
                    ? SeasonBadge(season: result.season!)
                    : null,
                subtitle: meta.status,
                subtitleColor: meta.statusColor,
                showInfo: true,
                progress: result.progress, // Senior Fix: Usamos el progreso inyectado
                onTap: () => onContentTap(result),
              );

              // Senior Premium Fix: Animación escalonada persistente para evitar bloques negros al hacer scroll
              if (index < 32) {
                return _StaggeredResultItem(
                  itemId: '${result.url}_${result.source}',
                  sessionKey: '$query|$category',
                  delay: Duration(milliseconds: index * 35), // Escalonamiento de 35ms
                  child: card,
                );
              }

              return card;
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFEF7A1E))),
      error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white54))),
    );
  }

  Widget _buildNoResultsPlaceholder(BuildContext context, String query, Function(SearchResult) onContentTap) {
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
              'No hemos encontrado resultados para "$query"',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Prueba con otros términos o explora lo más visto hoy', style: TextStyle(color: Colors.white30, fontSize: 14)),
          const SizedBox(height: 60),
          SearchDiscoveryFeed(
            category: category,
            onContentTap: onContentTap,
          ),
          const SizedBox(height: 40),
          SearchGenresGrid(onGenreTap: (q) {
          }),
        ],
      ),
    );
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

  // Senior State Tracking: Mantenemos un registro global de qué ítems ya se animaron en esta sesión.
  static final Set<String> _animatedIds = {};
  static String _activeSession = '';

  @override
  void initState() {
    super.initState();

    // Resetear historial si la sesión (búsqueda/categoría) cambió
    if (_activeSession != widget.sessionKey) {
      _animatedIds.clear();
      _activeSession = widget.sessionKey;
    }

    final bool alreadyAnimated = _animatedIds.contains(widget.itemId);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      // Si ya se animó, empezamos al final (valor 1.0) para aparición instantánea
      value: alreadyAnimated ? 1.0 : 0.0,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06), 
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
  final typeRe = RegExp(r'\b(movie|película|ova|special)\b');
  final isMovieish = typeRe.hasMatch(t);
  final franchise = t.replaceAll(RegExp(r'\b(movie|película|ova|special)\b'), '').replaceAll(RegExp(r'[^a-z0-9]'), '');
  final cat = inferOpenCategory(r, isMovieish ? 'movie' : 'series');
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
