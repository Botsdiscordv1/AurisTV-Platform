import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:auris_core/auris_core.dart';
import '../../../data/datasources/mock_data.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/utils/web_utils.dart';
import '../widgets/content_row.dart';
import '../widgets/editorial_content_row.dart';
import '../widgets/wide_content_row.dart';
import '../widgets/hero_banner.dart';
import '../../../shared/widgets/skeletons.dart';
import '../../../shared/widgets/airing_countdown_badge.dart';
import 'providers/home_provider.dart';

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
    final category = switch (uiCategory) {
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
    
    // Prioridad de Identidad: Romaji > Inglés > Título Local
    final metaTitle = item.romaji ?? item.english ?? item.title;

    final uri = '/content/${Uri.encodeComponent(item.title)}?source=${Uri.encodeComponent(source)}&category=${Uri.encodeComponent(category)}&url=${Uri.encodeComponent(item.id)}&metadataTitle=${Uri.encodeComponent(metaTitle)}&banner=${Uri.encodeComponent(item.bannerUrl ?? '')}&year=${item.year ?? ''}';
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
        child: RowSkeleton(isWide: false),
      )),
      error: (err, _) => [
        SliverToBoxAdapter(child: Center(child: Text('Error editorial: $err', style: const TextStyle(color: Colors.white24)))),
      ],
    );
  }

  Widget _buildSection(HomeLayoutSection section, double horizontalPadding) {
    switch (section.type) {
      case HomeSectionType.continueWatching:
        final historyAsync = ref.watch(playbackHistoryStateProvider);
        
        // Senior Logic: Filtrar historial para mostrar solo el episodio más reciente de cada serie
        // y que no esté completado.
        final Set<String> seenContentIds = {};
        final continueWatching = historyAsync.valueOrNull?.where((h) {
          if (h.title == null || h.isCompleted) return false;
          if (seenContentIds.contains(h.contentId)) return false;
          seenContentIds.add(h.contentId);
          return true;
        }).take(10).toList() ?? [];

        if (continueWatching.isEmpty) return const SizedBox.shrink();

        return WideContentRow(
          title: 'Continuar Viendo',
          items: continueWatching.map((h) {
            final bool useEpisodeThumb = _isHighQualityThumbnail(h.posterUrl);
            final String finalImageUrl = useEpisodeThumb ? (h.posterUrl ?? '') : (h.bannerUrl ?? h.posterUrl ?? '');

            String displayTitle = h.title ?? 'Contenido';
            if (h.episode != null && h.episode!.isNotEmpty) {
              displayTitle = 'Ep ${h.episode} • $displayTitle';
            }

            // Senior UI: Formateo de tiempo restante más profesional
            String remainingText = '';
            final remainingMs = h.durationInMilliseconds - h.positionInMilliseconds;
            if (remainingMs > 0) {
              final duration = Duration(milliseconds: remainingMs);
              final hours = duration.inHours;
              final minutes = duration.inMinutes % 60;
              
              if (hours > 0) {
                remainingText = 'Quedan $hours h $minutes min';
              } else if (minutes > 0) {
                remainingText = 'Quedan $minutes min';
              } else {
                remainingText = 'Menos de 1 min restante';
              }
            }

            return WideContentItem(
              id: h.contentId,
              title: displayTitle,
              imageUrl: ApiEndpoints.proxyImage(finalImageUrl),
              progress: h.progressPercentage,
              subtitle: remainingText,
              onDelete: () {
                // Feedback táctico/visual: eliminamos el item del estado de Riverpod
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
          loading: () => const RowSkeleton(),
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
          loading: () => const RowSkeleton(),
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
          loading: () => const RowSkeleton(),
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
          loading: () => const RowSkeleton(isWide: true),
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
          loading: () => const RowSkeleton(isWide: true),
          error: (err, _) => const SizedBox.shrink(),
        );
    }
  }

void _openScheduleItem(BuildContext context, MediaItem item) {
    final metaTitle = item.romaji ?? item.english ?? item.title;
    final itemYear = item.year ?? (item.airingAt != null ? DateTime.fromMillisecondsSinceEpoch(item.airingAt! * 1000).year : null);
    final uri = '/content/${Uri.encodeComponent(item.title)}?source=&category=anime&url=&metadataTitle=${Uri.encodeComponent(metaTitle)}&banner=&year=${itemYear ?? ''}';
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
    final navHeight = isCompactDesktop ? 70.0 : 80.0;

    final horizontalPadding = ResponsiveUtils.horizontalPadding(context);
    
    // Senior Performance: Disparamos la precarga de todas las categorías en segundo plano.
    // Usamos un delay más largo para dar prioridad absoluta al HeroBanner y contenido inicial.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) ref.read(homePrefetchProvider);
      });
    });
    
    final historyAsync = ref.watch(playbackHistoryStateProvider);
    
    // Providers de datos reales
    final layoutAsync = ref.watch(homeLayoutProvider);
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
    final rawFiltered = trendingAsync.valueOrNull
        ?.where((m) => m.bannerUrl != null && m.bannerUrl!.isNotEmpty)
        .take(5)
        .toList();
    final bannerItems = (rawFiltered != null && rawFiltered.isNotEmpty)
        ? rawFiltered
        : MockData.featuredItems;
    final trendingItems = (trendingAsync.valueOrNull != null && trendingAsync.valueOrNull!.isNotEmpty)
        ? trendingAsync.valueOrNull!
        : MockData.anime;
    final recentItems = (recentAsync.valueOrNull != null && recentAsync.valueOrNull!.isNotEmpty)
        ? recentAsync.valueOrNull!
        : MockData.anime;
    final movieItems = (movieTrendingAsync.valueOrNull != null && movieTrendingAsync.valueOrNull!.isNotEmpty)
        ? movieTrendingAsync.valueOrNull!
        : MockData.movies;
    final animeMovieItems = (animeMoviesAsync.valueOrNull != null && animeMoviesAsync.valueOrNull!.isNotEmpty)
        ? animeMoviesAsync.valueOrNull!
        : MockData.movies;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D), // Senior Recomienda: Rich Black para evitar OLED Smearing
      body: FocusScope( // Senior Fix: Usamos FocusScope para aislar el contexto de foco de la pantalla
        child: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Espaciador para que el contenido empiece debajo de la barra fija
                SliverToBoxAdapter(
                  child: Focus(
                    skipTraversal: true,
                    canRequestFocus: false,
                    child: SizedBox(height: navHeight + 20),
                  ),
                ),

                // 1. Banner Principal
                trendingAsync.when(
                  data: (_) => SliverToBoxAdapter(
                    child: HeroBanner(
                      autofocus: true,
                      items: bannerItems,
                      currentCategory: currentCategory,
                      onPlay: (item) => _openDetails(context, item, currentCategory),
                      onDetails: (item) => _openDetails(context, item, currentCategory),
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
                      children: List.generate(3, (index) => const RowSkeleton()),
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
                  loading: () => const SliverToBoxAdapter(child: RowSkeleton(isWide: true)),
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
                  loading: () => const SliverToBoxAdapter(child: RowSkeleton()),
                  error: (err, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                ),

                ..._buildEditorialRows(editorialRowsAsync, _openDetails,
                    'animes', includeMovies: true,
                    movieCategory: 'anime_movies'),

                animeMoviesAsync.when(
                  data: (items) => SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: WideContentRow(
                        key: const ValueKey('anime_movies'),
                        title: 'Películas de Anime',
                        items: items.map((m) => _wideItemFromMedia(m)).toList(),
                        onItemTap: (wideItem) => _openDetails(context, wideItem.originalItem as MediaItem, 'anime_movies'),
                      ),
                    ),
                  ),
                  loading: () => const SliverToBoxAdapter(child: RowSkeleton(isWide: true)),
                  error: (err, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                ),
              ]
else if (currentCategory == 'películas') ...[
                SliverToBoxAdapter(
                  child: WideContentRow(
                    key: const ValueKey('trending_movies'),
                    title: 'Cine Recomendado',
                    items: trendingItems.map((m) => _wideItemFromMedia(m as MediaItem)).toList(),
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
            color: const Color(0xFF0B0B0D).withValues(alpha: _isScrolled ? 0.9 : 0.4),
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
                // 1. Perfil y Búsqueda (Estilo Netflix a la izquierda)
                _buildUserAvatar(context, isCompactDesktop),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_drop_down, color: Colors.white60, size: 20),
                const SizedBox(width: 24),
                _FocusIconButton(
                  icon: Icons.search,
                  size: isCompactDesktop ? 22 : 26,
                  onPressed: () => context.go('/search'),
                ),
                
                const Spacer(),
                
                // 2. Navegación Principal (Centrada como en el ejemplo)
                _PillNavBar(
                  currentCategory: currentCategory,
                  onCategoryChanged: (cat) => ref.read(homeCategoryProvider.notifier).state = cat,
                ),
                
                const Spacer(),
                
                // 3. Acciones Secundarias y Logo (Derecha)
                _FocusIconButton(
                  icon: Icons.grid_view_rounded,
                  size: isCompactDesktop ? 22 : 26,
                  onPressed: () => context.push('/schedule'),
                ),
                const SizedBox(width: 24),
                
                // Logo de Auris (A la derecha como Netflix)
                SvgPicture.asset(
                  'assets/icons/auris-tv-icon.svg', // Cambiado de logo plano a icono (estilo cabecera)
                  height: logoHeight + 4, // Un pequeño extra para el icono comparado con el logo horizontal
                  fit: BoxFit.contain,
                  colorFilter: const ColorFilter.mode(Color(0xFFEF7A1E), BlendMode.srcIn),
                ),
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
            onPressed: () => context.go('/settings'),
          );
        }

        return _FocusIconButton(
          onPressed: () => context.go('/settings'),
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
                  color: const Color(0xFFEF7A1E).withOpacity(0.5),
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
                : (_isHovered ? Colors.white.withOpacity(0.05) : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
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
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final bool isHighlighted = _focused || _hovered;

    return Focus(
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.space) {
            widget.onTap();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
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
              color: isHighlighted && !widget.isActive
                  ? Colors.white.withOpacity(0.1)
                  : Colors.transparent,
              border: _focused ? Border.all(color: Colors.white, width: 2) : null,
            ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: GoogleFonts.poppins(
                color: widget.isActive ? Colors.black : Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              child: Text(widget.label),
            ),
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
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.space) {
            widget.onPressed();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            customBorder: const CircleBorder(),
            overlayColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.1)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
                border: isSelected ? Border.all(color: Colors.white, width: 2) : Border.all(color: Colors.transparent, width: 2),
              ),
              child: widget.child ?? Icon(
                widget.icon, 
                color: Colors.white, 
                size: widget.size,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
