import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

import 'package:auris_core/auris_core.dart' hide FocusablePosterCard;
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
  final FocusNode _firstResultFocusNode = FocusNode();
  final FocusNode _blurFocusNode = FocusNode();
  final String _selectedCategory = 'all';
  Timer? _debounce;
  String _currentQuery = '';
  bool _isFocused = false;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _voiceStatus = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
    // Enfocar automáticamente la barra de búsqueda al abrir la pantalla
    Future.delayed(Duration.zero, () {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  Future<void> _initSpeech() async {
    final status = await Permission.microphone.status;
    if (!status.isGranted) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) return;
    }
    final available = await _speech.initialize(
      onError: (error) {
        if (mounted) {
          setState(() {
            _isListening = false;
            _voiceStatus = '';
          });
        }
      },
      onStatus: (status) {
        if (mounted && status == 'done') {
          setState(() {
            _isListening = false;
            _voiceStatus = '';
          });
        }
      },
    );
    if (!available && mounted) {
      setState(() => _voiceStatus = 'Micrófono no disponible');
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    if (!_speech.isAvailable) {
      await _initSpeech();
      if (!_speech.isAvailable) return;
    }

    setState(() {
      _isListening = true;
      _voiceStatus = 'Escuchando…';
    });

    _speech.listen(
      localeId: 'es_ES',
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      onResult: (result) {
        if (!mounted) return;
        if (result.finalResult) {
          setState(() {
            _isListening = false;
            _voiceStatus = '';
          });
          final text = result.recognizedWords.trim();
          if (text.isNotEmpty) {
            _searchController.text = text;
            _onSearchSubmitted(text);
          }
        } else {
          setState(() => _voiceStatus = result.recognizedWords);
        }
      },
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    _firstResultFocusNode.dispose();
    _blurFocusNode.dispose();
    super.dispose();
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
    // unfocus ANTES de cualquier setState: si el rebuild toca al TextField
    // con foco y conexión de input activa, Android detecta un cambio en la
    // composing region y reinicia el IME (cierra y reabre el teclado).
    _focusNode.unfocus();
    if (query.isNotEmpty) {
      setState(() => _currentQuery = query);
      ref.read(searchHistoryProvider.notifier).addQuery(query);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_firstResultFocusNode.canRequestFocus) {
        _firstResultFocusNode.requestFocus();
      }
    });
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

    // DISEÑO TV EXCLUSIVO
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de búsqueda superior tipo TV
          Padding(
            padding: const EdgeInsets.fromLTRB(60, 40, 60, 16),
            child: Focus(
              focusNode: _blurFocusNode,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  if (_firstResultFocusNode.canRequestFocus) {
                    _firstResultFocusNode.requestFocus();
                    return KeyEventResult.handled;
                  }
                  FocusScope.of(context).focusInDirection(TraversalDirection.down);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.zero,
                  border: Border.all(
                    color: _isFocused ? const Color(0xFFEF7A1E) : Colors.white38,
                    width: _isFocused ? 2.5 : 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 20),
                    Icon(Icons.search_rounded, 
                        color: _isFocused ? const Color(0xFFEF7A1E) : Colors.white70, 
                        size: 24),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        textAlign: TextAlign.left,
                        textAlignVertical: TextAlignVertical.center,
                        style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                        inputFormatters: [CapitalizeFirstLetterFormatter()],
                        decoration: InputDecoration(
                          hintText: 'Busca una serie, película o episodio',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 18),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 20),
                                  onPressed: _clearSearch,
                                )
                              : null,
                        ),
                        onChanged: _onSearchChanged,
                        onSubmitted: _onSearchSubmitted,
                      ),
                    ),
                    const SizedBox(width: 20),
                    _buildMicButton(),
                    const SizedBox(width: 20),
                  ],
                ),
              ),
            ),
          ),

          // Título de sección ("Lo más buscado" solo cuando no hay búsqueda activa)
          if (_currentQuery.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(60, 10, 60, 12),
              child: Text(
                "Lo más buscado",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          // Grid de resultados
          const SizedBox(height: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60),
              child: _buildResultsState(resultsAsync, isTV: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicButton() {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          _toggleListening();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: _toggleListening,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isListening ? const Color(0xFFEF7A1E).withOpacity(0.25) : Colors.transparent,
          ),
          child: Icon(
            _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
            color: _isListening ? const Color(0xFFEF7A1E) : Colors.white70,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildResultsState(AsyncValue<SearchResponse> resultsAsync, {bool isTV = true}) {
    if (isTV && _currentQuery.isEmpty) {
      final trendingAsync = ref.watch(searchTrendingProvider);
      return _buildTrendingGrid(trendingAsync);
    }

    return resultsAsync.when(
      data: (response) {
        final results = _deduplicate(response.results);
        if (results.isEmpty) return _buildNoResultsState();
        
        const int crossAxisCount = 5;

        final notifier = ref.read(
          searchResultsProvider(
            SearchParams(category: _selectedCategory, query: _currentQuery),
          ).notifier,
        );

        return GridView.builder(
          key: const ValueKey('results_grid'),
          clipBehavior: Clip.none,
          padding: const EdgeInsets.fromLTRB(20, 16, 40, 40),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.55,
            crossAxisSpacing: 18, 
            mainAxisSpacing: 20, 
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
              focusNode: index == 0 ? _firstResultFocusNode : null,
              onKeyEvent: (node, event) {
                if (index < 5 && event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  _blurFocusNode.requestFocus();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
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
              activeBorderColor: Colors.white,
              titleFontSize: 11,
              showInfo: true,
              aspectRatio: 2/3,
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
        const int crossAxisCount = 5;

        return GridView.builder(
          key: const ValueKey('trending_grid'),
          clipBehavior: Clip.none,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.55,
            crossAxisSpacing: 16,
            mainAxisSpacing: 20,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final result = items[index];
            final meta = result.resolveMetadata(_selectedCategory);
            return FocusablePosterCard(
              focusNode: index == 0 ? _firstResultFocusNode : null,
              onKeyEvent: (node, event) {
                if (index < 5 && event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  _blurFocusNode.requestFocus();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
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
              activeBorderColor: Colors.white,
              titleFontSize: 11,
              showInfo: true,
              aspectRatio: 2/3,
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
          SearchDiscoveryFeed(
            category: _selectedCategory,
            onContentTap: _onContentTap,
          ),
          const SizedBox(height: 40),
          SearchGenresGrid(onGenreTap: _performSearch),
        ],
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
