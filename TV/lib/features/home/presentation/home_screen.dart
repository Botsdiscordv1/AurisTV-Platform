import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:auris_core/auris_core.dart' hide HeroBanner;
import '../../../core/utils/web_utils.dart';
import '../../../core/utils/tv_responsive_utils.dart';
import '../widgets/content_row.dart';
import '../widgets/editorial_content_row.dart';
import '../widgets/wide_content_row.dart';
import '../widgets/hero_banner.dart'; // Usar HeroBanner local optimizado para TV
import '../../player/presentation/player_screen.dart';
import '../../../shared/widgets/airing_countdown_badge.dart';

/// Senior TV Logic: Helpers de navegación globales para TV
void openTVDetails(BuildContext context, MediaItem item, String uiCategory) {
  final isAnimeMovie = item.card?.kind == 'movie_anime';
  final category = switch (uiCategory) {
    'inicio' => isAnimeMovie
        ? 'movie_anime'
        : switch (item.type) {
            MediaType.movie => 'movie',
            MediaType.kdrama => 'kdrama',
            _ => 'anime',
          },
    'animes' => isAnimeMovie ? 'movie_anime' : 'anime',
    'anime_movies' => 'movie_anime',
    'películas' => isAnimeMovie ? 'movie_anime' : 'movie',
    'kdrama' => 'kdrama',
    _ => isAnimeMovie ? 'movie_anime' : 'all',
  };
  final source = item.source.isNotEmpty ? item.source : category;

  final metaTitle = item.romaji ?? item.english ?? item.title;
  final effectiveUrl = item.detailUrl ?? item.id;
  final String? kind = isAnimeMovie ? 'movie_anime' : item.card?.kind;

  final uri = '/content/${Uri.encodeComponent(item.title)}'
      '?source=${Uri.encodeComponent(source)}'
      '&category=${Uri.encodeComponent(category)}'
      '&url=${Uri.encodeComponent(effectiveUrl)}'
      '&metadataTitle=${Uri.encodeComponent(metaTitle)}'
      '&banner=${Uri.encodeComponent(item.bannerUrl ?? '')}'
      '&year=${item.year ?? ''}'
      '${kind != null ? '&type=${Uri.encodeComponent(kind)}' : ''}'
      '&sectionId=${Uri.encodeComponent(item.sectionId ?? '')}';

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) context.push(uri, extra: item.toContentSeed());
  });
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

  Widget _buildSection(HomeLayoutSection section, double horizontalPadding) {
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
        return _RecentlyAddedSection(title: section.title ?? 'Recién añadido', horizontalPadding: horizontalPadding);

      case HomeSectionType.trendingAnime:
        return _TrendingSection(category: 'animes', title: section.title ?? 'Animes en tendencia', horizontalPadding: horizontalPadding);

      case HomeSectionType.trendingMovies:
        return _TrendingSection(category: 'películas', title: section.title ?? 'Películas destacadas', horizontalPadding: horizontalPadding, isWide: true);

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

  WideContentItem _wideItemFromMedia(MediaItem m, {Widget? badgeOverlay}) => WideContentItem(
        id: m.id,
        title: m.title,
        imageUrl: m.bannerUrl ?? m.posterUrl,
        logoUrl: m.logoUrl,
        subtitle: m.subtitle,
        rating: formatRating(m.rating),
        badgeOverlay: badgeOverlay,
        originalItem: m,
      );

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

    // Senior TV Tuning: La altura del Navbar en TV es fija y más compacta
    final navHeight = TVResponsiveUtils.sp(context, 52); // Reducido de 60 para ganar espacio vertical

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
                        key: const ValueKey('hero_tv_main'), // Senior Fix: Clave estable para evitar recreación y crashes de foco
                        autofocus: true,
                        items: displayItems,
                        currentCategory: currentCategory,
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
                        onTrailer: (item) async {
                          final directUrl = await YoutubeResolver.getDirectStreamUrl(item.trailerKey!);
                          if (directUrl != null && context.mounted) {
                            final uri = '/player/${Uri.encodeComponent(item.id)}'
                                '?url=${Uri.encodeComponent(directUrl)}'
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

              const SliverToBoxAdapter(child: SizedBox(height: 0)), // Reducido de 8 a 0 para pegar más las filas al Hero

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
    final logoHeight = TVResponsiveUtils.sp(context, 22);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _isScrolled ? 20.0 : 0.0, sigmaY: _isScrolled ? 20.0 : 0.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: navHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF0B0B0D).withOpacity(_isScrolled ? 0.9 : 0.4),
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
                _buildUserAvatar(context),
                SizedBox(width: TVResponsiveUtils.sp(context, 4)), 
                const Icon(Icons.arrow_drop_down, color: Colors.white60, size: 14), 
                SizedBox(width: TVResponsiveUtils.sp(context, 10)), 
                _FocusIconButton(
                  icon: Icons.search,
                  size: TVResponsiveUtils.sp(context, 18),
                  onPressed: () => context.go('/search'),
                ),
                
                const Spacer(),
                
                _PillNavBar(
                  currentCategory: currentCategory,
                  onCategoryChanged: (cat) => ref.read(homeCategoryProvider.notifier).state = cat,
                ),
                
                const Spacer(),
                
                _FocusIconButton(
                  icon: Icons.grid_view_rounded,
                  size: TVResponsiveUtils.sp(context, 18),
                  onPressed: () => context.push('/schedule'),
                ),
                SizedBox(width: TVResponsiveUtils.sp(context, 10)), 
                
                SvgPicture.asset(
                  'assets/icons/auris-tv-icon.svg',
                  height: logoHeight,
                  colorFilter: const ColorFilter.mode(Color(0xFFEF7A1E), BlendMode.srcIn),
                ),
              ],
            ),
          ),
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
            icon: Icons.person_outline_rounded,
            size: TVResponsiveUtils.sp(context, 18), // Reducido de 20
            onPressed: () => context.go('/settings'),
          );
        }

        return _FocusIconButton(
          onPressed: () => context.go('/settings'),
          child: Container(
            width: TVResponsiveUtils.sp(context, 24), // Reducido de 28
            height: TVResponsiveUtils.sp(context, 24), // Reducido de 28
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 1.2), // Reducido width de 1.5
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
                ? Icon(Icons.person, size: TVResponsiveUtils.sp(context, 14), color: Colors.white70) // Reducido de 16
                : null,
          ),
        );
      },
    );
  }
}

class _PillNavBar extends StatelessWidget {
  final String currentCategory;
  final ValueChanged<String> onCategoryChanged;

  const _PillNavBar({
    required this.currentCategory,
    required this.onCategoryChanged,
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

    final double hPadding = TVResponsiveUtils.sp(context, 20);
    final double spacing = TVResponsiveUtils.sp(context, 2);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: categories.map((cat) {
        final id = cat['id']!;
        final isSelected = id == currentCategory;
        return Padding(
          padding: EdgeInsets.only(right: spacing),
          child: _PillNavItem(
            key: ValueKey('pill_$id'),
            label: cat['label']!,
            isActive: isSelected,
            onTap: () => onCategoryChanged(id),
            hPadding: hPadding,
          ),
        );
      }).toList(),
    );
  }
}

class _PillNavItem extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final double hPadding;

  const _PillNavItem({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.hPadding,
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
      onFocusChange: (f) => setState(() => _focused = f),
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
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: EdgeInsets.symmetric(horizontal: widget.hPadding / 2, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            // Senior Logic: Blanco si tiene el foco, Gris (#2D2D2D) si es la categoría activa sin foco
            color: _focused 
                ? Colors.white 
                : (widget.isActive ? const Color(0xFF2D2D2D) : Colors.transparent),
            border: _focused ? Border.all(color: Colors.white, width: 1.2) : null,
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.poppins(
              // Texto negro solo cuando la cápsula es blanca (está enfocada)
              color: _focused ? Colors.black : Colors.white,
              fontSize: TVResponsiveUtils.sp(context, 10.5),
              fontWeight: FontWeight.w700,
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

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
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
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: TVResponsiveUtils.sp(context, 28),
          height: TVResponsiveUtils.sp(context, 28),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Senior Fix: Relleno blanco sólido cuando tiene el foco (según captura 2)
            color: _focused ? Colors.white : Colors.transparent,
          ),
          child: widget.child ?? Icon(
            widget.icon,
            // Senior Fix: Icono negro sobre fondo blanco cuando está enfocado
            color: _focused ? Colors.black : Colors.white,
            size: widget.size,
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
    final historyAsync = ref.watch(playbackHistoryStateProvider);

    return historyAsync.when(
      data: (items) {
        // Senior Logic: Filtrar por categoría si se especifica
        final filteredItems = categoryFilter == null
            ? items
            : items.where((h) => h.category?.toLowerCase() == categoryFilter!.toLowerCase()).toList();

        if (filteredItems.isEmpty) return const SizedBox.shrink();

        return WideContentRow(
          title: 'Continuar Viendo',
          items: filteredItems.take(10).map((h) {
            String displayTitle = h.title ?? 'Contenido';
            if (h.episode != null && h.episode!.isNotEmpty) {
              displayTitle = 'Ep ${h.episode} • $displayTitle';
            }

            return WideContentItem(
              id: h.contentId,
              title: displayTitle,
              imageUrl: h.bannerUrl ?? h.posterUrl ?? '',
              progress: h.progressPercentage,
              subtitle: 'Quedan ${(h.durationInMilliseconds - h.positionInMilliseconds) ~/ 60000} min',
              onDelete: () => ref.read(playbackHistoryStateProvider.notifier).deleteProgress(h.contentId, h.season, h.episode),
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
                '&bannerUrl=${Uri.encodeComponent(item.bannerUrl ?? "")}';
            context.push(uri);
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
            items: items.map((m) => WideContentItem(
              id: m.id, title: m.title, imageUrl: m.bannerUrl ?? m.posterUrl,
              logoUrl: m.logoUrl,
              subtitle: m.subtitle, rating: formatRating(m.rating), originalItem: m,
            )).toList(),
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
        items: items.map((m) => WideContentItem(
          id: m.id, title: m.title, imageUrl: m.bannerUrl ?? m.posterUrl,
          logoUrl: m.logoUrl,
          subtitle: m.subtitle, rating: formatRating(m.rating),
          badgeOverlay: m.airingAt != null ? AiringCountdownBadge(airingAt: m.airingAt!, aired: m.aired) : null,
          originalItem: m,
        )).toList(),
        onItemTap: (wide) => openTVScheduleItem(context, wide.originalItem as MediaItem),
      ),
      loading: () => const RowSkeleton(isWide: true),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
