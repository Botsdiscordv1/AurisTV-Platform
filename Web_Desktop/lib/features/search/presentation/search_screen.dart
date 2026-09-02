import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:auris_core/auris_core.dart';
import 'package:auristv_web/core/router/app_router.dart';
import 'package:auristv_web/core/utils/responsive_utils.dart';
import 'package:auristv_web/core/utils/url_utils.dart';
import 'package:auristv_web/shared/widgets/focusable_poster_card.dart';
import 'package:auristv_web/features/search/presentation/providers/search_provider.dart';
import 'package:auristv_web/features/search/presentation/widgets/search_widgets.dart';

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

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _searchController;
  final _focusNode = FocusNode();
  late String _selectedCategory;
  Timer? _debounce;
  late String _currentQuery;
  bool _isFocused = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _currentQuery = widget.initialQuery;
    _selectedCategory = widget.initialCategory;
    _searchController = TextEditingController(text: _currentQuery);
    
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    // Senior Fix: Evitar tocar el estado si el widget ya no existe
    if (!mounted || _isNavigating) return;
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
    _isNavigating = true;
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
    // Senior Fix: Si estamos destruyendo la pantalla, nos callamos
    if (!mounted || _isNavigating) return;

    final router = GoRouter.of(context);
    final String currentGlobalPath = router.routeInformationProvider.value.uri.path;
    if (currentGlobalPath != '/catalogo') return;

    final uri = Uri(
      path: '/catalogo',
      queryParameters: {
        if (_currentQuery.isNotEmpty) 'q': _currentQuery,
        if (_selectedCategory != 'all') 'cat': _selectedCategory,
      },
    );
    
    final String currentFullUrl = router.routeInformationProvider.value.uri.toString();
    if (currentFullUrl != uri.toString()) {
      router.replace(uri.toString());
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
      if (mounted && !_isNavigating) {
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
    // Senior Fix: Bloqueo total y transición atómica
    _isNavigating = true;
    _debounce?.cancel();
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
    );

    // Senior Web Fix: Usamos .go para forzar la URL /media/ y limpiar el Shell.
    context.go(shareableUri, extra: result);
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
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [CapitalizeWordsFormatter()],
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
            ),
            const SizedBox(width: 12),
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
                  RepaintBoundary(child: SearchGenresGrid(onGenreTap: _performSearch)),
                  const SizedBox(height: 32),
                  RepaintBoundary(child: SearchTrendingSection(onTrendingTap: _onContentTap)),
                ],
              ),
            ),
          ),
          Container(width: 1, color: Colors.white.withOpacity(0.05), margin: const EdgeInsets.symmetric(vertical: 24)),
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
          RepaintBoundary(child: SearchHistorySection(onQueryTap: _performSearch)),
          RepaintBoundary(child: SearchGenresGrid(onGenreTap: _performSearch)),
          const SizedBox(height: 16),
          RepaintBoundary(child: SearchTrendingSection(onTrendingTap: _onContentTap)),
        ],
      ),
    );
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
          if (screenWidth > 1800) crossAxisCount = 8;
          else if (screenWidth > 1400) crossAxisCount = 7;
          else if (screenWidth > 1000) crossAxisCount = 6;
          else crossAxisCount = 5;
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
              final info = _cardInfo(result, category);
              return FocusablePosterCard(
                key: ValueKey('search_${result.url}_${result.source}'),
                title: cleanTitleForDisplay(result.scrapedTitle ?? result.metadataTitle ?? result.title),
                posterUrl: ApiEndpoints.proxyImage(result.thumbnail),
                badge: info['format'] as String?,
                badgeColor: info['formatColor'] as Color?,
                subtitle: info['status'] as String?,
                subtitleColor: info['statusColor'] as Color?,
                onTap: () => onContentTap(result),
              );
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
          SearchTrendingSection(onTrendingTap: (res) => onContentTap(res)),
          const SizedBox(height: 40),
          SearchGenresGrid(onGenreTap: (q) {
          }),
        ],
      ),
    );
  }
}

String _fuseKey(SearchResult r) {
  final t = r.title.toLowerCase();
  final franchise = t.replaceAll(RegExp(r'\b(movie|película|ova|special)\b'), '').replaceAll(RegExp(r'[^a-z0-9]'), '');
  return '$franchise#${r.type}';
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

Map<String, dynamic> _cardInfo(SearchResult result, String selectedCategory) {
  String? format = result.type?.toUpperCase() ?? selectedCategory.toUpperCase();
  String? statusLabel;
  Color? statusColor;
  final s = (result.status ?? '').toLowerCase();
  if (s.contains('emisi')) {
    statusLabel = 'EN EMISIÓN';
    statusColor = const Color(0xFFEF7A1E); 
  } else if (s.contains('finaliz') || s.contains('complet')) {
    statusLabel = 'FINALIZADO';
    statusColor = Colors.black.withOpacity(0.9);
  }

  return {
    'format': format,
    'formatColor': const Color(0xFF1976D2), 
    'status': statusLabel,
    'statusColor': statusColor,
  };
}
