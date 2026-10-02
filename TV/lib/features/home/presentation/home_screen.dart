import 'dart:ui';
import 'dart:async';
import '../../../shared/widgets/focusable_poster_card.dart';
import '../../search/presentation/providers/search_provider.dart';
import '../../search/presentation/widgets/search_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:auris_core/auris_core.dart' hide HeroBanner, FocusablePosterCard;
import '../../../core/utils/web_utils.dart';
import '../../../core/utils/tv_responsive_utils.dart';
import '../widgets/content_row.dart';
import '../widgets/editorial_content_row.dart';
import '../widgets/wide_content_row.dart';
import '../widgets/hero_banner.dart'; // Usar HeroBanner local optimizado para TV
import '../../player/presentation/player_screen.dart';
import '../../../shared/widgets/airing_countdown_badge.dart';

/// Senior TV Logic: Helpers de navegaciÃ³n globales para TV
void openTVDetails(BuildContext context, MediaItem item, String uiCategory) {
  final isAnimeMovie = item.card?.kind == 'movie_anime';
  final category = switch (uiCategory) {
    'inicio' => isAnimeMovie
        ? 'movie_anime'
        : switch (item.type) {
            MediaType.movie => 'movie',
            MediaType.series => 'series',
            MediaType.kdrama => 'kdrama',
            _ => 'anime',
          },
    'animes' => isAnimeMovie ? 'movie_anime' : 'anime',
    'anime_movies' => 'movie_anime',
    'pelÃ­culas' => isAnimeMovie ? 'movie_anime' : 'movie',
    'series' => 'series',
    'kdrama' => 'kdrama',
    _ => isAnimeMovie ? 'movie_anime' : 'all',
  };
  final source = item.source.isNotEmpty ? item.source : category;

  final metaTitle = item.romaji ?? item.english ?? item.title;
  final effectiveUrl = item.detailUrl ?? item.id;
  final String? typeVal = item.card?.type ?? item.card?.kind ?? (isAnimeMovie ? 'movie_anime' : null);

  final uri = '/content/${Uri.encodeComponent(item.title)}'
      '?source=${Uri.encodeComponent(source)}'
      '&category=${Uri.encodeComponent(category)}'
      '&url=${Uri.encodeComponent(effectiveUrl)}'
      '&metadataTitle=${Uri.encodeComponent(metaTitle)}'
      '&banner=${Uri.encodeComponent(item.bannerUrl ?? '')}'
      '&year=${item.year ?? ''}'
      '${typeVal != null ? '&type=${Uri.encodeComponent(typeVal)}' : ''}'
      '&sectionId=${Uri.encodeComponent(item.sectionId ?? '')}';

  // Push directo (sin post-frame): diferirlo dejaba la navegaciÃ³n colgada
  // si la app estaba idle (sin frames), y solo avanzaba al hacer scroll.
  if (context.mounted) context.push(uri, extra: item.toContentSeed());
}

void openTVScheduleItem(BuildContext context, MediaItem item) {
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

  // Push directo (sin post-frame): diferirlo dejaba la navegaciÃ³n colgada
  // si la app estaba idle (sin frames), y solo avanzaba al hacer scroll.
  if (context.mounted) context.push(uri, extra: item.toContentSeed());
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;
  bool _splashRemoved = false;
  bool _isTopBarFocused = false;
  final FocusNode _searchIconFocusNode = FocusNode();
  final FocusNode _overlaySearchFocusNode = FocusNode();
  bool _showSearch = false;

  // Nodos de foco de las cÃ¡psulas del topbar (uno por categorÃ­a): el hero los
  // usa para subir con D-pad arriba directo a la cÃ¡psula activa.
  final Map<String, FocusNode> _pillFocusNodes = {
    'inicio': FocusNode(),
    'animes': FocusNode(),
    'pelÃ­culas': FocusNode(),
    'series': FocusNode(),
    'kdrama': FocusNode(),
  };

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Senior Performance: Precarga escalonada
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) ref.read(homePrefetchProvider);
      });
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _searchIconFocusNode.dispose();
    _overlaySearchFocusNode.dispose();
    _scrollController.dispose();
    for (final node in _pillFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    final scrolled = _scrollController.offset > 5;
    if (scrolled != _isScrolled) {
      setState(() => _isScrolled = scrolled);
    }
  }

  List<Widget> _buildEditorialRows(
    AsyncValue<List<EditorialRow>> editorials,
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
          
          final targetCat = (category == 'inicio') ? 'inicio' : (row.isMovie ? movieCategory : category);

          if (row.format == SectionPresentation.wide) {
            list.add(SliverToBoxAdapter(
              child: RepaintBoundary(
                child: WideContentRow(
                  title: row.title,
                  items: row.items.map((m) => _wideItemFromMedia(m)).toList(),
                  onItemTap: (wideItem) => openTVDetails(context, wideItem.originalItem as MediaItem, targetCat),
                ),
              ),
            ));
          } else {
            list.add(SliverToBoxAdapter(
              child: RepaintBoundary(
                child: EditorialContentRow(
                  title: row.title,
                  subtitle: row.subtitle,
                  items: row.items,
                  badge: row.badge,
                  onItemTap: (item) => openTVDetails(context, item, targetCat),
                ),
              ),
            ));
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

  Widget _buildSection(ComposedHomeSection section, double horizontalPadding) {
    switch (section.type) {
      case HomeSectionType.continueWatching:
        return _ContinueWatchingSection(horizontalPadding: horizontalPadding);

      case HomeSectionType.editorial:
      case HomeSectionType.discovery:
        final row = section.data as EditorialRow;
        if (row.format == SectionPresentation.top10) {
          return RepaintBoundary(
            child: EditorialContentRow(
              title: row.title,
              subtitle: row.subtitle,
              items: row.items,
              badge: row.badge,
              forceTopDesign: true,
              onItemTap: (item) => openTVDetails(context, item, 'inicio'),
            ),
          );
        } else if (row.format == SectionPresentation.wide) {
          return RepaintBoundary(
            child: WideContentRow(
              title: row.title,
              subtitle: row.subtitle,
              items: row.items.map((m) => _wideItemFromMedia(m)).toList(),
              onItemTap: (wideItem) => openTVDetails(context, wideItem.originalItem as MediaItem, 'inicio'),
            ),
          );
        } else {
          return RepaintBoundary(
            child: EditorialContentRow(
              title: row.title,
              subtitle: row.subtitle,
              items: row.items,
              badge: row.badge,
              onItemTap: (item) => openTVDetails(context, item, 'inicio'),
            ),
          );
        }

      case HomeSectionType.top10Global:
        return _Top10Section(title: section.title ?? 'Top 10 de hoy', horizontalPadding: horizontalPadding);

      case HomeSectionType.recentlyAdded:
        return _RecentlyAddedSection(title: section.title ?? 'ReciÃ©n aÃ±adido', horizontalPadding: horizontalPadding);

      case HomeSectionType.trendingAnime:
        return _TrendingSection(category: 'animes', title: section.title ?? 'Animes en tendencia', horizontalPadding: horizontalPadding);

      case HomeSectionType.trendingMovies:
        return _TrendingSection(category: 'pelÃ­culas', title: section.title ?? 'PelÃ­culas destacadas', horizontalPadding: horizontalPadding, isWide: true);

      case HomeSectionType.recentEpisodes:
        return _RecentEpisodesSection(title: section.title ?? 'Estrenos (Hoy)', horizontalPadding: horizontalPadding);

      case HomeSectionType.recommendation:
        final row = section.data as EditorialRow;
        if (row.format == SectionPresentation.top10) {
          return RepaintBoundary(
            child: EditorialContentRow(
              title: row.title,
              subtitle: row.subtitle,
              items: row.items,
              badge: row.badge,
              forceTopDesign: true,
              onItemTap: (item) => openTVDetails(context, item, 'inicio'),
            ),
          );
        } else if (row.format == SectionPresentation.wide) {
          return RepaintBoundary(
            child: WideContentRow(
              title: row.title,
              subtitle: row.subtitle,
              items: row.items.map((m) => _wideItemFromMedia(m)).toList(),
              onItemTap: (wideItem) => openTVDetails(context, wideItem.originalItem as MediaItem, 'inicio'),
            ),
          );
        } else {
          return RepaintBoundary(
            child: ContentRow(
              title: row.title,
              subtitle: row.subtitle,
              items: row.items,
              onItemTap: (item) => openTVDetails(context, item, 'inicio'),
            ),
          );
        }
    }
  }

  WideContentItem _wideItemFromMedia(MediaItem m, {Widget? badgeOverlay}) {
    final bool isMovieish = m.type == MediaType.movie || m.card?.kind == 'movie_anime';
    final String? rawSub = m.subtitle;
    final bool isJustYear = rawSub != null && RegExp(r'^(?:19|20)\d{2}$').hasMatch(rawSub.trim());
    final String? effectiveSubtitle = isJustYear ? null : rawSub;

    return WideContentItem(
      id: m.id,
      title: m.title,
      imageUrl: ApiEndpoints.proxyImage(
        m.bannerUrl ?? m.posterUrl,
        width: isMovieish ? 1280 : 800,
      ),
      logoUrl: m.logoUrl,
      subtitle: effectiveSubtitle,
      rating: formatRating(m.rating),
      badgeOverlay: badgeOverlay,
      originalItem: m,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentCategory = ref.watch(homeCategoryProvider);
    ref.listen(homeCategoryProvider, (prev, next) {
      if (prev != next && prev != null && _scrollController.hasClients) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
      }
    });
    final horizontalPadding = TVResponsiveUtils.horizontalPadding(context);

    final layoutAsync = ref.watch(homeLayoutProvider);
    final heroBannerItemsAsync = ref.watch(heroBannerItemsProvider(currentCategory));
    final editorialRowsAsync = ref.watch(editorialRowsProvider(currentCategory));

    if (!editorialRowsAsync.isLoading && !_splashRemoved) {
      _splashRemoved = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WebUtils.removeSplashScreen();
      });
    }

    // Senior TV Tuning: La altura del Navbar en TV adaptada a un tamaÃ±o estÃ¡ndar y cÃ³modo
    final navHeight = TVResponsiveUtils.topBarHeight(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Espaciador para el Navbar
              SliverToBoxAdapter(
                child: SizedBox(height: navHeight), // Eliminado el +4 extra
              ),

              // 1. Banner Principal
              heroBannerItemsAsync.when(
                data: (displayItems) {
                  if (displayItems.isEmpty) return const SliverToBoxAdapter(child: HeroBannerSkeleton());

                  return SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: HeroBanner(
                        key: const ValueKey('hero_tv_main'), // Senior Fix: Clave estable para evitar recreaciÃ³n y crashes de foco
                        autofocus: true,
                        items: displayItems,
                        currentCategory: currentCategory,
                        // D-pad arriba desde el hero -> cÃ¡psula activa del topbar.
                        pillFocusNode: _pillFocusNodes[currentCategory] ?? _pillFocusNodes['inicio'],
                        onFocused: () {
                          // Senior Fix: Centrar hero suavemente al enfocarlo
                          _scrollController.animateTo(
                            0, 
                            duration: const Duration(milliseconds: 500), 
                            curve: Curves.easeOutQuart
                          );
                        },
                        onPlay: (item) => openTVDetails(context, item, currentCategory),
                        onDetails: (item) => openTVDetails(context, item, currentCategory),
                        onTrailer: (item) {
                          if (item.trailerKey == null || item.trailerKey!.isEmpty) return;
                          final youtubeUrl = item.trailerKey!.startsWith('http')
                              ? item.trailerKey!
                              : 'https://www.youtube.com/watch?v=${item.trailerKey}';
                          if (context.mounted) {
                            final uri = '/player/${Uri.encodeComponent(item.id)}'
                                '?url=${Uri.encodeComponent(youtubeUrl)}'
                                '&source=YouTube'
                                '&episode=Trailer'
                                '&category=${item.type.name}'
                                '&title=${Uri.encodeComponent(item.title)}'
                                '&posterUrl=${Uri.encodeComponent(item.posterUrl)}'
                                '&bannerUrl=${Uri.encodeComponent(item.bannerUrl ?? "")}';
                            context.push(uri);
                          }
                        },
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(child: HeroBannerSkeleton()),
                error: (err, _) => SliverToBoxAdapter(child: Center(child: Text('Error: $err'))),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 0)), // Reducido de 8 a 0 para pegar mÃ¡s las filas al Hero

              // 2. Contenido dinÃ¡mico
              if (currentCategory == 'inicio') 
                layoutAsync.when(
                  data: (sections) => SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return RepaintBoundary(
                          child: _buildSection(sections[index], horizontalPadding),
                        );
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
              else
                layoutAsync.when(
                  data: (sections) => SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return RepaintBoundary(
                          child: _buildSection(sections[index], horizontalPadding),
                        );
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
                ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
          
          // Overlay de busqueda (se muestra encima del contenido, debajo de la topbar)
          if (_showSearch)
            Positioned(
              top: navHeight,
              left: 0,
              right: 0,
              bottom: 0,
              child: _SearchOverlay(
                searchIconFocusNode: _searchIconFocusNode,
                searchFieldFocusNode: _overlaySearchFocusNode,
                onClose: () => setState(() => _showSearch = false),
              ),
            ),

          Positioned(
            top: 0, left: 0, right: 0,
            child: _buildTopNavContent(context, ref, currentCategory, navHeight),
          ),
        ],
      ),
    );
  }

  Widget _buildTopNavContent(BuildContext context, WidgetRef ref, String currentCategory, double navHeight) {
    final horizontalPadding = TVResponsiveUtils.horizontalPadding(context);
    final logoHeight = TVResponsiveUtils.sp(context, 32);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: navHeight,
      decoration: const BoxDecoration(
        color: Color(0xFF0B0B0D), // Fondo sÃ³lido sin blur
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Row(
          children: [
            _buildUserAvatar(context),
            SizedBox(width: TVResponsiveUtils.sp(context, 6)), 
            AurisIcon(AurisIcons.chevronDown, color: Colors.white60, size: 16), 
            
            const Spacer(),
            
            Focus(
              onFocusChange: (focused) {
                if (mounted && _isTopBarFocused != focused) {
                  setState(() => _isTopBarFocused = focused);
                }
              },
              child: AnimatedScale(
                scale: _isTopBarFocused ? 1.0 : 0.95,
                alignment: Alignment.center,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: _PillNavBar(
                  currentCategory: currentCategory,
                  isSearchActive: _showSearch,
                  onCategoryChanged: (cat) {
                    if (_showSearch) setState(() => _showSearch = false);
                    ref.read(homeCategoryProvider.notifier).state = cat;
                  },
                  focusNodes: _pillFocusNodes,
                  searchIconFocusNode: _searchIconFocusNode,
                  onSearchPressed: () => setState(() => _showSearch = true),
                  onSearchKeyEvent: (node, event) {
                    if (_showSearch && event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      _overlaySearchFocusNode.requestFocus();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  onSchedulePressed: () => context.push('/schedule'),
                ),
              ),
            ),
            
            const Spacer(),
            
            SvgPicture.asset(
              'assets/icons/auris-tv-icon.svg',
              height: logoHeight,
              colorFilter: const ColorFilter.mode(Color(0xFFEF7A1E), BlendMode.srcIn),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAvatar(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final user = ref.watch(authProvider);
        if (user == null) {
          return _FocusIconButton(
            icon: AurisIcons.userOutline,
            size: TVResponsiveUtils.sp(context, 22),
            onPressed: () => context.go('/profile'),
          );
        }

        return _FocusIconButton(
          onPressed: () => context.go('/profile'),
          child: Container(
            width: TVResponsiveUtils.sp(context, 36),
            height: TVResponsiveUtils.sp(context, 36),
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
                ? AurisIcon(AurisIcons.user, size: TVResponsiveUtils.sp(context, 16), color: Colors.white70)
                : null,
          ),
        );
      },
    );
  }
}
class _PillNavBar extends StatelessWidget {
  final String currentCategory;
  final bool isSearchActive;
  final ValueChanged<String> onCategoryChanged;
  final Map<String, FocusNode>? focusNodes;
  final FocusNode? searchIconFocusNode;
  final VoidCallback onSearchPressed;
  final FocusOnKeyEventCallback? onSearchKeyEvent;
  final VoidCallback onSchedulePressed;

  const _PillNavBar({
    required this.currentCategory,
    this.isSearchActive = false,
    required this.onCategoryChanged,
    this.focusNodes,
    this.searchIconFocusNode,
    required this.onSearchPressed,
    this.onSearchKeyEvent,
    required this.onSchedulePressed,
  });

  @override
  Widget build(BuildContext context) {
    final categories = [
      {'id': 'inicio', 'label': 'Inicio'},
      {'id': 'animes', 'label': 'Animes'},
      {'id': 'películas', 'label': 'Películas'},
      {'id': 'series', 'label': 'Series'},
      {'id': 'kdrama', 'label': 'KDramas'},
    ];

    final double hPadding = TVResponsiveUtils.sp(context, 16);
    final double spacing = 8.0;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botón Buscar (lateral izquierdo)
        Padding(
          padding: EdgeInsets.only(right: spacing),
          child: _FocusIconButton(
            focusNode: searchIconFocusNode,
            icon: AurisIcons.search,
            size: TVResponsiveUtils.sp(context, 16),
            isActive: isSearchActive,
            onPressed: onSearchPressed,
            onKeyEvent: onSearchKeyEvent,
          ),
        ),
        // Categorías principales
        ...categories.map((cat) {
          final id = cat['id']!;
          final isSelected = id == currentCategory && !isSearchActive;
          return Padding(
            padding: EdgeInsets.only(right: spacing),
            child: _PillNavItem(
              key: ValueKey('pill_'),
              label: cat['label']!,
              isActive: isSelected,
              onTap: () => onCategoryChanged(id),
              hPadding: hPadding,
              focusNode: focusNodes?[id],
            ),
          );
        }),
        // Botón Calendario / Horarios (lateral derecho)
        _FocusIconButton(
          icon: AurisIcons.grid,
          size: TVResponsiveUtils.sp(context, 16),
          onPressed: onSchedulePressed,
        ),
      ],
    );
  }
}

class _PillNavItem extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final double hPadding;
  final FocusNode? focusNode;
  final FocusOnKeyEventCallback? onKeyEvent;

  const _PillNavItem({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.hPadding,
    this.focusNode,
    this.onKeyEvent,
  });

  @override
  State<_PillNavItem> createState() => _PillNavItemState();
}

class _PillNavItemState extends State<_PillNavItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      // Senior Fix: Desactivado autofocus inicial para permitir que el Hero tome el mando al cargar la App
      autofocus: false,
      focusNode: widget.focusNode,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (widget.onKeyEvent != null) {
          final res = widget.onKeyEvent!(node, event);
          if (res != KeyEventResult.ignored) return res;
        }
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
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 32.0, // Altura reducida a 32 px para mayor estilizaciÃ³n
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: widget.hPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.0), // Radio de 16 px (mitad de 32px para pÃ­ldora perfecta)
            // Senior Logic: Blanco si tiene el foco, Gris (#2D2D2D) si es la categorÃ­a activa sin foco
            color: _focused 
                ? Colors.white 
                : (widget.isActive ? const Color(0xFF2D2D2D) : Colors.transparent),
            border: _focused ? Border.all(color: Colors.white, width: 1.5) : null,
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.poppins(
              // Texto negro solo cuando la cÃ¡psula es blanca (estÃ¡ enfocada)
              color: _focused ? Colors.black : Colors.white,
              fontSize: TVResponsiveUtils.sp(context, 12.5), // Ajustado ligeramente para armonizar con 32px
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _FocusIconButton extends StatefulWidget {
  final Object? icon;
  final Widget? child;
  final VoidCallback onPressed;
  final double size;
  final FocusNode? focusNode;
  final FocusOnKeyEventCallback? onKeyEvent;
  final bool isActive;

  const _FocusIconButton({
    this.icon,
    this.child,
    required this.onPressed,
    this.size = 28,
    this.focusNode,
    this.onKeyEvent,
    this.isActive = false,
  });

  @override
  State<_FocusIconButton> createState() => _FocusIconButtonState();
}

class _FocusIconButtonState extends State<_FocusIconButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (widget.onKeyEvent != null) {
          final res = widget.onKeyEvent!(node, event);
          if (res != KeyEventResult.ignored) return res;
        }
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
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: TVResponsiveUtils.sp(context, 32),
          height: TVResponsiveUtils.sp(context, 32),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _focused 
                ? Colors.white 
                : (widget.isActive ? const Color(0xFF2D2D2D) : Colors.transparent),
            border: _focused ? Border.all(color: Colors.white, width: 1.5) : null,
          ),
          child: widget.child ?? (widget.icon is String
              ? AurisIcon(
                  widget.icon as String,
                  color: _focused ? Colors.black : Colors.white,
                  size: widget.size,
                )
              : Icon(
                  widget.icon as IconData?,
                  // Senior Fix: Icono negro sobre fondo blanco cuando estÃ¡ enfocado
                  color: _focused ? Colors.black : Colors.white,
                  size: widget.size,
                )),
        ),
      ),
    );
  }
}

class _ContinueWatchingSection extends ConsumerWidget {
  final double horizontalPadding;
  final String? categoryFilter;
  const _ContinueWatchingSection({required this.horizontalPadding, this.categoryFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(playbackHistoryStateProvider);

    return historyAsync.when(
      data: (items) {
        // Senior Logic: Filtrar por categorÃ­a si se especifica
        final filteredItems = categoryFilter == null
            ? items
            : items.where((h) => h.category?.toLowerCase() == categoryFilter!.toLowerCase()).toList();

        if (filteredItems.isEmpty) return const SizedBox.shrink();

        return WideContentRow(
          title: 'Continuar Viendo',
          items: filteredItems.take(10).map((h) {
            // LÃ³gica centralizada en Core (library_providers): solo diseÃ±o aquÃ­.
            final bool isMovieish = libraryIsMovieish(h);
            final String displayTitle = libraryDisplayTitle(h);
            // SubtÃ­tulo en 2 lÃ­neas: "T1:E7 . TÃ­tulo" + "Quedan X".
            final sub = continueCardSubtitle(h);

            final String? rawUrl = h.bannerUrl ?? h.posterUrl;
            final String? logoUrl = h.logoUrl;
            final remainingMs = h.durationInMilliseconds - h.positionInMilliseconds;

            return WideContentItem(
              id: h.contentId,
              title: displayTitle,
              imageUrl: ApiEndpoints.proxyImage(
                rawUrl,
                width: isMovieish ? 1280 : 800,
              ),
              logoUrl: logoUrl != null ? ApiEndpoints.proxyImage(logoUrl) : null,
              progress: h.progressPercentage,
              subtitle: sub.line1.isNotEmpty ? sub.line1 : null,
              subtitle2: sub.line2,
              // Ocultar de Continuar Viendo (conserva el Historial).
              onDelete: () => ref.read(playbackHistoryStateProvider.notifier).dismissFromContinue(h.contentId, h.season, h.episode),
              originalItem: h,
            );
          }).toList(),
          onItemTap: (wideItem) {
            final item = wideItem.originalItem as PlaybackHistory;
            final detailParams = item.toUnifiedDetailParams();            // FIX continuar-viendo: kind/year/type/metadataTitle + seed (extra).
            // Sin kind el discovery iba al servidor movies y remapeaba la
            // categorÃ­a (animeâ†’series) â†’ detalle sin fuentes.
            final uri = '/content/${Uri.encodeComponent(detailParams.title)}'
                '?source=${Uri.encodeComponent(detailParams.source)}'
                '&category=${Uri.encodeComponent(detailParams.category)}'
                '&url=${Uri.encodeComponent(detailParams.url ?? item.contentId)}'
                '${detailParams.season != null ? '&season=${detailParams.season}' : ''}'
                '${detailParams.sectionId != null ? '&sectionId=${Uri.encodeComponent(detailParams.sectionId!)}' : ''}'
                '&year=${detailParams.year ?? ''}'
                '${detailParams.kind != null && detailParams.kind!.isNotEmpty ? '&kind=${Uri.encodeComponent(detailParams.kind!)}' : ''}'
                '${detailParams.type != null && detailParams.type!.isNotEmpty ? '&type=${Uri.encodeComponent(detailParams.type!)}' : ''}'
                '${detailParams.metadataTitle != null && detailParams.metadataTitle!.isNotEmpty ? '&metadataTitle=${Uri.encodeComponent(detailParams.metadataTitle!)}' : ''}';
            // Seed centralizado en Core (null si no hay URL http real).
            final seed = historyToSeed(item);
            context.push(uri, extra: seed);
          },
        );
      },
      loading: () => const RowSkeleton(isWide: true),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _Top10Section extends ConsumerWidget {
  final String title;
  final double horizontalPadding;
  const _Top10Section({required this.title, required this.horizontalPadding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(top10GlobalProvider);
    return asyncData.when(
      data: (items) => EditorialContentRow(
        title: title,
        items: items,
        badge: EditorialBadge.mythical,
        forceTopDesign: true,
        onItemTap: (item) => openTVDetails(context, item, 'inicio'),
      ),
      loading: () => const RowSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _RecentlyAddedSection extends ConsumerWidget {
  final String title;
  final double horizontalPadding;
  const _RecentlyAddedSection({required this.title, required this.horizontalPadding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(recentlyAddedProvider);
    return asyncData.when(
      data: (items) => ContentRow(
        title: title,
        items: items,
        horizontalPadding: horizontalPadding,
        onItemTap: (item) => openTVDetails(context, item, 'inicio'),
      ),
      loading: () => const RowSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _TrendingSection extends ConsumerWidget {
  final String category;
  final String title;
  final double horizontalPadding;
  final bool isWide;
  const _TrendingSection({required this.category, required this.title, required this.horizontalPadding, this.isWide = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(trendingListProvider(category));
    return asyncData.when(
      data: (items) {
        if (isWide) {
          return WideContentRow(
            title: title,
            items: items.map((m) {
              final rawSub = m.subtitle;
              final isJustYear = rawSub != null && RegExp(r'^(?:19|20)\d{2}$').hasMatch(rawSub.trim());
              return WideContentItem(
                id: m.id, title: m.title, imageUrl: m.bannerUrl ?? m.posterUrl,
                logoUrl: m.logoUrl,
                subtitle: isJustYear ? null : rawSub, rating: formatRating(m.rating), originalItem: m,
              );
            }).toList(),
            onItemTap: (wide) => openTVDetails(context, wide.originalItem as MediaItem, category),
          );
        }
        return ContentRow(
          title: title,
          items: items,
          horizontalPadding: horizontalPadding,
          onItemTap: (item) => openTVDetails(context, item, category),
        );
      },
      loading: () => RowSkeleton(isWide: isWide),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _RecentEpisodesSection extends ConsumerWidget {
  final String title;
  final double horizontalPadding;
  const _RecentEpisodesSection({required this.title, required this.horizontalPadding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(recentEpisodesProvider);
    return asyncData.when(
      data: (items) => WideContentRow(
        title: title,
        items: items.map((m) {
          final rawSub = m.subtitle;
          final isJustYear = rawSub != null && RegExp(r'^(?:19|20)\d{2}$').hasMatch(rawSub.trim());
          return WideContentItem(
            id: m.id, title: m.title, imageUrl: m.bannerUrl ?? m.posterUrl,
            logoUrl: m.logoUrl,
            subtitle: isJustYear ? null : rawSub, rating: formatRating(m.rating),
            badgeOverlay: m.airingAt != null ? AiringCountdownBadge(airingAt: m.airingAt!, aired: m.aired) : null,
            originalItem: m,
          );
        }).toList(),
        onItemTap: (wide) => openTVScheduleItem(context, wide.originalItem as MediaItem),
      ),
      loading: () => const RowSkeleton(isWide: true),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SearchOverlay: se muestra encima del contenido de HomeScreen, debajo de la
// topbar existente. Reutiliza la lógica de SearchScreen sin navegar.
// ─────────────────────────────────────────────────────────────────────────────
class _SearchOverlay extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  final FocusNode? searchIconFocusNode;
  final FocusNode? searchFieldFocusNode;
  const _SearchOverlay({
    required this.onClose,
    this.searchIconFocusNode,
    this.searchFieldFocusNode,
  });

  @override
  ConsumerState<_SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends ConsumerState<_SearchOverlay>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late final FocusNode _focusNode;
  FocusNode? _internalFocusNode;
  final FocusNode _firstResultFocusNode = FocusNode();
  final FocusScopeNode _overlayScopeNode = FocusScopeNode();
  final FocusNode _micFocusNode = FocusNode();
  bool _isMicFocused = false;
  final String _selectedCategory = 'all';
  Timer? _debounce;
  String _currentQuery = '';
  bool _isFocused = false;
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    if (widget.searchFieldFocusNode != null) {
      _focusNode = widget.searchFieldFocusNode!;
    } else {
      _internalFocusNode = FocusNode();
      _focusNode = _internalFocusNode!;
    }
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _focusNode.addListener(() {
      if (mounted) {
        setState(() => _isFocused = _focusNode.hasFocus);
        // When _focusNode loses focus, only redirect to first result if
        // focus moved explicitly to another widget inside the overlay.
        // Do NOT redirect here on keyboard dismiss (BACK key) — the
        // Focus wrapper's onKeyEvent on Enter will re-show the keyboard.
        if (!_focusNode.hasFocus) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final focused = _overlayScopeNode.focusedChild;
            // If nothing in overlay has focus, return focus to search bar
            if (focused == null) {
              _focusNode.requestFocus();
            }
            // Otherwise, a result card or mic gained focus intentionally — leave it
          });
        }
      }
    });
    Future.delayed(Duration.zero, () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _overlayScopeNode.dispose();
    _animCtrl.dispose();
    _debounce?.cancel();
    _searchController.dispose();
    _internalFocusNode?.dispose();
    _firstResultFocusNode.dispose();
    _micFocusNode.dispose();
    super.dispose();
  }

  void _startVoiceSearch() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Búsqueda por voz activada'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _close() async {
    await _animCtrl.reverse();
    widget.onClose();
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
    final metaTitle = cleanTitleForDisplay(
        result.metadataTitle ?? result.scrapedTitle ?? result.title);
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

    // Navigate first WITHOUT closing the overlay, then restore it on back.
    // This keeps the overlay in the widget tree so that pressing BACK
    // on the content screen returns the user to the search overlay.
    if (context.mounted) {
      context.push(uri, extra: result).then((_) {
        // When the user comes back, ensure the search field regains focus.
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted) _focusNode.requestFocus();
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(
      searchResultsProvider(
        SearchParams(category: _selectedCategory, query: _currentQuery),
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _close();
        }
      },
      child: FocusScope(
        node: _overlayScopeNode,
        autofocus: true,
        child: FadeTransition(
        opacity: _fadeAnim,
        child: Container(
          color: const Color(0xFF0B0B0D),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra de búsqueda con botón de micrófono (idéntica a referencia)
              Padding(
                padding: const EdgeInsets.fromLTRB(60, 16, 60, 16),
                child: Row(
                  children: [
                    // Campo de búsqueda principal
                    Expanded(
                      child: Focus(
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent) {
                            if (event.logicalKey == LogicalKeyboardKey.enter ||
                                event.logicalKey == LogicalKeyboardKey.select ||
                                event.logicalKey == LogicalKeyboardKey.space) {
                              _focusNode.requestFocus();
                              SystemChannels.textInput.invokeMethod('TextInput.show');
                              return KeyEventResult.handled;
                            }
                            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                              if (_micFocusNode.canRequestFocus) {
                                _micFocusNode.requestFocus();
                                return KeyEventResult.handled;
                              }
                            }
                            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                              if (_firstResultFocusNode.canRequestFocus) {
                                _firstResultFocusNode.requestFocus();
                              } else {
                                FocusScope.of(context)
                                    .focusInDirection(TraversalDirection.down);
                              }
                              return KeyEventResult.handled;
                            }
                            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                              if (widget.searchIconFocusNode?.canRequestFocus == true) {
                                widget.searchIconFocusNode!.requestFocus();
                              } else {
                                FocusScope.of(context)
                                    .focusInDirection(TraversalDirection.up);
                              }
                              return KeyEventResult.handled;
                            }
                            if (event.logicalKey == LogicalKeyboardKey.escape ||
                                event.logicalKey == LogicalKeyboardKey.goBack) {
                              _close();
                              return KeyEventResult.handled;
                            }
                          }
                          return KeyEventResult.ignored;
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            border: Border.all(
                              color: _isFocused
                                  ? const Color(0xFFEF7A1E)
                                  : Colors.white38,
                              width: _isFocused ? 2.5 : 1.5,
                            ),
                          ),
                          child: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: TextField(
                              controller: _searchController,
                              focusNode: _focusNode,
                              style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                              textCapitalization: TextCapitalization.sentences,
                              inputFormatters: [CapitalizeFirstLetterFormatter()],
                              decoration: InputDecoration(
                                hintText: 'Busca una serie, película o episodio',
                                hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.3),
                                    fontSize: 18),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: _onSearchChanged,
                              onSubmitted: _onSearchSubmitted,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Botón de micrófono integrado (al lado derecho de la barra)
                    Focus(
                      focusNode: _micFocusNode,
                      onFocusChange: (focused) =>
                          setState(() => _isMicFocused = focused),
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent) {
                          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                            _focusNode.requestFocus();
                            return KeyEventResult.handled;
                          }
                          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                            if (_firstResultFocusNode.canRequestFocus) {
                              _firstResultFocusNode.requestFocus();
                            } else {
                              FocusScope.of(context)
                                  .focusInDirection(TraversalDirection.down);
                            }
                            return KeyEventResult.handled;
                          }
                          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                            if (widget.searchIconFocusNode?.canRequestFocus == true) {
                              widget.searchIconFocusNode!.requestFocus();
                            } else {
                              FocusScope.of(context)
                                  .focusInDirection(TraversalDirection.up);
                            }
                            return KeyEventResult.handled;
                          }
                          if (event.logicalKey == LogicalKeyboardKey.enter ||
                              event.logicalKey == LogicalKeyboardKey.select ||
                              event.logicalKey == LogicalKeyboardKey.space) {
                            _startVoiceSearch();
                            return KeyEventResult.handled;
                          }
                          if (event.logicalKey == LogicalKeyboardKey.escape ||
                              event.logicalKey == LogicalKeyboardKey.goBack) {
                            _close();
                            return KeyEventResult.handled;
                          }
                        }
                        return KeyEventResult.ignored;
                      },
                      child: GestureDetector(
                        onTap: _startVoiceSearch,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: _isMicFocused
                                ? Colors.transparent
                                : const Color(0xFF1A1A1A),
                            border: Border.all(
                              color: _isMicFocused
                                  ? const Color(0xFFEF7A1E)
                                  : Colors.white38,
                              width: _isMicFocused ? 2.5 : 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.mic_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Título sección
              if (_currentQuery.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(60, 4, 60, 12),
                  child: Text(
                    'Lo más buscado',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                ),

              const SizedBox(height: 4),

              // Grid de resultados
              Expanded(
                child: ClipRect(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 60),
                    child: _buildResultsState(resultsAsync),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildResultsState(AsyncValue<SearchResponse> resultsAsync) {
    if (_currentQuery.isEmpty) {
      final trendingAsync = ref.watch(searchTrendingProvider);
      return _buildTrendingGrid(trendingAsync);
    }

    return resultsAsync.when(
      data: (response) {
        final results = _deduplicateSearch(response.results);
        if (results.isEmpty) return _buildNoResultsState();

        final notifier = ref.read(
          searchResultsProvider(
            SearchParams(category: _selectedCategory, query: _currentQuery),
          ).notifier,
        );

        return GridView.builder(
          key: const ValueKey('overlay_results_grid'),
          clipBehavior: Clip.hardEdge,
          padding: const EdgeInsets.fromLTRB(20, 20, 40, 40),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
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
                        strokeWidth: 2.5, color: Color(0xFFEF7A1E)),
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
                  _focusNode.requestFocus();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              title: cleanTitleForDisplay(
                  result.scrapedTitle ?? result.metadataTitle ?? result.title),
              posterUrl: ApiEndpoints.proxyImage(result.thumbnail,
                  fallbackUrl: result.tmdbThumbnail),
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
              showInfo: true,
              aspectRatio: 2 / 3,
              onTap: () => _onContentTap(result),
            );
          },
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Color(0xFFEF7A1E))),
      error: (err, _) => Center(
          child: Text('Error: $err',
              style: const TextStyle(color: Colors.white54))),
    );
  }

  Widget _buildTrendingGrid(AsyncValue<List<SearchResult>> trendingAsync) {
    return trendingAsync.when(
      data: (items) => GridView.builder(
        key: const ValueKey('overlay_trending_grid'),
        clipBehavior: Clip.hardEdge,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
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
                _focusNode.requestFocus();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            title: cleanTitleForDisplay(
                result.scrapedTitle ?? result.metadataTitle ?? result.title),
            posterUrl: ApiEndpoints.proxyImage(result.thumbnail,
                fallbackUrl: result.tmdbThumbnail),
            badge: meta.label,
            badgeColor: meta.labelColor,
            subtitle: meta.status,
            subtitleColor: meta.statusColor,
            activeBorderColor: const Color(0xFFE91E63),
            showInfo: true,
            aspectRatio: 2 / 3,
            onTap: () => _onContentTap(result),
          );
        },
      ),
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Color(0xFFEF7A1E))),
      error: (err, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildNoResultsState() {
    return SingleChildScrollView(
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
                  letterSpacing: -0.5),
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

String _fuseKeyOverlay(SearchResult r) {
  final t = r.title.toLowerCase();
  final typeRe = RegExp(r'\b(movie|pelicula|film|ova|special|oav)\b');
  final isMovieish = typeRe.hasMatch(t);
  final franchise =
      t.replaceAll(typeRe, '').replaceAll(RegExp(r'[^a-z0-9]'), '');
  final cat = inferOpenCategory(r, isMovieish ? 'movie' : 'tv');
  return '$franchise#$cat';
}

List<SearchResult> _deduplicateSearch(List<SearchResult> results) {
  final Map<String, SearchResult> grouped = {};
  for (final r in results) {
    final key = _fuseKeyOverlay(r);
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
      } else if ((existing.banner == null || existing.banner!.isEmpty) &&
          (r.banner != null && r.banner!.isNotEmpty)) {
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
