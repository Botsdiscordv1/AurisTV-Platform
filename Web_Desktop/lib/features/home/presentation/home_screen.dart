import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../widgets/hero_banner.dart';
import '../../../shared/widgets/skeletons.dart';
import '../../../shared/widgets/airing_countdown_badge.dart';
import 'providers/home_provider.dart';

/// Senior: Helpers de navegación globales para permitir acceso desde widgets externos
/// sin depender de la instancia privada de _HomeScreenState.
void openHomeDetails(BuildContext context, MediaItem item, String uiCategory) {
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
  
  final metaTitle = item.romaji ?? item.english ?? item.title;

  final uri = '/content/${Uri.encodeComponent(item.title)}'
      '?source=${Uri.encodeComponent(source)}'
      '&category=${Uri.encodeComponent(category)}'
      '&url=${Uri.encodeComponent(item.id)}'
      '&metadataTitle=${Uri.encodeComponent(metaTitle)}'
      '&banner=${Uri.encodeComponent(item.bannerUrl ?? '')}'
      '&year=${item.year ?? ''}';
      
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) context.push(uri, extra: item.toContentSeed());
  });
}

void openHomeScheduleItem(BuildContext context, MediaItem item) {
  final metaTitle = item.romaji ?? item.english ?? item.title;
  final itemYear = item.year ?? (item.airingAt != null ? DateTime.fromMillisecondsSinceEpoch(item.airingAt! * 1000).year : null);
  final uri = '/content/${Uri.encodeComponent(item.title)}'
      '?source=&category=anime&url='
      '&metadataTitle=${Uri.encodeComponent(metaTitle)}'
      '&banner=&year=${itemYear ?? ''}';
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) context.push(uri, extra: item.toContentSeed());
  });
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

          if (row.format == RowFormat.horizontal) {
            list.add(SliverToBoxAdapter(
              child: RepaintBoundary(
                child: WideContentRow(
                  title: row.title,
                  items: row.items.map((m) => _wideItemFromMedia(m)).toList(),
                  onItemTap: (wideItem) => openHomeDetails(context, wideItem.originalItem as MediaItem, targetCat),
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
                  onItemTap: (item) => openHomeDetails(context, item, targetCat),
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

  Widget _buildSection(HomeLayoutSection section, double horizontalPadding) {
    switch (section.type) {
      case HomeSectionType.continueWatching:
        return _ContinueWatchingSection(horizontalPadding: horizontalPadding);

      case HomeSectionType.editorial:
        final row = section.data as EditorialRow;
        if (row.format == RowFormat.horizontal) {
          return RepaintBoundary(
            child: WideContentRow(
              title: row.title,
              items: row.items.map((m) => _wideItemFromMedia(m)).toList(),
              onItemTap: (wideItem) => openHomeDetails(context, wideItem.originalItem as MediaItem, 'inicio'),
            ),
          );
        } else {
          return RepaintBoundary(
            child: EditorialContentRow(
              title: row.title,
              items: row.items,
              badge: row.badge,
              onItemTap: (item) => openHomeDetails(context, item, 'inicio'),
            ),
          );
        }

      case HomeSectionType.top10Global:
        return _Top10Section(title: section.title ?? 'Top 10 de hoy', horizontalPadding: horizontalPadding);

      case HomeSectionType.recentlyAdded:
        return _RecentlyAddedSection(title: section.title ?? 'Recién añadido', horizontalPadding: horizontalPadding);

      case HomeSectionType.trendingAnime:
        return _TrendingSection(category: 'animes', title: section.title ?? 'En tendencia', horizontalPadding: horizontalPadding);

      case HomeSectionType.trendingMovies:
        return _TrendingSection(category: 'películas', title: section.title ?? 'Cine', horizontalPadding: horizontalPadding, isWide: true);

      case HomeSectionType.recentEpisodes:
        return _RecentEpisodesSection(title: section.title ?? 'Estrenos', horizontalPadding: horizontalPadding);
    }
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

  @override
  Widget build(BuildContext context) {
    final currentCategory = ref.watch(homeCategoryProvider);
    final isMobile = ResponsiveUtils.isMobile(context);
    final horizontalPadding = ResponsiveUtils.horizontalPadding(context);
    
    // Senior Performance: Disparamos la precarga escalonada con delay inicial.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) ref.read(homePrefetchProvider);
      });
    });
    
    final layoutAsync = ref.watch(homeLayoutProvider);
    final currentCategoryTrending = ref.watch(trendingListProvider(currentCategory));
    final editorialRowsAsync = ref.watch(editorialRowsProvider);

    if (!editorialRowsAsync.isLoading && !_splashRemoved) {
      _splashRemoved = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WebUtils.removeSplashScreen();
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(height: isMobile ? (MediaQuery.of(context).padding.top + 60) : 80),
              ),

              // 1. Banner Principal
              currentCategoryTrending.when(
                data: (items) {
                  final bannerItems = items.where((m) => m.bannerUrl != null && m.bannerUrl!.isNotEmpty).take(5).toList();
                  final displayItems = bannerItems.isNotEmpty ? bannerItems : MockData.featuredItems;

                  return SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: HeroBanner(
                        autofocus: true,
                        items: displayItems,
                        currentCategory: currentCategory,
                        onPlay: (item) => openHomeDetails(context, item, currentCategory),
                        onDetails: (item) => openHomeDetails(context, item, currentCategory),
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(child: HeroBannerSkeleton()),
                error: (err, _) => SliverToBoxAdapter(
                  child: HeroBanner(
                    autofocus: true,
                    items: MockData.featuredItems,
                    currentCategory: currentCategory,
                    onPlay: (item) => openHomeDetails(context, item, currentCategory),
                    onDetails: (item) => openHomeDetails(context, item, currentCategory),
                  ),
                ),
              ),

              // 2. Contenido dinámico
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
                    child: Column(children: List.generate(3, (index) => const RowSkeleton())),
                  ),
                  error: (err, _) => SliverToBoxAdapter(child: Center(child: Text('Error layout: $err'))),
                )
              else if (currentCategory == 'animes') ...[
                SliverToBoxAdapter(child: _RecentEpisodesSection(title: 'Estrenos (Hoy)', horizontalPadding: horizontalPadding)),
                SliverToBoxAdapter(child: _TrendingSection(category: 'animes', title: 'Populares esta temporada', horizontalPadding: horizontalPadding)),
                ..._buildEditorialRows(editorialRowsAsync, 'animes', includeMovies: true, movieCategory: 'anime_movies'),
                SliverToBoxAdapter(child: _AnimeMoviesSection(horizontalPadding: horizontalPadding)),
              ] else if (currentCategory == 'películas') ...[
                SliverToBoxAdapter(child: _TrendingSection(category: 'películas', title: 'Cine Recomendado', horizontalPadding: horizontalPadding, isWide: true)),
              ] else if (currentCategory == 'series') ...[
                SliverToBoxAdapter(child: _TrendingSection(category: 'series', title: 'Series y Dramas Populares', horizontalPadding: horizontalPadding)),
              ] else if (currentCategory == 'kdrama') ...[
                SliverToBoxAdapter(child: _TrendingSection(category: 'kdrama', title: 'Doramas Populares', horizontalPadding: horizontalPadding)),
              ],
              
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
          
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
    // Senior: Refinamos umbrales para tablets verticales. 
    // Si el ancho es < 920px entramos en modo Ultra-Compacto para evitar desbordamientos.
    final isCompactDesktop = width < 1150;
    final isUltraCompact = width < 920;
    
    final horizontalPadding = ResponsiveUtils.horizontalPadding(context);
    final logoHeight = isUltraCompact ? 24.0 : (isCompactDesktop ? 28.0 : 32.0);
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
              color: _isScrolled ? const Color(0xFF0B0B0D).withOpacity(0.6) : const Color(0xFF0B0B0D), 
              border: Border(
                bottom: BorderSide(
                  color: _isScrolled ? Colors.white.withOpacity(0.08) : Colors.transparent,
                  width: 0.5,
                ),
              ),
            ),
            padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 12),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 40,
                child: Row(
                  children: [
                    SvgPicture.asset(
                      'assets/icons/auris-tv-icon.svg',
                      height: 30,
                      colorFilter: const ColorFilter.mode(Color(0xFFEF7A1E), BlendMode.srcIn),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 700),
                        switchInCurve: Curves.easeInOutQuart,
                        switchOutCurve: Curves.easeInOutQuart,
                        transitionBuilder: (child, animation) {
                          final isFilter = child.key == const ValueKey('home_nav_filter');
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
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
                                      shaderCallback: (Rect rect) => const LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [Colors.black, Colors.transparent],
                                        stops: [0.8, 1.0],
                                      ).createShader(rect),
                                      blendMode: BlendMode.dstIn,
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        physics: const BouncingScrollPhysics(),
                                        padding: const EdgeInsets.only(right: 20),
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
                                        color: Colors.white.withOpacity(0.1),
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
                                      style: GoogleFonts.poppins(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w700),
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
        filter: ImageFilter.blur(sigmaX: _isScrolled ? 20.0 : 0.0, sigmaY: _isScrolled ? 20.0 : 0.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: navHeight,
          decoration: BoxDecoration(
            color: _isScrolled ? const Color(0xFF0B0B0D).withOpacity(0.4) : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: _isScrolled ? Colors.white.withOpacity(0.1) : Colors.transparent,
                width: 0.5,
              ),
            ),
          ),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/icons/auris-logo-web-flat.svg',
                  height: logoHeight,
                  colorFilter: const ColorFilter.mode(Color(0xFFEF7A1E), BlendMode.srcIn),
                ),
                SizedBox(width: isUltraCompact ? 8 : (isCompactDesktop ? 20 : 40)),
                _PillNavBar(
                  currentCategory: currentCategory,
                  isCompact: isCompactDesktop,
                  isUltraCompact: isUltraCompact,
                  onCategoryChanged: (cat) => ref.read(homeCategoryProvider.notifier).state = cat,
                ),
                const Spacer(),
                const SizedBox(width: 4),
                _FocusIconButton(
                  icon: Icons.search,
                  size: isUltraCompact ? 20 : (isCompactDesktop ? 22 : 26),
                  onPressed: () => context.push('/search'),
                ),
                // Senior: Ocultamos el selector de idioma en resoluciones intermedias para evitar overflow
                if (width >= 1080) ...[
                  const SizedBox(width: 12),
                  const _LanguageSelector(),
                ],
                const SizedBox(width: 12),
                // Senior: Ocultamos el grid en ultra-compacto (iPad Vertical) para priorizar la navegación
                if (!isUltraCompact) ...[
                  _FocusIconButton(
                    icon: Icons.grid_view_rounded,
                    size: isCompactDesktop ? 22 : 26,
                    onPressed: () => context.push('/schedule'),
                  ),
                  const SizedBox(width: 12),
                ],
                _buildUserAvatar(context, isUltraCompact ? true : isCompactDesktop),
                // Senior: El botón de login se oculta si el espacio es crítico (< 950px) para priorizar navegación
                if (width >= 950) ...[
                  const SizedBox(width: 20),
                  _AuthButton(isCompactDesktop: isCompactDesktop),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar(BuildContext context, bool isCompact) {
    final width = MediaQuery.of(context).size.width;
    final bool isUltra = width < 920;
    return Consumer(
      builder: (context, ref, _) {
        final user = ref.watch(authProvider);
        if (user == null) {
          return _FocusIconButton(
            icon: Icons.person_outline_rounded,
            size: isUltra ? 20 : (isCompact ? 20 : 22),
            onPressed: () => context.push('/settings'),
          );
        }
        return _FocusIconButton(
          onPressed: () => context.push('/settings'),
          child: Container(
            width: isUltra ? 24 : (isCompact ? 28 : 32),
            height: isUltra ? 24 : (isCompact ? 28 : 32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 1.5),
              image: user.photoUrl != null
                  ? DecorationImage(
                      image: user.photoUrl!.startsWith('assets/') ? AssetImage(user.photoUrl!) as ImageProvider : NetworkImage(user.photoUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: user.photoUrl == null ? Icon(Icons.person, size: isUltra ? 14 : (isCompact ? 16 : 18), color: Colors.white70) : null,
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
        if (user != null) return const SizedBox.shrink();

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              boxShadow: _isHovered ? [BoxShadow(color: const Color(0xFFEF7A1E).withOpacity(0.5), blurRadius: 15, spreadRadius: 2)] : [],
            ),
            child: ElevatedButton(
              onPressed: () => context.push('/login'),
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
                style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: widget.isCompactDesktop ? 13 : 15, letterSpacing: 0.5),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PillNavBar extends StatelessWidget {
  final String currentCategory;
  final ValueChanged<String> onCategoryChanged;
  final bool hideHome;
  final bool isCompact;
  final bool isUltraCompact;

  const _PillNavBar({
    required this.currentCategory, 
    required this.onCategoryChanged, 
    this.hideHome = false,
    this.isCompact = false,
    this.isUltraCompact = false,
  });

  double _calculateTextWidth(String text) {
    // Senior: Ajuste de fuente para el modo ultra-compacto (Vertical tablets)
    final double fontSize = isUltraCompact ? 13.5 : (isCompact ? 14 : 15);
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: GoogleFonts.poppins(fontSize: fontSize, fontWeight: FontWeight.w700)),
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
    final categories = hideHome ? allCategories.where((c) => c['id'] != 'inicio').toList() : allCategories;
    
    // Senior: Reducción agresiva de paddings en modo compacto y ultra-compacto
    final double hPadding = isMobile ? 24.0 : (isUltraCompact ? 14.0 : (isCompact ? 22.0 : 36.0)); 
    final double spacing = isUltraCompact ? 2.0 : (isCompact ? 6.0 : 8.0);
    final double fontSize = isUltraCompact ? 13.0 : (isCompact ? 14 : 15);
    
    final List<double> itemWidths = categories.map((c) => _calculateTextWidth(c['label']!) + hPadding).toList();
    final activeIndex = categories.indexWhere((c) => c['id'] == currentCategory);
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
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
                ),
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(categories.length, (index) {
              final cat = categories[index];
              return Padding(
                padding: EdgeInsets.only(right: index == categories.length - 1 ? 0 : spacing),
                child: _PillNavItem(
                  label: cat['label']!,
                  isActive: index == activeIndex,
                  width: itemWidths[index],
                  fontSize: fontSize,
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
  final double fontSize;
  final VoidCallback onTap;
  const _PillNavItem({required this.label, required this.isActive, required this.width, required this.onTap, this.fontSize = 15});

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
            style: GoogleFonts.poppins(color: widget.isActive ? Colors.black : Colors.white, fontSize: widget.fontSize, fontWeight: FontWeight.w700),
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
  const _FocusIconButton({this.icon, this.child, required this.onPressed, this.size = 28});

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
            width: 42, height: 42,
            decoration: BoxDecoration(shape: BoxShape.circle, color: isSelected ? Colors.white : Colors.transparent),
            child: widget.child ?? Icon(widget.icon, color: isSelected ? Colors.black : Colors.white, size: widget.size),
          ),
        ),
      ),
    );
  }
}

class _LanguageSelector extends StatefulWidget {
  const _LanguageSelector();
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
          offset: const Offset(-120, 48),
          child: MouseRegion(
            onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) => _showOverlay()),
            onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) => _hideOverlay()),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 25, spreadRadius: 2, offset: const Offset(0, 8))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A222B).withOpacity(0.55),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _LanguageItem(label: 'English', onTap: () => _hideOverlay()),
                          _LanguageItem(label: 'Español', onTap: () => _hideOverlay()),
                          _LanguageItem(label: 'Español Latinoamerica', onTap: () => _hideOverlay()),
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
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) => _showOverlay(),
        onExit: (_) => _hideOverlay(),
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
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: isSelected ? Colors.white : Colors.transparent),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.label, style: GoogleFonts.poppins(color: isSelected ? Colors.black : Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(width: 4),
                Icon(widget.icon, color: isSelected ? Colors.black : Colors.white, size: 16),
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
          decoration: BoxDecoration(color: _isHovered ? Colors.white.withOpacity(0.05) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
          child: Text(
            widget.label,
            style: GoogleFonts.poppins(color: _isHovered ? Colors.white : Colors.white.withOpacity(0.7), fontSize: 14, fontWeight: _isHovered ? FontWeight.w700 : FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

class _ContinueWatchingSection extends ConsumerWidget {
  final double horizontalPadding;
  const _ContinueWatchingSection({required this.horizontalPadding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(playbackHistoryStateProvider);
    return historyAsync.when(
      data: (history) {
        final Set<String> seenContentIds = {};
        final items = history.where((h) {
          if (h.title == null || h.isCompleted) return false;
          if (seenContentIds.contains(h.contentId)) return false;
          seenContentIds.add(h.contentId);
          return true;
        }).take(10).toList();

        if (items.isEmpty) return const SizedBox.shrink();

        return RepaintBoundary(
          child: WideContentRow(
            title: 'Continuar Viendo',
            items: items.map((h) => _mapHistoryToWide(h)).toList(),
            onItemTap: (wideItem) => _onTap(context, wideItem.originalItem as PlaybackHistory),
          ),
        );
      },
      loading: () => const RowSkeleton(isWide: true),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  WideContentItem _mapHistoryToWide(PlaybackHistory h) {
    String displayTitle = h.title ?? 'Contenido';
    final bool isMovie = h.category?.toLowerCase().contains('movie') ?? false;
    if (!isMovie && h.episode != null && h.episode!.isNotEmpty) {
      displayTitle = 'Ep ${h.episode} • $displayTitle';
    }
    String remainingText = '';
    final remainingMs = h.durationInMilliseconds - h.positionInMilliseconds;
    if (remainingMs > 0) {
      final duration = Duration(milliseconds: remainingMs);
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      remainingText = hours > 0 ? 'Quedan $hours h $minutes min' : 'Quedan $minutes min';
    }
    return WideContentItem(
      id: h.contentId,
      title: displayTitle,
      imageUrl: ApiEndpoints.proxyImage(h.posterUrl ?? h.bannerUrl ?? ''),
      progress: h.progressPercentage,
      subtitle: remainingText,
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
        '&bannerUrl=${Uri.encodeComponent(item.bannerUrl ?? "")}';
    context.push(uri);
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
      data: (items) => RepaintBoundary(
        child: EditorialContentRow(
          title: title,
          items: items,
          badge: EditorialBadge.mythical,
          onItemTap: (item) => openHomeDetails(context, item, 'inicio'),
        ),
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
      data: (items) => RepaintBoundary(
        child: ContentRow(
          title: title,
          items: items,
          horizontalPadding: horizontalPadding,
          onItemTap: (item) => openHomeDetails(context, item, 'inicio'),
        ),
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
          return RepaintBoundary(
            child: WideContentRow(
              title: title,
              items: items.map((m) => WideContentItem(
                id: m.id, title: m.title, imageUrl: m.bannerUrl ?? m.posterUrl,
                subtitle: m.subtitle, rating: formatRating(m.rating), originalItem: m,
              )).toList(),
              onItemTap: (wide) => openHomeDetails(context, wide.originalItem as MediaItem, category),
            ),
          );
        }
        return RepaintBoundary(
          child: ContentRow(
            title: title,
            items: items,
            horizontalPadding: horizontalPadding,
            onItemTap: (item) => openHomeDetails(context, item, category),
          ),
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
      data: (items) => RepaintBoundary(
        child: WideContentRow(
          title: title,
          items: items.map((m) => WideContentItem(
            id: m.id, title: m.title, imageUrl: m.bannerUrl ?? m.posterUrl,
            subtitle: m.subtitle, rating: formatRating(m.rating),
            badgeOverlay: m.airingAt != null ? AiringCountdownBadge(airingAt: m.airingAt!, aired: m.aired) : null,
            originalItem: m,
          )).toList(),
          onItemTap: (wide) => openHomeScheduleItem(context, wide.originalItem as MediaItem),
        ),
      ),
      loading: () => const RowSkeleton(isWide: true),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _AnimeMoviesSection extends ConsumerWidget {
  final double horizontalPadding;
  const _AnimeMoviesSection({required this.horizontalPadding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(animeMoviesProvider);
    return asyncData.when(
      data: (items) => RepaintBoundary(
        child: WideContentRow(
          title: 'Películas de Anime',
          items: items.map((m) => WideContentItem(
            id: m.id, title: m.title, imageUrl: m.bannerUrl ?? m.posterUrl,
            subtitle: m.subtitle, rating: formatRating(m.rating), originalItem: m,
          )).toList(),
          onItemTap: (wide) => openHomeDetails(context, wide.originalItem as MediaItem, 'anime_movies'),
        ),
      ),
      loading: () => const RowSkeleton(isWide: true),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
