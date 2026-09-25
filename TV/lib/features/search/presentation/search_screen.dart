import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:auris_core/auris_core.dart' hide FocusablePosterCard;
import '../../../shared/widgets/focusable_poster_card.dart';
import 'providers/search_provider.dart';
import 'widgets/search_widgets.dart';
import 'widgets/tv_keyboard.dart';

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
    // En TV/Desktop, el foco inicial debe estar en el teclado virtual
    Future.delayed(Duration.zero, () {
      if (mounted) {
        if (ResponsiveUtils.isMobile(context)) {
          FocusScope.of(context).requestFocus(_focusNode);
        } else {
          // El primer elemento del teclado virtual tomará el foco automáticamente 
          // si es el primer FocusNode en el árbol.
        }
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

    final contentType = result.type ?? result.kind;

    final uri = '/content/${Uri.encodeComponent(displayTitle)}'
        '?source=${Uri.encodeComponent(result.source)}'
        '&url=${Uri.encodeComponent(result.url)}'
        '&metadataTitle=${Uri.encodeComponent(metaTitle)}'
        '&banner=${Uri.encodeComponent(result.banner ?? '')}'
        '&category=${Uri.encodeComponent(openCategory)}'
        '&year=${result.year ?? ''}'
        '&totalSeasons=${result.totalSeasons ?? ''}'
        '${contentType != null ? '&type=${Uri.encodeComponent(contentType)}' : ''}';

    context.push(uri, extra: result);
  }



  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(
      searchResultsProvider(
        SearchParams(category: _selectedCategory, query: _currentQuery),
      ),
    );

    final isMobile = ResponsiveUtils.isMobile(context);
    
    // Si es móvil, mantenemos el diseño anterior más optimizado para touch
    if (isMobile) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: _buildMobileAppBar(),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _currentQuery.isEmpty 
              ? _buildPreSearchState() 
              : _buildResultsState(resultsAsync),
        ),
      );
    }

    // DISEÑO TV / DESKTOP (Basado en la imagen de referencia)
    return Scaffold(
      backgroundColor: Colors.black,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. COLUMNA IZQUIERDA: Teclado y Sugerencias
          Padding(
            padding: const EdgeInsets.fromLTRB(60, 46, 0, 20), // Reducido en 40px (86 -> 46)
            child: SizedBox(
              width: 250, 
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TVKeyboard(
                  currentQuery: _currentQuery,
                  onKeyTap: (key) {
                    final rawQuery = _searchController.text + key;
                    final newQuery = AurisStringUtils.capitalizeSearchQuery(rawQuery);
                    _searchController.text = newQuery;
                    _onSearchChanged(newQuery);
                  },
                  onBackspace: () {
                    if (_searchController.text.isNotEmpty) {
                      final newQuery = _searchController.text.substring(0, _searchController.text.length - 1);
                      _searchController.text = newQuery;
                      _onSearchChanged(newQuery);
                    }
                  },
                  onClear: _clearSearch,
                ),
                const SizedBox(height: 12), // Reducido un poco más
                Expanded(
                  child: _buildTVSuggestions(),
                ),
              ],
            ),
          ),
        ),

          // 2. COLUMNA DERECHA: Query y Resultados
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header con el query actual o "Top Searches"
                // El texto queda ARRIBA del teclado y de los posters
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 40, 0), // Reducido en 40px (60 -> 20)
                  child: SizedBox(
                    height: 40, // Reducimos altura para acercarlo a las cards
                    child: Text(
                      _currentQuery.isEmpty ? "Lo más buscado" : _currentQuery,
                      style: TextStyle(
                        color: _currentQuery.isEmpty ? Colors.white24 : Colors.white,
                        fontSize: _currentQuery.isEmpty ? 20 : 28, // Reducido de 36 a 28
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
                
                // Grid de resultados (Su borde superior coincide con el del teclado)
                Expanded(
                  child: _buildResultsState(resultsAsync, isTV: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0B0B0D),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 80,
      title: Row(
        children: [
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
          _buildFilterDropdown(),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
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
    );
  }

  Widget _buildTVSuggestions() {
    final history = ref.watch(searchHistoryProvider);
    
    // Lista base de sugerencias (Historial + Mock data de la imagen para el look & feel)
    final List<String> baseSuggestions = [
      ...history.map((e) => e.query),
      "Ryan Gosling", "Russell Crowe", "Robert Carlyle", "Reese Witherspoon", 
      "Robin Williams", "Rob Schneider", "Ryan Reynolds"
    ];

    // Si hay query, filtramos para que parezca que el sistema está sugiriendo en tiempo real
    final List<String> suggestions = _currentQuery.isEmpty 
        ? baseSuggestions.take(8).toList()
        : baseSuggestions
            .where((s) => s.toLowerCase().startsWith(_currentQuery.toLowerCase()))
            .take(8)
            .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 10), // Alineado exactamente con el padding interno del teclado (10px)
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...suggestions.map((s) => _TVSuggestionItem(
            label: s,
            onTap: () => _performSearch(s),
          )),
        ],
      ),
    );
  }

  Widget _buildPreSearchState() {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1200;

    if (isDesktop) {
      return Row(
        key: const ValueKey('pre_search_desktop'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // COLUMNA IZQUIERDA (GÉNEROS + DISCOVERY FEED)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 40, right: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SearchGenresGrid(onGenreTap: _performSearch),
                  const SizedBox(height: 8),
                  SearchDiscoveryFeed(
                    category: _selectedCategory,
                    onContentTap: _onContentTap,
                  ),
                ],
              ),
            ),
          ),
          
          // DIVISOR SUTIL
          Container(width: 1, color: Colors.white.withOpacity(0.05), margin: const EdgeInsets.symmetric(vertical: 24)),
          
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
      key: const ValueKey('pre_search_mobile'),
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        children: [
          SearchHistorySection(onQueryTap: _performSearch),
          SearchGenresGrid(onGenreTap: _performSearch),
          const SizedBox(height: 8),
          SearchDiscoveryFeed(
            category: _selectedCategory,
            onContentTap: _onContentTap,
          ),
        ],
      ),
    );
  }

  Widget _buildResultsState(AsyncValue<SearchResponse> resultsAsync, {bool isTV = false}) {
    if (isTV && _currentQuery.isEmpty) {
      final trendingAsync = ref.watch(searchTrendingProvider);
      return _buildTrendingGrid(trendingAsync);
    }

    return resultsAsync.when(
      data: (response) {
        final results = _deduplicate(response.results);
        if (results.isEmpty) return _buildNoResultsState();
        
        final isMobile = ResponsiveUtils.isMobile(context);
        final screenWidth = MediaQuery.sizeOf(context).width;

        int crossAxisCount = 3;
        if (isTV) {
          // En TV usamos 3 columnas de posters horizontales
          crossAxisCount = 3;
        } else if (!isMobile) {
          if (screenWidth > 1800) crossAxisCount = 8;
          else if (screenWidth > 1400) crossAxisCount = 7;
          else if (screenWidth > 1000) crossAxisCount = 6;
          else crossAxisCount = 5;
        }

        final notifier = ref.read(
          searchResultsProvider(
            SearchParams(category: _selectedCategory, query: _currentQuery),
          ).notifier,
        );

        return GridView.builder(
          key: const ValueKey('results_grid'),
          padding: EdgeInsets.fromLTRB(
            isMobile ? 16 : (isTV ? 20 : 40), 0, isMobile ? 16 : 40, 40
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: isTV ? 1.15 : (isMobile ? 0.54 : 0.68), // Mayor espacio vertical para TV
            crossAxisSpacing: isMobile ? 12 : 16, 
            mainAxisSpacing: isMobile ? 12 : 24, 
          ),
          itemCount: results.length + (response.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= results.length) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                notifier.loadNextPage();
              });
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFFEF7A1E),
                    ),
                  ),
                ),
              );
            }

            final result = results[index];
            final meta = result.resolveMetadata(_selectedCategory);
            return FocusablePosterCard(
              title: cleanTitleForDisplay(result.scrapedTitle ?? result.metadataTitle ?? result.title),
              posterUrl: ApiEndpoints.proxyImage(result.thumbnail, fallbackUrl: result.tmdbThumbnail),
              badge: meta.label,
              badgeColor: meta.labelColor,
              badgeOverlay: result.season != null && result.season! > 1 
                  ? SeasonBadge(
                      season: result.season!,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomRight: Radius.circular(11),
                      ),
                    ) 
                  : null,
              subtitle: meta.status,
              subtitleColor: meta.statusColor,
              activeBorderColor: const Color(0xFFE91E63),
              showInfo: true, // Títulos activados
              aspectRatio: isTV ? 1.5 : 2/3,
              onTap: () => _onContentTap(result),
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFFEF7A1E)),
      ),
      error: (err, _) => Center(
        key: const ValueKey('search_error'),
        child: Text('Error: $err', style: const TextStyle(color: Colors.white54))
      ),
    );
  }

  Widget _buildTrendingGrid(AsyncValue<List<SearchResult>> trendingAsync) {
    return trendingAsync.when(
      data: (items) {
        return GridView.builder(
          key: const ValueKey('trending_grid'),
          padding: const EdgeInsets.fromLTRB(20, 0, 40, 40),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.15, // Mayor espacio vertical para TV
            crossAxisSpacing: 16,
            mainAxisSpacing: 24,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final result = items[index];
            final meta = result.resolveMetadata(_selectedCategory);
            return FocusablePosterCard(
              title: cleanTitleForDisplay(result.scrapedTitle ?? result.metadataTitle ?? result.title),
              posterUrl: ApiEndpoints.proxyImage(result.thumbnail, fallbackUrl: result.tmdbThumbnail),
              badge: meta.label,
              badgeColor: meta.labelColor,
              badgeOverlay: result.season != null && result.season! > 1 
                  ? SeasonBadge(
                      season: result.season!,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomRight: Radius.circular(11),
                      ),
                    ) 
                  : null,
              subtitle: meta.status,
              subtitleColor: meta.statusColor,
              activeBorderColor: const Color(0xFFE91E63),
              showInfo: true, // Títulos activados
              aspectRatio: 1.5,
              onTap: () => _onContentTap(result),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFEF7A1E))),
      error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white24))),
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
          
          // RECOMENDACIONES (EL NUEVO FEED DE DESCUBRIMIENTO)
          SearchDiscoveryFeed(
            category: _selectedCategory,
            onContentTap: _onContentTap,
          ),
          
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
  // La categoría (anime/series/movie) distingue resultados que comparten
  // título pero son contenido distinto (p.ej. "One Piece" anime vs "One Piece"
  // serie). Antes solo se separaba movie/no-movie, así que anime y serie
  // colapsaban en la misma tarjeta.
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

class _TVSuggestionItem extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _TVSuggestionItem({required this.label, required this.onTap});

  @override
  State<_TVSuggestionItem> createState() => _TVSuggestionItemState();
}

class _TVSuggestionItemState extends State<_TVSuggestionItem> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select) {
            widget.onTap();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8), // Padding reducido para controlarlo vía height
          child: Text(
            widget.label,
            maxLines: 1, // Una sola línea
            overflow: TextOverflow.ellipsis, // Puntos suspensivos si es largo
            style: TextStyle(
              color: _isFocused ? Colors.white : Colors.white70,
              fontSize: 15, // Reducido de 16 a 15 para mejor jerarquía
              height: 1.8, // Interlineado solicitado
              fontWeight: _isFocused ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}


