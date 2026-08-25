import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:auris_core/auris_core.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../shared/widgets/focusable_poster_card.dart';
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
    final displayTitle = result.scrapedTitle ?? result.metadataTitle ?? result.title;
    final metaTitle = result.metadataTitle ?? result.scrapedTitle ?? result.title;
    ref.read(searchHistoryProvider.notifier).addQuery(result.title);
    final openCategory = result.kind?.toLowerCase() == 'movie' ? 'movie' : _selectedCategory;
    context.push(
      '/content/${Uri.encodeComponent(displayTitle)}?source=${Uri.encodeComponent(result.source)}&url=${Uri.encodeComponent(result.url)}&metadataTitle=${Uri.encodeComponent(metaTitle)}&banner=${Uri.encodeComponent(result.banner ?? '')}&category=${Uri.encodeComponent(openCategory)}&year=${result.year ?? ''}&totalSeasons=${result.totalSeasons ?? ''}',
      extra: result,
    );
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
                    color: _isFocused ? const Color(0xFFEF7A1E) : Colors.white.withValues(alpha: 0.05),
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  textAlign: TextAlign.left, // Texto alineado a la izquierda
                  textAlignVertical: TextAlignVertical.center, // Centrado vertical respecto al icono
                  style: const TextStyle(fontSize: 15, color: Colors.white),
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
                    isDense: true, // Ayuda al centrado vertical real
                    contentPadding: EdgeInsets.zero, // Eliminamos paddings extra que rompen el centro vertical
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
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
    final isDesktop = MediaQuery.sizeOf(context).width >= 1200;

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // COLUMNA IZQUIERDA (GÉNEROS + TRENDING)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 40, right: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SearchGenresGrid(onGenreTap: _performSearch),
                  const SizedBox(height: 32),
                  SearchTrendingSection(onTrendingTap: _onContentTap),
                ],
              ),
            ),
          ),
          
          // DIVISOR SUTIL
          Container(width: 1, color: Colors.white.withValues(alpha: 0.05), margin: const EdgeInsets.symmetric(vertical: 24)),
          
          // COLUMNA DERECHA (SIDEBAR HISTORIAL)
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
            childAspectRatio: isMobile ? 0.54 : 0.58, // Senior Fix: Ajustado a 0.58 para eliminar el overflow de 12px
            crossAxisSpacing: isMobile ? 12 : 20, 
            mainAxisSpacing: isMobile ? 12 : 16, 
          ),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final result = results[index];
            final info = _cardInfo(result);
            return FocusablePosterCard(
              title: cleanTitleForDisplay(result.scrapedTitle ?? result.metadataTitle ?? result.title),
              posterUrl: ApiEndpoints.proxyImage(result.thumbnail),
              badge: info['format'] as String?,
              badgeColor: info['formatColor'] as Color?,
              subtitle: info['status'] as String?,
              subtitleColor: info['statusColor'] as Color?,
              onTap: () => _onContentTap(result),
            );
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
          // MENSAJE PRINCIPAL
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
          
          // RECOMENDACIONES (EL TOP 10 RECIÉN CREADO)
          SearchTrendingSection(onTrendingTap: _onContentTap),
          
          const SizedBox(height: 40),
          
          // EXPLORACIÓN POR GÉNEROS
          SearchGenresGrid(onGenreTap: _performSearch),
        ],
      ),
    );
  }
}

// Clave de fusión: agrupa por franquicia base + tipo de media (película vs serie),
// para unir "Youjo Senki Movie" (AV1) y "Youjo Senki Pelicula" (AnimeJara) en una
// sola tarjeta sin confundir la película con la serie "Youjo Senki".
String _fuseKey(SearchResult r) {
  final t = r.title.toLowerCase();
  final typeRe = RegExp(r'\b(movie|pel[íi]cula|film|ova|special|oav)\b');
  final isMovieish = typeRe.hasMatch(t);
  final franchise = t.replaceAll(typeRe, '').replaceAll(RegExp(r'[^a-z0-9]'), '');
  return '$franchise#${isMovieish ? 'm' : 't'}';
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
        sources: mergedSources,
      );
    }
  }
  return grouped.values.toList();
}

Map<String, dynamic> _cardInfo(SearchResult result) {
  final raw = result.quality.toUpperCase();
  // El formato va arriba a la derecha. Se prioriza el `type` del server
  // (Película/TV/OVA/ONA/Especial), que es el clasificador fiable, frente a
  // parsear `quality` (el meta de AV1 puede sobrescribirlo erróneamente).
  final String typeLabel;
  if (result.type != null && result.type!.isNotEmpty) {
    final up = result.type!.toUpperCase();
    typeLabel = up == 'TV' ? 'TV ANIME' : up;
  } else {
    typeLabel = raw.contains('•') ? raw.split('•').first.trim() : (result.kind == 'movie' ? 'PELÍCULA' : 'TV ANIME');
  }
  final format = typeLabel;

  // El estado va abajo a la izquierda.
  String? statusLabel;
  Color? statusColor;
  final s = (result.status ?? '').toLowerCase();
  if (s.contains('emisi')) {
    statusLabel = 'EN EMISIÓN';
    statusColor = const Color(0xFFEF7A1E); // AurisTV Brand Orange
  } else if (s.contains('finaliz') || s.contains('complet')) {
    statusLabel = 'FINALIZADO';
    statusColor = Colors.black.withValues(alpha: 0.9);
  }

  return {
    'format': format,
    'formatColor': const Color(0xFF1976D2), // Azul
    'status': statusLabel,
    'statusColor': statusColor,
  };
}

