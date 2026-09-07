import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:auris_core/auris_core.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/utils/web_utils.dart';
import '../widgets/content_row.dart';
import '../widgets/editorial_content_row.dart';
import '../widgets/wide_content_row.dart';
import '../../../shared/widgets/airing_countdown_badge.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Senior Fix: Bajamos el umbral a 5px para una respuesta inmediata al tacto (Estilo iOS)
    final scrolled = _scrollController.offset > 5;
    if (scrolled != _isScrolled) {
      setState(() => _isScrolled = scrolled);
    }
  }

  void _openDetails(BuildContext context, MediaItem item, String uiCategory) {
    // Senior Logic: Si estamos en Inicio, el tipo de contenido (Anime/Movie/Drama)
    // manda sobre la categoría de la UI para asegurar que el detalle abra el servidor correcto.
    final String category = switch (uiCategory) {
      'inicio' => switch (item.type) {
        MediaType.movie => 'movie',
        MediaType.kdrama => 'kdrama',
        _ => 'anime',
      },
      'animes' => 'anime',
      'anime_movies' => 'movie_anime',
      'películas' => 'movie',
      'kdrama' => 'kdrama',
      _ => 'all',
    };
    
    final source = item.source.isNotEmpty ? item.source : category;
    final metaTitle = item.romaji ?? item.english ?? item.title;
    final effectiveUrl = item.detailUrl ?? item.id;
    final String? kind = item.card?.kind;

    final uri = '/content/${Uri.encodeComponent(item.title)}'
        '?source=${Uri.encodeComponent(source)}'
        '&category=${Uri.encodeComponent(category)}'
        '&url=${Uri.encodeComponent(effectiveUrl)}'
        '&metadataTitle=${Uri.encodeComponent(metaTitle)}'
        '&banner=${Uri.encodeComponent(item.bannerUrl ?? '')}'
        '&year=${item.year ?? ''}'
        '${kind != null ? '&type=${Uri.encodeComponent(kind)}' : ''}';
        
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.push(uri, extra: item.toContentSeed());
    });
  }

  List<Widget> _buildEditorialRows(
    AsyncValue<List<EditorialRow>> editorials,
    void Function(BuildContext, MediaItem, String) onTap,
    String category, {
    bool includeMovies = false,
    String movieCategory = 'anime_movies',
  }) {
    return editorials.when(
      data: (rows) {
        final list = <Widget>[];
        for (final row in rows) {
          if (row.isMovie && !includeMovies) continue;
          if (row.items.isEmpty) continue;
          
          // Senior Logic: Si estamos en inicio, no forzamos subcategorías de películas
          // para que el ruteo sea 100% dinámico por MediaItem.
          final targetCat = (category == 'inicio') ? 'inicio' : (row.isMovie ? movieCategory : category);

          if (row.format == RowFormat.horizontal) {
            list.add(SliverToBoxAdapter(
              child: RepaintBoundary(
                child: WideContentRow(
                  title: row.title,
                  items: row.items.map((m) => _wideItemFromMedia(m)).toList(),
                  onItemTap: (wideItem) => onTap(context, wideItem.originalItem as MediaItem, targetCat),
                ),
              ),
            ));
          } else {
            list.add(SliverToBoxAdapter(
              child: RepaintBoundary(
                child: EditorialContentRow(
                  title: row.title,
                  items: row.items,
                  badge: row.badge,
                  onItemTap: (item) => onTap(context, item, targetCat),
                ),
              ),
            ),);
          }
        }
        return list;
      },
      loading: () => List.generate(3, (index) => const SliverToBoxAdapter(
        child: const RowSkeleton(isWide: false),
      )),
      error: (err, _) => [
        SliverToBoxAdapter(child: Center(child: Text('Error editorial: $err', style: const TextStyle(color: Colors.white24)))),
      ],
    );
  }

  Widget _buildSection(HomeLayoutSection section, double horizontalPadding) {
    switch (section.type) {
      case HomeSectionType.continueWatching:
        final continueWatchingAsync = ref.watch(continueWatchingProvider);
        
        return continueWatchingAsync.when(
          data: (items) {
            if (items.isEmpty) return const SizedBox.shrink();

            return WideContentRow(
              title: 'Continuar Viendo',
              items: items.map((h) {
                final bool useEpisodeThumb = _isHighQualityThumbnail(h.posterUrl);
                final String finalImageUrl = useEpisodeThumb ? (h.posterUrl ?? '') : (h.bannerUrl ?? h.posterUrl ?? '');

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
                  imageUrl: finalImageUrl,
                  progress: h.progress,
                  subtitle: remainingText,
                  onDelete: () {
                    ref.read(playbackHistoryStateProvider.notifier).deleteProgress(h.contentId, h.season, h.episode);
                  },
                  originalItem: h,
                );
              }).toList(),
              onItemTap: (wideItem) {
                final item = wideItem.originalItem as PlaybackHistory;
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
              },
            );
          },
          loading: () => RowSkeleton(isWide: true),
          error: (_, __) => const SizedBox.shrink(),
        );

      case HomeSectionType.editorial:
        final row = section.data as EditorialRow;
        if (row.format == RowFormat.horizontal) {
          return WideContentRow(
            title: row.title,
            items: row.items.map((m) => _wideItemFromMedia(m)).toList(),
            onItemTap: (wideItem) => _openDetails(context, wideItem.originalItem as MediaItem, 'inicio'),
          );
        } else {
          return EditorialContentRow(
            title: row.title,
            items: row.items,
            badge: row.badge,
            onItemTap: (item) => _openDetails(context, item, 'inicio'),
          );
        }

      case HomeSectionType.top10Global:
        final top10Async = ref.watch(top10GlobalProvider);
        return top10Async.when(
          data: (items) => EditorialContentRow(
            title: section.title ?? 'Top 10 de hoy',
            items: items,
            badge: EditorialBadge.mythical,
            onItemTap: (item) => _openDetails(context, item, 'inicio'),
          ),
          loading: () => RowSkeleton(),
          error: (err, _) => const SizedBox.shrink(),
        );

      case HomeSectionType.recentlyAdded:
        final recentAddedAsync = ref.watch(recentlyAddedProvider);
        return recentAddedAsync.when(
          data: (items) => ContentRow(
            title: section.title ?? 'Recién añadido a AurisTV',
            items: items,
            horizontalPadding: horizontalPadding,
            onItemTap: (item) => _openDetails(context, item, 'inicio'),
          ),
          loading: () => RowSkeleton(),
          error: (err, _) => const SizedBox.shrink(),
        );

      case HomeSectionType.trendingAnime:
        final trendingAsync = ref.watch(trendingListProvider('animes'));
        return trendingAsync.when(
          data: (items) => ContentRow(
            title: section.title ?? 'Animes en tendencia',
            items: items,
            horizontalPadding: horizontalPadding,
            onItemTap: (item) => _openDetails(context, item, 'animes'),
          ),
          loading: () => RowSkeleton(),
          error: (err, _) => const SizedBox.shrink(),
        );

      case HomeSectionType.trendingMovies:
        final movieTrendingAsync = ref.watch(trendingListProvider('películas'));
        return movieTrendingAsync.when(
          data: (items) => WideContentRow(
            title: section.title ?? 'Películas destacadas',
            items: items.map((m) => _wideItemFromMedia(m)).toList(),
            onItemTap: (wideItem) => _openDetails(context, wideItem.originalItem as MediaItem, 'películas'),
          ),
          loading: () => RowSkeleton(isWide: true),
          error: (err, _) => const SizedBox.shrink(),
        );

      case HomeSectionType.recentEpisodes:
        final recentAsync = ref.watch(recentEpisodesProvider);
        return recentAsync.when(
          data: (items) => WideContentRow(
            title: section.title ?? 'Estrenos (Hoy)',
            items: items.map((m) => _wideItemFromMedia(
              m,
              badgeOverlay: m.airingAt != null ? AiringCountdownBadge(airingAt: m.airingAt!, aired: m.aired) : null,
            )).toList(),
            onItemTap: (wideItem) => _openScheduleItem(context, wideItem.originalItem as MediaItem),
          ),
          loading: () => RowSkeleton(isWide: true),
          error: (err, _) => const SizedBox.shrink(),
        );
    }
  }

  void _openScheduleItem(BuildContext context, MediaItem item) {
    final metaTitle = item.romaji ?? item.english ?? item.title;
    final itemYear = item.year ??
        (item.airingAt != null
            ? DateTime.fromMillisecondsSinceEpoch(item.airingAt! * 1000).year
            : null);

    final seed = item.card;
    final source = seed?.source ?? item.source;
    final url = seed?.url ?? item.id;
    final quality = seed?.quality ?? '';
    final type = seed?.type ?? '';

    final uri =
        '/content/${Uri.encodeComponent(item.title)}?source=${Uri.encodeComponent(source)}&category=anime&url=${Uri.encodeComponent(url)}&metadataTitle=${Uri.encodeComponent(metaTitle)}&banner=&year=${itemYear ?? ''}&quality=${Uri.encodeComponent(quality)}&type=${Uri.encodeComponent(type)}';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.push(uri, extra: item.toContentSeed());
    });
  }

  WideContentItem _wideItemFromMedia(MediaItem m, {Widget? badgeOverlay}) => WideContentItem(
        id: m.id,
        title: m.title,
        imageUrl: m.bannerUrl ?? m.posterUrl,
        subtitle: m.subtitle,
        rating: formatRating(m.rating),
        badgeOverlay: badgeOverlay,
        originalItem: m,
      );

  bool _isHighQualityThumbnail(String? url) {
    if (url == null || url.isEmpty) return false;
    // Senior Logic: Solo consideramos alta calidad las imágenes de TMDB, AniList u OMDB.
    // Las miniaturas de servidores (JK, AV1, Any) suelen ser capturas de baja resolución.
    final highResHints = ['tmdb.org', 'anilist.co', 'amazon.com', 'googleusercontent.com', 'blogspot.com'];
    return highResHints.any((hint) => url.contains(hint));
  }

  @override
  Widget build(BuildContext context) {
    final currentCategory = ref.watch(homeCategoryProvider);
    final isMobile = ResponsiveUtils.isMobile(context);
    final width = MediaQuery.of(context).size.width;

    // Breakpoints granulares para escritorio (Navbar / Spacer)
    final isCompactDesktop = width >= 800 && width < 1100;

    final horizontalPadding = ResponsiveUtils.horizontalPadding(context);
    
    // Senior Performance: Disparamos la precarga de todas las categorías en segundo plano.
    // Usamos un delay más largo para dar prioridad absoluta al HeroBanner y contenido inicial.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) ref.read(homePrefetchProvider);
      });
    });
    
    // Providers de datos reales
    final layoutAsync = ref.watch(homeLayoutProvider);
    final heroBannerItemsAsync = ref.watch(heroBannerItemsProvider(currentCategory));
    final trendingAsync = ref.watch(trendingListProvider(currentCategory));
    final recentAsync = ref.watch(recentEpisodesProvider);
    final movieTrendingAsync = ref.watch(trendingListProvider('películas'));
    final animeMoviesAsync = ref.watch(animeMoviesProvider);
    final editorialRowsAsync = ref.watch(editorialRowsProvider);

    // Senior Logic: Una vez que el provider deja de estar en carga (ya sea éxito o error),
    // mandamos la señal al index.html para desvanecer y eliminar el Splash Screen.
    if (!editorialRowsAsync.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WebUtils.removeSplashScreen();
      });
    }

    // Datos con fallback automático a MockData para que el diseño NUNCA se rompa
    final trendingItems = (trendingAsync.valueOrNull != null && trendingAsync.valueOrNull!.isNotEmpty)
        ? trendingAsync.valueOrNull!
        : MockData.anime;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D), // Senior Recomienda: Rich Black para evitar OLED Smearing
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Espaciador para que el contenido empiece debajo de la barra fija
              SliverToBoxAdapter(
                child: SizedBox(height: isMobile 
                  ? (MediaQuery.of(context).padding.top + 60) 
                  : 0 // Senior Fix: En Web el banner sangra hasta arriba (detrás de la barra)
                ),
              ),

              // 1. Banner Principal con Datos Curados por Categoría
              heroBannerItemsAsync.when(
                data: (displayItems) => SliverToBoxAdapter(
                  child: HeroBanner(
                    key: ValueKey('hero_mob_$currentCategory'), // Senior Fix: Reset total al cambiar categoría
                    autofocus: true,
                    items: displayItems,
                    currentCategory: currentCategory,
                    onPlay: (item) => _openDetails(context, item, currentCategory),
                    onDetails: (item) => _openDetails(context, item, currentCategory),
                    onTrailer: (item) async {
                      // Senior Fix: Extraer Stream Directo para el Player Nativo
                      final directUrl = await YoutubeResolver.getDirectStreamUrl(item.trailerKey!);
                      if (directUrl != null && context.mounted) {
                        final posterParam = '&posterUrl=${Uri.encodeComponent(item.posterUrl ?? '')}&bannerUrl=${Uri.encodeComponent(item.bannerUrl ?? '')}';
                        final uri = '/player/${Uri.encodeComponent(item.title)}'
                            '?source=YouTube'
                            '&url=${Uri.encodeComponent(directUrl)}'
                            '&episode=Trailer'
                            '&serverName=YouTube'
                            '&language=Trailer'
                            '&totalEpisodes=1'
                            '&category=${item.type.name}'
                            '$posterParam';
                        context.push(uri);
                      }
                    },
                  ),
                ),
                loading: () => const SliverToBoxAdapter(child: HeroBannerSkeleton()),
                error: (err, _) => SliverToBoxAdapter(
                  child: HeroBanner(
                    autofocus: true,
                    items: MockData.featuredItems,
                    currentCategory: currentCategory,
                    onPlay: (item) => _openDetails(context, item, currentCategory),
                    onDetails: (item) => _openDetails(context, item, currentCategory),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // 2. Contenido dinámico con Server-Driven UI Lite
              if (currentCategory == 'inicio') 
                layoutAsync.when(
                  data: (sections) => SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final section = sections[index];
                        return _buildSection(section, horizontalPadding);
                      },
                      childCount: sections.length,
                    ),
                  ),
                  loading: () => SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SizedBox(height: 12), // Senior Fix: Separador para el primer skeleton
                        ...List.generate(3, (index) => const RowSkeleton()),
                      ],
                    ),
                  ),
                  error: (err, _) => SliverToBoxAdapter(child: Center(child: Text('Error layout: $err'))),
                )
              else if (currentCategory == 'animes') ...[
                  recentAsync.when(
                  data: (items) => SliverToBoxAdapter(
                    child: WideContentRow(
                      key: const ValueKey('recent_animes'),
                      title: 'Estrenos (Hoy)',
                      items: items.map((m) => _wideItemFromMedia(
                        m,
                        badgeOverlay: m.airingAt != null
                            ? AiringCountdownBadge(airingAt: m.airingAt!, aired: m.aired)
                            : null,
                      )).toList(),
                      onItemTap: (wideItem) => _openScheduleItem(context, wideItem.originalItem as MediaItem),
                    ),
                  ),
                  loading: () => SliverToBoxAdapter(child: RowSkeleton(isWide: true)),
                  error: (err, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                ),
                
                trendingAsync.when(
                  data: (items) => SliverToBoxAdapter(
                    child: ContentRow(
                      key: const ValueKey('trending_seasonal'),
                      title: 'Populares esta temporada',
                      items: items,
                      horizontalPadding: horizontalPadding,
                      onItemTap: (item) => _openDetails(context, item, 'animes'),
                    ),
                  ),
                  loading: () => SliverToBoxAdapter(child: RowSkeleton()),
                  error: (err, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                ),

                ..._buildEditorialRows(editorialRowsAsync, _openDetails,
                    'animes', includeMovies: true,
                    movieCategory: 'anime_movies'),
              ]
else if (currentCategory == 'películas') ...[
                SliverToBoxAdapter(
                  child: WideContentRow(
                    key: const ValueKey('trending_movies'),
                    title: 'Cine Recomendado',
                    items: trendingItems.map((m) => _wideItemFromMedia(m)).toList(),
                    onItemTap: (wideItem) => _openDetails(context, wideItem.originalItem as MediaItem, 'películas'),
                  ),
                ),
              ] else if (currentCategory == 'series') ...[
                SliverToBoxAdapter(
                  child: ContentRow(
                    key: const ValueKey('trending'),
                    title: 'Series y Dramas Populares',
                    items: trendingItems,
                    horizontalPadding: horizontalPadding,
                    onItemTap: (item) => _openDetails(context, item, 'series'),
                  ),
                ),
              ] else if (currentCategory == 'kdrama') ...[
                SliverToBoxAdapter(
                  child: ContentRow(
                    key: const ValueKey('trending_kdrama'),
                    title: 'Doramas Populares',
                    items: trendingItems,
                    horizontalPadding: horizontalPadding,
                    onItemTap: (item) => _openDetails(context, item, 'kdrama'),
                  ),
                ),
              ],
              
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
            ],
          ),
          
          // La navegación flota sobre el contenido (Fija en la parte superior)
          Positioned(
            top: 0, left: 0, right: 0,
            child: _buildTopNavContent(context, ref, currentCategory, isMobile),
          ),
        ],
      ),
    );
  }

  Widget _buildTopNavContent(BuildContext context, WidgetRef ref, String currentCategory, bool isMobile) {
    final width = MediaQuery.of(context).size.width;
    
    // Breakpoints granulares para escritorio
    final isCompactDesktop = width >= 800 && width < 1100;
    
    final horizontalPadding = ResponsiveUtils.horizontalPadding(context);
    final logoHeight = isCompactDesktop ? 28.0 : 32.0;
    final navHeight = isCompactDesktop ? 70.0 : 80.0;
    
    if (isMobile) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: _isScrolled ? 15.0 : 0.0,
            sigmaY: _isScrolled ? 15.0 : 0.0,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: _isScrolled 
                  ? const Color(0xFF0B0B0D).withValues(alpha: 0.6) 
                  : const Color(0xFF0B0B0D), 
              border: Border(
                bottom: BorderSide(
                  color: _isScrolled ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
                  width: 0.5,
                ),
              ),
            ),
            // Senior Fix: Reducimos padding para un look más compacto y fijo (como pidió el usuario)
            padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 12),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 40, // Senior Fix: Altura fija absoluta para evitar cualquier "salto" vertical
                child: Row(
                  children: [
                    // 1. Logo ESTÁTICO
                    SvgPicture.asset(
                      'assets/icons/auris-tv-icon.svg',
                      height: 30,
                      fit: BoxFit.contain,
                      colorFilter: const ColorFilter.mode(Color(0xFFEF7A1E), BlendMode.srcIn),
                    ),
                    const SizedBox(width: 16),
                    
                    // 2. Contenido ANIMADO con Coreografía Refinada
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 700), // Senior: Más lento para máxima elegancia
                        switchInCurve: Curves.easeInOutQuart, // Senior: Curva muy suave en los extremos
                        switchOutCurve: Curves.easeInOutQuart,
                        transitionBuilder: (child, animation) {
                          final isFilter = child.key == const ValueKey('home_nav_filter');
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                // Senior Fix: Aumentamos el recorrido (0.4) para que incluso 
                                // distancias cortas tengan un "viaje" visible y lento.
                                begin: Offset(isFilter ? 0.4 : -0.4, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: (currentCategory == 'inicio')
                            ? Row(
                                key: const ValueKey('home_nav_full'),
                                children: [
                                  Expanded(
                                    child: ShaderMask(
                                      shaderCallback: (Rect rect) {
                                        return const LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [Colors.black, Colors.transparent],
                                          stops: [0.8, 1.0], // Senior UI: Desvanecimiento sutil al final para indicar scroll
                                        ).createShader(rect);
                                      },
                                      blendMode: BlendMode.dstIn,
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        physics: const BouncingScrollPhysics(),
                                        padding: const EdgeInsets.only(right: 20), // Espacio para que el desvanecimiento luzca mejor
                                        child: _PillNavBar(
                                          currentCategory: currentCategory,
                                          hideHome: true,
                                          onCategoryChanged: (cat) => ref.read(homeCategoryProvider.notifier).state = cat,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                key: const ValueKey('home_nav_filter'),
                                children: [
                                  GestureDetector(
                                    onTap: () => ref.read(homeCategoryProvider.notifier).state = 'inicio',
                                    child: Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      currentCategory[0].toUpperCase() + currentCategory.substring(1),
                                      style: GoogleFonts.poppins(
                                        color: Colors.black,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: _isScrolled ? 20.0 : 0.0,
          sigmaY: _isScrolled ? 20.0 : 0.0,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: navHeight,
          margin: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: _isScrolled 
                ? const Color(0xFF0B0B0D).withValues(alpha: 0.4) 
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: _isScrolled ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
                width: 0.5,
              ),
            ),
          ),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Row(
              children: [
                // Logo de Auris (Naranja de marca)
                SvgPicture.asset(
                  'assets/icons/auris-logo-web-flat.svg',
                  height: logoHeight,
                  fit: BoxFit.contain,
                  colorFilter: const ColorFilter.mode(Color(0xFFEF7A1E), BlendMode.srcIn),
                ),
                SizedBox(width: isCompactDesktop ? 20 : 40),
                
                // Items de Navegación Estilo Píldora (Modern Netflix)
                _PillNavBar(
                  currentCategory: currentCategory,
                  onCategoryChanged: (cat) => ref.read(homeCategoryProvider.notifier).state = cat,
                ),
                
                const Spacer(),
                
                // Acciones (Derecha)
                const SizedBox(width: 8),
                _FocusIconButton(
                  icon: Icons.search,
                  size: isCompactDesktop ? 22 : 26,
                  onPressed: () => context.push('/search'),
                ),
                const SizedBox(width: 12),
                _LanguageSelector(isCompact: isCompactDesktop),
                const SizedBox(width: 12),
                _FocusIconButton(
                  icon: Icons.grid_view_rounded,
                  size: isCompactDesktop ? 22 : 26,
                  onPressed: () => context.push('/schedule'),
                ),
                const SizedBox(width: 12),
                _buildUserAvatar(context, isCompactDesktop),
                const SizedBox(width: 20),
                
                // Botón de Autenticación
                _AuthButton(isCompactDesktop: isCompactDesktop),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar(BuildContext context, bool isCompact) {
    return Consumer(
      builder: (context, ref, _) {
        final user = ref.watch(authProvider);
        final bool isLoggedIn = user != null;

        if (!isLoggedIn) {
          return _FocusIconButton(
            icon: Icons.person_outline_rounded,
            size: isCompact ? 20 : 22,
            onPressed: () => context.push('/settings'),
          );
        }

        return _FocusIconButton(
          onPressed: () => context.push('/settings'),
          child: Container(
            width: isCompact ? 28 : 32,
            height: isCompact ? 28 : 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 1.5),
              image: user.photoUrl != null
                  ? DecorationImage(
                      image: user.photoUrl!.startsWith('assets/')
                          ? AssetImage(user.photoUrl!) as ImageProvider
                          : NetworkImage(user.photoUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: user.photoUrl == null
                ? Icon(Icons.person, size: isCompact ? 16 : 18, color: Colors.white70)
                : null,
          ),
        );
      },
    );
  }
}

class _AuthButton extends StatefulWidget {
  final bool isCompactDesktop;
  const _AuthButton({required this.isCompactDesktop});

  @override
  State<_AuthButton> createState() => _AuthButtonState();
}

class _AuthButtonState extends State<_AuthButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final user = ref.watch(authProvider);
        final bool isLoggedIn = user != null;

        if (isLoggedIn) return const SizedBox.shrink();

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              boxShadow: _isHovered ? [
                BoxShadow(
                  color: const Color(0xFFEF7A1E).withValues(alpha: 0.5),
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              ] : [],
            ),
            child: ElevatedButton(
              onPressed: () {
                context.push('/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF7A1E),
                foregroundColor: Colors.white,
                minimumSize: Size(0, widget.isCompactDesktop ? 36 : 42),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                elevation: 0,
              ),
              child: Text(
                'Iniciar sesión', 
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w800, 
                  fontSize: widget.isCompactDesktop ? 13 : 15,
                  letterSpacing: 0.5,
                )
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CategoryChip extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = widget.isActive;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          clipBehavior: Clip.antiAlias, // Senior Fix: Cortar bordes internos para que sigan la curva
          decoration: BoxDecoration(
            color: isSelected 
                ? const Color(0xFF505459) 
                : (_isHovered ? Colors.white.withValues(alpha: 0.05) : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ] : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isSelected) ...[
                // Borde Superior (Brillo)
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(
                    height: 1,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
                // Borde Inferior (Sombra)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    height: 1,
                    color: Colors.black.withOpacity(0.20),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: const Color(0xFFF5F5F5),
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillNavBar extends StatelessWidget {
  final String currentCategory;
  final ValueChanged<String> onCategoryChanged;
  final bool hideHome;

  const _PillNavBar({
    required this.currentCategory,
    required this.onCategoryChanged,
    this.hideHome = false,
  });

  double _calculateTextWidth(String text) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return textPainter.size.width;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    final allCategories = [
      {'id': 'inicio', 'label': 'Inicio'},
      {'id': 'animes', 'label': 'Animes'},
      {'id': 'películas', 'label': 'Películas'},
      {'id': 'series', 'label': 'Series'},
      {'id': 'kdrama', 'label': 'KDramas'},
    ];

    final categories = hideHome 
        ? allCategories.where((c) => c['id'] != 'inicio').toList()
        : allCategories;

    // Senior UI Fix: Reducimos padding en móvil para que el 4to item asome (Affordance)
    final double hPadding = isMobile ? 24.0 : 36.0; 
    const double spacing = 8.0;
    
    final List<double> itemWidths = categories.map((c) => _calculateTextWidth(c['label']!) + hPadding).toList();
    final activeIndex = categories.indexWhere((c) => c['id'] == currentCategory);
    
    // Senior Logic: Si estamos en una categoria oculta (como inicio en movil), 
    // no mostramos la pildora de seleccion.
    final bool showPill = activeIndex != -1;

    double leftOffset = 0;
    if (showPill) {
      for (int i = 0; i < activeIndex; i++) {
        leftOffset += itemWidths[i] + spacing;
      }
    }

    return SizedBox(
      height: 40,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // LA PÍLDORA (El fondo que desliza)
          if (showPill)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              left: leftOffset,
              child: Container(
                width: itemWidths[activeIndex],
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          
          // LOS TEXTOS
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(categories.length, (index) {
              final cat = categories[index];
              final isSelected = index == activeIndex;
              return Padding(
                padding: EdgeInsets.only(right: index == categories.length - 1 ? 0 : spacing),
                child: _PillNavItem(
                  label: cat['label']!,
                  isActive: isSelected,
                  width: itemWidths[index],
                  onTap: () => onCategoryChanged(cat['id']!),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _PillNavItem extends StatefulWidget {
  final String label;
  final bool isActive;
  final double width;
  final VoidCallback onTap;

  const _PillNavItem({
    required this.label,
    required this.isActive,
    required this.width,
    required this.onTap,
  });

  @override
  State<_PillNavItem> createState() => _PillNavItemState();
}

class _PillNavItemState extends State<_PillNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: widget.width,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: (!widget.isActive && _hovered) ? Colors.white.withOpacity(0.1) : Colors.transparent,
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: GoogleFonts.poppins(
              color: widget.isActive ? Colors.black : Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700, // Senior Fix: Unificamos a w700 para consistencia total
            ),
            child: Text(widget.label),
          ),
        ),
      ),
    );
  }
}

class _FocusIconButton extends StatefulWidget {
  final IconData? icon;
  final Widget? child;
  final VoidCallback onPressed;
  final double size;

  const _FocusIconButton({
    this.icon,
    this.child,
    required this.onPressed,
    this.size = 28,
  });

  @override
  State<_FocusIconButton> createState() => _FocusIconButtonState();
}

class _FocusIconButtonState extends State<_FocusIconButton> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = _focused || _hovered;

    return Focus(
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: InkWell(
          onTap: widget.onPressed,
          customBorder: const CircleBorder(),
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? Colors.white : Colors.transparent,
            ),
            child: widget.child ?? Icon(
              widget.icon, 
              color: isSelected ? Colors.black : Colors.white, 
              size: widget.size,
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageSelector extends StatefulWidget {
  final bool isCompact;
  const _LanguageSelector({required this.isCompact});

  @override
  State<_LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends State<_LanguageSelector> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  void _showOverlay() {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 280,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(-120, 48), // Senior Fix: Centrado dinámico respecto al botón ES
          child: MouseRegion(
            onEnter: (_) => _showOverlay(),
            onExit: (_) => _hideOverlay(),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 25,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A222B).withOpacity(0.55), // Senior: Blur más claro y transparente
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _LanguageItem(label: 'English', onTap: () => _selectLanguage('EN')),
                          _LanguageItem(label: 'Español', onTap: () => _selectLanguage('ES')),
                          _LanguageItem(label: 'Español Latinoamerica', onTap: () => _selectLanguage('LAT')),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectLanguage(String code) {
    _hideOverlay();
    // Aquí se implementaría el cambio de idioma real
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) {
          _showOverlay();
        },
        onExit: (_) {
          _hideOverlay();
        },
        child: _FocusTextButton(
          label: 'ES',
          icon: _overlayEntry != null ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          onPressed: () {},
        ),
      ),
    );
  }
}

class _FocusTextButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _FocusTextButton({required this.label, required this.icon, required this.onPressed});

  @override
  State<_FocusTextButton> createState() => _FocusTextButtonState();
}

class _FocusTextButtonState extends State<_FocusTextButton> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = _focused || _hovered;

    return Focus(
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected ? Colors.white : Colors.transparent,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label, 
                  style: GoogleFonts.poppins(
                    color: isSelected ? Colors.black : Colors.white, 
                    fontSize: 13, 
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  widget.icon, 
                  color: isSelected ? Colors.black : Colors.white, 
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _LanguageItem extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _LanguageItem({required this.label, required this.onTap});

  @override
  State<_LanguageItem> createState() => _LanguageItemState();
}

class _LanguageItemState extends State<_LanguageItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _isHovered ? Colors.white.withOpacity(0.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.poppins(
              color: _isHovered ? Colors.white : Colors.white.withOpacity(0.7),
              fontSize: 14,
              fontWeight: _isHovered ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
