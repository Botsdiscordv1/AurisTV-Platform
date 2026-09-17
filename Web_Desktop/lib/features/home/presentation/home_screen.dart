import 'dart:ui';
import 'package:flutter/foundation.dart'; // Senior Fix: Necesario para kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:auris_core/auris_core.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/utils/web_utils.dart';
import '../../../core/utils/url_utils.dart';
import '../widgets/content_row.dart';
import '../widgets/editorial_content_row.dart';
import '../widgets/wide_content_row.dart';
import '../widgets/unified_section.dart';
import 'package:auristv_web/features/player/presentation/player_screen.dart';
import '../../../shared/widgets/airing_countdown_badge.dart';

/// Senior: Helpers de navegación globales para permitir acceso desde widgets externos
/// sin depender de la instancia privada de _HomeScreenState.
void openHomeDetails(BuildContext context, MediaItem item, String uiCategory) {
  final category = switch (uiCategory) {
    'inicio' => (item.card?.kind == 'movie_anime') 
        ? 'movie_anime' 
        : switch (item.type) {
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
  final effectiveUrl = item.detailUrl ?? item.id;

  final uri = UrlUtils.buildShareableUri(
    title: item.title,
    source: source,
    url: effectiveUrl,
    category: category,
    year: item.year,
    type: item.card?.kind,
    sectionId: item.sectionId,
    from: '/inicio',
  );
      
  if (context.mounted) {
    context.push(uri, extra: item.toContentSeed());
  }
}

void openHomeScheduleItem(BuildContext context, MediaItem item) {
  final itemYear = item.year ??
      (item.airingAt != null
          ? DateTime.fromMillisecondsSinceEpoch(item.airingAt! * 1000).year
          : null);

  final seed = item.card;
  final source = seed?.source ?? item.source;
  final url = seed?.url ?? item.id;

  final uri = UrlUtils.buildShareableUri(
    title: item.title,
    source: source,
    url: url,
    category: 'anime',
    year: itemYear,
    type: item.card?.kind ?? (item.type == MediaType.anime ? 'anime' : null),
    from: '/horario',
  );
  
  if (context.mounted) {
    context.push(uri, extra: item.toContentSeed());
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  final String categoryPath;
  const HomeScreen({super.key, this.categoryPath = 'inicio'});

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
    
    // Senior Sync: Sincronizar el provider de categoría con la ruta inicial
    Future.microtask(() {
      if (mounted) {
        ref.read(homeCategoryProvider.notifier).state = widget.categoryPath;
      }
    });

    // Senior Performance: Disparamos la precarga escalonada con delay inicial.
    // Movido a initState para evitar múltiples disparos en re-builds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) ref.read(homePrefetchProvider);
      });
    });
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Senior Sync: Si la ruta cambia (ej: botón atrás del browser), actualizamos el estado
    if (oldWidget.categoryPath != widget.categoryPath) {
      ref.read(homeCategoryProvider.notifier).state = widget.categoryPath;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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

          list.add(SliverToBoxAdapter(
            child: UnifiedSection(
              presentation: row.format,
              title: row.title,
              subtitle: row.subtitle,
              items: row.items,
              badge: row.badge,
              onItemTap: (item) => openHomeDetails(context, item, targetCat),
            ),
          ));
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
    if (section.type == HomeSectionType.continueWatching) {
      // Pass category filter if provided in data hint from provider
      final String? categoryFilter = section.data is String ? section.data as String : null;
      return _ContinueWatchingSection(
        horizontalPadding: horizontalPadding,
        categoryFilter: categoryFilter
      );
    }

    return UnifiedSection(
      presentation: section.presentation,
      title: section.title,
      subtitle: section.subtitle,
      items: section.items,
      badge: section.badge,
      onItemTap: (item) => openHomeDetails(context, item, ref.read(homeCategoryProvider)),
    );
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
    // Senior Fix: Al cambiar categoría siempre volver arriba
    ref.listen(homeCategoryProvider, (prev, next) {
      if (prev != next && prev != null && _scrollController.hasClients) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
      }
    });
    final useMobileLayout = context.useMobileLayout;
    final horizontalPadding = ResponsiveUtils.horizontalPadding(context);
    
    final layoutAsync = ref.watch(homeLayoutProvider);
    final heroBannerItemsAsync = ref.watch(heroBannerItemsProvider(currentCategory));
    final editorialRowsAsync = ref.watch(editorialRowsProvider(currentCategory));

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
                child: SizedBox(height: useMobileLayout ? (MediaQuery.of(context).padding.top + 58) : 78),
              ),

              // 1. Banner Principal (Conectado al Sistema Editorial del Servidor)
              heroBannerItemsAsync.when(
                data: (displayItems) {
                  if (displayItems.isEmpty) {
                    return const SliverToBoxAdapter(child: HeroBannerSkeleton());
                  }

                  return SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: HeroBanner(
                        key: ValueKey('hero_web_$currentCategory'), // Senior Fix: Reset total al cambiar categoría
                        autofocus: true,
                        items: displayItems,
                        currentCategory: currentCategory,
                        onPlay: (item) => openHomeDetails(context, item, currentCategory),
                        onDetails: (item) => openHomeDetails(context, item, currentCategory),
                        onTrailer: (item) async {
                          // Senior Fix: En Web, si el usuario pulsa "Tráiler", extraemos el stream directo
                          // para usar el reproductor nativo (media_kit) y evitar el IFrame si es posible,
                          // o simplemente delegamos a la lógica interna del HeroBanner si se prefiere.
                          // Para consistencia con Móvil, usamos la extracción.
                          final directUrl = await YoutubeResolver.getDirectStreamUrl(item.trailerKey!);
                          if (directUrl != null && context.mounted) {
                            final player = PlayerScreen(
                              contentId: item.id,
                              sourceUrl: directUrl,
                              source: 'YouTube',
                              episode: 'Trailer',
                              serverName: 'YouTube',
                              language: 'Trailer',
                              category: item.type.name,
                              title: item.title,
                              posterUrl: item.posterUrl,
                              bannerUrl: item.bannerUrl,
                            );
                            UrlUtils.openPlayer(context, player);
                          }
                        },
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

              const SliverToBoxAdapter(child: SizedBox(height: 6)), // Senior: Espaciado refinado para equilibrio visual
              
              // 2. Contenido dinámico
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
                    children: [
                      const SizedBox(height: 12),
                      ...List.generate(3, (index) => const RowSkeleton()),
                    ],
                  ),
                ),
                error: (err, _) => SliverToBoxAdapter(child: Center(child: Text('Error layout: $err'))),
              ),
              
              SliverToBoxAdapter(child: SizedBox(height: context.useMobileLayout ? 18 : 32)), // Senior: Espaciado final adaptativo (18/32)
            ],
          ),
          
          Positioned(
            top: 0, left: 0, right: 0,
            child: _buildTopNavContent(context, ref, currentCategory, useMobileLayout),
          ),
        ],
      ),
    );
  }

  Widget _buildTopNavContent(BuildContext context, WidgetRef ref, String currentCategory, bool useMobileLayout) {
    final width = MediaQuery.of(context).size.width;
    // Senior: Refinamos umbrales para tablets verticales y diferentes densidades.
    final isCompactDesktop = context.breakpoint < Breakpoint.xl;
    final isUltraCompact = context.breakpoint <= Breakpoint.lg;
    
    final horizontalPadding = ResponsiveUtils.horizontalPadding(context);
    final logoHeight = isUltraCompact ? 24.0 : (isCompactDesktop ? 28.0 : 32.0);
    final navHeight = isCompactDesktop ? 70.0 : 80.0;
    
    if (useMobileLayout) {
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
                                          onCategoryChanged: _handleCategoryChange,
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
                                    onTap: () => _handleCategoryChange('inicio'),
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
                  onCategoryChanged: _handleCategoryChange,
                ),
                const Spacer(),
                const SizedBox(width: 4),
                _FocusIconButton(
                  icon: Icons.search,
                  size: isUltraCompact ? 20 : (isCompactDesktop ? 22 : 26),
                  onPressed: () => context.go('/catalogo'),
                ),
                const SizedBox(width: 12),
                const _LanguageSelector(),
                const SizedBox(width: 12),
                // Senior: Ocultamos el grid en ultra-compacto (iPad Vertical) para priorizar la navegación
                if (!isUltraCompact) ...[
                  _FocusIconButton(
                    icon: Icons.grid_view_rounded,
                    size: isCompactDesktop ? 22 : 26,
                    onPressed: () => context.push('/horario'),
                  ),
                  const SizedBox(width: 12),
                ],
                _buildUserAvatar(context, isUltraCompact ? true : isCompactDesktop),
                SizedBox(width: isCompactDesktop ? 0 : 4), // Senior Fix: Eliminamos espacio extra a la derecha del perfil
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleCategoryChange(String cat) {
    // Senior Strategy: Actualizamos el estado interno en lugar de navegar a una nueva ruta
    // para evitar errores de deep linking en la web y mantener la URL limpia.
    ref.read(homeCategoryProvider.notifier).state = cat;
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
            onPressed: () => context.go('/settings'),
          );
        }
        return _FocusIconButton(
          onPressed: () => context.go('/settings'),
          builder: (context, isSelected) => Container(
            width: isUltra ? 24 : (isCompact ? 28 : 32),
            height: isUltra ? 24 : (isCompact ? 28 : 32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.black12 : Colors.white24, 
                width: 1.5
              ),
              image: user.photoUrl != null
                  ? DecorationImage(
                      image: user.photoUrl!.startsWith('assets/') ? AssetImage(user.photoUrl!) as ImageProvider : NetworkImage(user.photoUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: user.photoUrl == null 
                ? Icon(
                    Icons.person, 
                    size: isUltra ? 14 : (isCompact ? 16 : 18), 
                    color: isSelected ? Colors.black87 : Colors.white70
                  ) 
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
              onPressed: () => context.go('/login'),
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
  final Widget Function(BuildContext context, bool isSelected)? builder;
  final Widget? child;
  final VoidCallback onPressed;
  final double size;
  const _FocusIconButton({this.icon, this.builder, this.child, required this.onPressed, this.size = 28});

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
            child: widget.builder != null 
                ? widget.builder!(context, isSelected)
                : (widget.child ?? Icon(widget.icon, color: isSelected ? Colors.black : Colors.white, size: widget.size)),
          ),
        ),
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector();

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: PopupMenuButton<String>(
        offset: const Offset(0, 48),
        color: const Color(0xFF1A222B).withOpacity(0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        elevation: 10,
        tooltip: 'Cambiar idioma',
        onSelected: (String value) {
          // Lógica de cambio de idioma aquí
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          _buildPopupItem('English'),
          _buildPopupItem('Español'),
          _buildPopupItem('Español Latinoamerica'),
        ],
        child: const _LanguageButton(),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(String label) {
    return PopupMenuItem<String>(
      value: label,
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: Colors.white.withOpacity(0.9),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LanguageButton extends StatefulWidget {
  const _LanguageButton();
  @override
  State<_LanguageButton> createState() => _LanguageButtonState();
}

class _LanguageButtonState extends State<_LanguageButton> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = _focused || _hovered;
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12), 
            color: isSelected ? Colors.white : Colors.transparent
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ES', 
                style: GoogleFonts.poppins(
                  color: isSelected ? Colors.black : Colors.white, 
                  fontSize: 13, 
                  fontWeight: FontWeight.w700
                )
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down, 
                color: isSelected ? Colors.black : Colors.white, 
                size: 16
              ),
            ],
          ),
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
    final continueWatchingAsync = ref.watch(continueWatchingProvider);

    return continueWatchingAsync.when(
      data: (items) {
        // Senior Logic: Aplicar filtro de categoría si se solicita (ej: 'anime')
        final filteredItems = categoryFilter == null
            ? items
            : items.where((h) => h.category?.toLowerCase() == categoryFilter!.toLowerCase()).toList();

        if (filteredItems.isEmpty) return const SizedBox.shrink();

        return RepaintBoundary(
          child: WideContentRow(
            title: 'Continuar Viendo',
            items: filteredItems.map((h) => _mapHistoryToWide(ref, h)).toList(),
            onItemTap: (wideItem) => _onTap(context, wideItem.originalItem as PlaybackHistory),
          ),
        );
      },
      // Mientras carga (Hot Restart), mostramos el esqueleto para evitar saltos visuales
      loading: () => const RowSkeleton(isWide: true),
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
      imageUrl: h.bannerUrl ?? h.posterUrl ?? '',
      logoUrl: null, // Historial normalmente no tiene logo independiente guardado aún
      progress: h.progress,
      subtitle: remainingText,
      onDelete: () {
        ref.read(playbackHistoryStateProvider.notifier).deleteProgress(h.contentId, h.season, h.episode);
      },
      originalItem: h,
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
    );
    
    // Senior UI Fix: Abrir el reproductor como un diálogo a pantalla completa
    // para mantener la URL actual intacta.
    UrlUtils.openPlayer(context, player);
  }
}

class _Top10Section extends ConsumerWidget {
  final String title;
  final double horizontalPadding;
  final SectionPresentation presentation;
  const _Top10Section({required this.title, required this.horizontalPadding, this.presentation = SectionPresentation.top10});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(top10GlobalProvider);
    return asyncData.when(
      data: (items) => UnifiedSection(
        presentation: presentation,
        title: title,
        items: items,
        badge: EditorialBadge.mythical,
        onItemTap: (item) => openHomeDetails(context, item, 'inicio'),
      ),
      loading: () => const RowSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _RecentlyAddedSection extends ConsumerWidget {
  final String title;
  final double horizontalPadding;
  final SectionPresentation presentation;
  const _RecentlyAddedSection({required this.title, required this.horizontalPadding, this.presentation = SectionPresentation.poster});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(recentlyAddedProvider);
    return asyncData.when(
      data: (items) => UnifiedSection(
        presentation: presentation,
        title: title,
        items: items,
        onItemTap: (item) => openHomeDetails(context, item, 'inicio'),
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
  final SectionPresentation presentation;
  const _TrendingSection({required this.category, required this.title, required this.horizontalPadding, this.presentation = SectionPresentation.poster});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(trendingListProvider(category));
    return asyncData.when(
      data: (items) => UnifiedSection(
        presentation: presentation,
        title: title,
        items: items,
        onItemTap: (item) => openHomeDetails(context, item, category),
      ),
      loading: () => RowSkeleton(isWide: presentation == SectionPresentation.wide),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _RecentEpisodesSection extends ConsumerWidget {
  final String title;
  final double horizontalPadding;
  final SectionPresentation presentation;
  const _RecentEpisodesSection({required this.title, required this.horizontalPadding, this.presentation = SectionPresentation.wide});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(recentEpisodesProvider);
    return asyncData.when(
      data: (items) => UnifiedSection(
        presentation: presentation,
        title: title,
        items: items,
        onItemTap: (item) => openHomeScheduleItem(context, item),
      ),
      loading: () => RowSkeleton(isWide: presentation == SectionPresentation.wide),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _AnimeMoviesSection extends ConsumerWidget {
  final double horizontalPadding;
  final SectionPresentation presentation;
  const _AnimeMoviesSection({required this.horizontalPadding, this.presentation = SectionPresentation.wide});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(animeMoviesProvider);
    return asyncData.when(
      data: (items) => UnifiedSection(
        presentation: presentation,
        title: 'Películas de Anime',
        items: items,
        onItemTap: (item) => openHomeDetails(context, item, 'anime_movies'),
      ),
      loading: () => RowSkeleton(isWide: presentation == SectionPresentation.wide),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
