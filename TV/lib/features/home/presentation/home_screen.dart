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
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

import 'package:auris_core/auris_core.dart' hide HeroBanner, FocusablePosterCard;
import '../../../core/utils/web_utils.dart';
import '../../../core/utils/tv_responsive_utils.dart';
import '../widgets/content_row.dart';
import '../widgets/editorial_content_row.dart';
import '../widgets/wide_content_row.dart';
import '../widgets/hero_banner.dart'; // Usar HeroBanner local optimizado para TV
import '../../player/presentation/player_screen.dart';
import '../../../shared/widgets/airing_countdown_badge.dart';
import '../../../core/router/app_router.dart';
import '../../../core/focus/global_focus_nodes.dart';

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
    'películas' => isAnimeMovie ? 'movie_anime' : 'movie',
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

class _HomeScreenState extends ConsumerState<HomeScreen> with RouteAware {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<HeroBannerState> _heroKey = GlobalKey<HeroBannerState>();
  bool _isScrolled = false;
  bool _splashRemoved = false;
  bool _isAppStartup = true;
  final List<GlobalKey> _sectionRowKeys = [];
  final FocusNode _searchIconFocusNode = FocusNode();
  final FocusNode _overlaySearchFocusNode = FocusNode();
  bool _showSearch = false;

  // Nodos de foco de las cÃ¡psulas del topbar (uno por categorÃ­a): el hero los
  // usa para subir con D-pad arriba directo a la cÃ¡psula activa.
  final Map<String, FocusNode> _pillFocusNodes = {
    'inicio': FocusNode(),
    'animes': FocusNode(),
    'películas': FocusNode(),
    'series': FocusNode(),
    'kdrama': FocusNode(),
    'live': FocusNode(),
  };

  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
    _scrollController.addListener(() {
      if (mounted) {
        setState(() => _scrollOffset = _scrollController.offset);
      }
    });
  }

  void _checkForUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final updateInfo = await AppUpdateService.checkForUpdate();
      if (updateInfo != null && mounted) {
        showDialog(
          context: context,
          barrierDismissible: !updateInfo.forceUpdate,
          builder: (context) =>
              AppUpdateDialog(info: updateInfo, flavor: 'tv'),
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _scrollController.removeListener(_onScroll);
    _searchIconFocusNode.dispose();
    _overlaySearchFocusNode.dispose();
    _scrollController.dispose();
    for (final node in _pillFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  void didPopNext() {
    super.didPopNext();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _heroKey.currentState?.requestPlayFocus();
      }
    });
  }

  void _onScroll() {
    if (!mounted) return;
    final scrolled = _scrollController.offset > 5;
    if (scrolled != _isScrolled) {
      setState(() => _isScrolled = scrolled);
    }
  }

  List<ComposedHomeSection> _applyTVRhythm(List<ComposedHomeSection> rawSections) {
    final List<ComposedHomeSection> tvSections = [];
    int consecutiveWide = 0;

    for (final sec in rawSections) {
      if (sec.type == HomeSectionType.continueWatching || 
          sec.presentation == SectionPresentation.top10 || 
          sec.presentation == SectionPresentation.wide || 
          sec.presentation == SectionPresentation.posterLarge) {
        tvSections.add(sec);
        if (sec.presentation == SectionPresentation.wide) {
          consecutiveWide++;
          if (consecutiveWide >= 2) consecutiveWide = 0;
        } else if (sec.presentation == SectionPresentation.posterLarge) {
          consecutiveWide = 0;
        }
      } else {
        if (consecutiveWide >= 2) {
          tvSections.add(ComposedHomeSection(
            id: '${sec.id}_large',
            type: sec.type,
            title: sec.title,
            subtitle: sec.subtitle,
            items: sec.items,
            sportsItems: sec.sportsItems,
            brandItems: sec.brandItems,
            presentation: SectionPresentation.posterLarge,
            data: sec.data is EditorialRow ? (sec.data as EditorialRow).copyWith(format: SectionPresentation.posterLarge) : sec.data,
            badge: sec.badge,
          ));
          consecutiveWide = 0;
        } else {
          tvSections.add(ComposedHomeSection(
            id: '${sec.id}_wide',
            type: sec.type,
            title: sec.title,
            subtitle: sec.subtitle,
            items: sec.items,
            sportsItems: sec.sportsItems,
            brandItems: sec.brandItems,
            presentation: SectionPresentation.wide,
            data: sec.data is EditorialRow ? (sec.data as EditorialRow).copyWith(format: SectionPresentation.wide) : sec.data,
            badge: sec.badge,
          ));
          consecutiveWide++;
        }
      }
    }
    return tvSections;
  }

  Widget _buildSection(
    ComposedHomeSection section, 
    double horizontalPadding, {
    Key? key,
    bool Function()? onArrowRightOnLast,
    bool Function()? onArrowLeftOnFirst,
    bool Function()? onArrowDownToNext,
    bool Function()? onArrowUpToPrev,
  }) {
    // Carrusel de marcas/categorías deportivas → SportsBrandCarousel
    if (section.type == HomeSectionType.brands && section.brandItems != null) {
      return SportsBrandCarousel(
        title: section.title,
        items: section.brandItems!
            .map((b) => SportsBrandItem(id: b.id, name: b.name, logoUrl: b.logoUrl, onTap: b.onTap))
            .toList(),
      );
    }

    // Filas de eventos deportivos → SportsCard (directo desde sportsItems,
    // preservando isLive/status/date/league/canales). Evita el cast `as EditorialRow`.
    if (section.sportsItems != null && section.sportsItems!.isNotEmpty) {
      return SportsEventRow(
        title: section.title,
        subtitle: section.subtitle,
        events: section.sportsItems!,
        horizontalPadding: horizontalPadding,
        // SportsCard navega a ContentSportScreen por defecto (onTap null).
      );
    }

    switch (section.type) {
      case HomeSectionType.continueWatching:
        return _ContinueWatchingSection(
          rowKey: key,
          horizontalPadding: horizontalPadding,
          onArrowRightOnLast: onArrowRightOnLast,
          onArrowLeftOnFirst: onArrowLeftOnFirst,
          onArrowDownToNext: onArrowDownToNext,
          onArrowUpToPrev: onArrowUpToPrev,
        );

      case HomeSectionType.editorial:
      case HomeSectionType.discovery:
        final row = section.data as EditorialRow;
        if (row.format == SectionPresentation.top10) {
          return RepaintBoundary(
            child: EditorialContentRow(
              key: key,
              title: row.title,
              subtitle: row.subtitle,
              items: row.items,
              badge: row.badge,
              forceTopDesign: true,
              onItemTap: (item) => openTVDetails(context, item, 'inicio'),
              onArrowRightOnLast: onArrowRightOnLast,
              onArrowLeftOnFirst: onArrowLeftOnFirst,
              onArrowDownToNext: onArrowDownToNext,
              onArrowUpToPrev: onArrowUpToPrev,
            ),
          );
        } else if (row.format == SectionPresentation.wide) {
          return RepaintBoundary(
            child: WideContentRow(
              key: key,
              title: row.title,
              subtitle: row.subtitle,
              items: row.items.map((m) => _wideItemFromMedia(m)).toList(),
              onItemTap: (wideItem) => openTVDetails(context, wideItem.originalItem as MediaItem, 'inicio'),
              onArrowRightOnLast: onArrowRightOnLast,
              onArrowLeftOnFirst: onArrowLeftOnFirst,
              onArrowDownToNext: onArrowDownToNext,
              onArrowUpToPrev: onArrowUpToPrev,
            ),
          );
        } else if (row.format == SectionPresentation.posterLarge) {
          return RepaintBoundary(
            child: EditorialContentRow(
              key: key,
              title: row.title,
              subtitle: row.subtitle,
              items: row.items,
              badge: row.badge,
              format: SectionPresentation.posterLarge,
              onItemTap: (item) => openTVDetails(context, item, 'inicio'),
              onArrowRightOnLast: onArrowRightOnLast,
              onArrowLeftOnFirst: onArrowLeftOnFirst,
              onArrowDownToNext: onArrowDownToNext,
              onArrowUpToPrev: onArrowUpToPrev,
            ),
          );
        } else {
          return RepaintBoundary(
            child: EditorialContentRow(
              key: key,
              title: row.title,
              subtitle: row.subtitle,
              items: row.items,
              badge: row.badge,
              format: row.format,
              onItemTap: (item) => openTVDetails(context, item, 'inicio'),
              onArrowRightOnLast: onArrowRightOnLast,
              onArrowLeftOnFirst: onArrowLeftOnFirst,
              onArrowDownToNext: onArrowDownToNext,
              onArrowUpToPrev: onArrowUpToPrev,
            ),
          );
        }

      case HomeSectionType.top10Global:
        return _Top10Section(
          rowKey: key,
          title: section.title ?? 'Top 10 de hoy', 
          horizontalPadding: horizontalPadding,
          onArrowRightOnLast: onArrowRightOnLast,
          onArrowLeftOnFirst: onArrowLeftOnFirst,
          onArrowDownToNext: onArrowDownToNext,
          onArrowUpToPrev: onArrowUpToPrev,
        );

      case HomeSectionType.recentlyAdded:
        return _RecentlyAddedSection(
          rowKey: key,
          title: section.title ?? 'Recién añadido', 
          horizontalPadding: horizontalPadding,
          onArrowRightOnLast: onArrowRightOnLast,
          onArrowLeftOnFirst: onArrowLeftOnFirst,
          onArrowDownToNext: onArrowDownToNext,
          onArrowUpToPrev: onArrowUpToPrev,
        );

      case HomeSectionType.trendingAnime:
        return _TrendingSection(
          rowKey: key,
          category: 'animes', 
          title: section.title ?? 'Animes en tendencia', 
          horizontalPadding: horizontalPadding,
          onArrowRightOnLast: onArrowRightOnLast,
          onArrowLeftOnFirst: onArrowLeftOnFirst,
          onArrowDownToNext: onArrowDownToNext,
          onArrowUpToPrev: onArrowUpToPrev,
        );

      case HomeSectionType.trendingMovies:
        return _TrendingSection(
          rowKey: key,
          category: 'películas', 
          title: section.title ?? 'Películas destacadas', 
          horizontalPadding: horizontalPadding, 
          isWide: true,
          onArrowRightOnLast: onArrowRightOnLast,
          onArrowLeftOnFirst: onArrowLeftOnFirst,
          onArrowDownToNext: onArrowDownToNext,
          onArrowUpToPrev: onArrowUpToPrev,
        );

      case HomeSectionType.recentEpisodes:
        return _RecentEpisodesSection(
          rowKey: key,
          title: section.title ?? 'Estrenos (Hoy)', 
          horizontalPadding: horizontalPadding,
          onArrowRightOnLast: onArrowRightOnLast,
          onArrowLeftOnFirst: onArrowLeftOnFirst,
          onArrowDownToNext: onArrowDownToNext,
          onArrowUpToPrev: onArrowUpToPrev,
        );

      case HomeSectionType.recommendation:
        final row = section.data as EditorialRow;
        if (row.format == SectionPresentation.top10) {
          return RepaintBoundary(
            child: EditorialContentRow(
              key: key,
              title: row.title,
              subtitle: row.subtitle,
              items: row.items,
              badge: row.badge,
              forceTopDesign: true,
              onItemTap: (item) => openTVDetails(context, item, 'inicio'),
              onArrowRightOnLast: onArrowRightOnLast,
              onArrowLeftOnFirst: onArrowLeftOnFirst,
              onArrowDownToNext: onArrowDownToNext,
              onArrowUpToPrev: onArrowUpToPrev,
            ),
          );
        } else if (row.format == SectionPresentation.wide) {
          return RepaintBoundary(
            child: WideContentRow(
              key: key,
              title: row.title,
              subtitle: row.subtitle,
              items: row.items.map((m) => _wideItemFromMedia(m)).toList(),
              onItemTap: (wideItem) => openTVDetails(context, wideItem.originalItem as MediaItem, 'inicio'),
              onArrowRightOnLast: onArrowRightOnLast,
              onArrowLeftOnFirst: onArrowLeftOnFirst,
              onArrowDownToNext: onArrowDownToNext,
              onArrowUpToPrev: onArrowUpToPrev,
            ),
          );
        } else {
          return RepaintBoundary(
            child: ContentRow(
              key: key,
              title: row.title,
              subtitle: row.subtitle,
              items: row.items,
              onItemTap: (item) => openTVDetails(context, item, 'inicio'),
              onArrowRightOnLast: onArrowRightOnLast,
              onArrowLeftOnFirst: onArrowLeftOnFirst,
              onArrowDownToNext: onArrowDownToNext,
              onArrowUpToPrev: onArrowUpToPrev,
            ),
          );
        }

      // Marcas: ya se maneja al inicio de _buildSection (defensivo).
      case HomeSectionType.brands:
        return const SizedBox.shrink();
    }
  }

  WideContentItem _wideItemFromMedia(MediaItem m, {Widget? badgeOverlay}) {
    final bool isMovieish = m.type == MediaType.movie || m.card?.kind == 'movie_anime';
    final String? rawSub = m.subtitle;
    final bool isJustYear = rawSub != null && RegExp(r'^(?:19|20)\d{2}$').hasMatch(rawSub.trim());
    final bool isHomeInicio = ref.read(homeCategoryProvider) == 'inicio';
    final String? effectiveSubtitle = (isJustYear || isHomeInicio) ? null : rawSub;

    return WideContentItem(
      id: m.id,
      title: m.title,
      imageUrl: ApiEndpoints.proxyImage(
        m.bannerUrl ?? m.posterUrl,
        width: isMovieish ? 1280 : 800,
      ),
      logoUrl: m.logoUrl,
      isBannerFallback: m.isBannerFallback,
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

    if (!layoutAsync.isLoading && !_splashRemoved) {
      _splashRemoved = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WebUtils.removeSplashScreen();
      });
    }

    // Senior TV Tuning: La altura del Navbar en TV adaptada a un tamaÃ±o estÃ¡ndar y cÃ³modo
    final navHeight = TVResponsiveUtils.topBarHeight(context);

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            cacheExtent: 700,
            slivers: [
              // Espaciador para el Navbar y Sticky Compact Hero si está activo (con solapamiento de ~40px estilo Prime Video)
              SliverToBoxAdapter(
                child: SizedBox(height: navHeight + (_scrollOffset > 250 ? 235.0 : 0.0)),
              ),

              // 1. Banner Principal
              heroBannerItemsAsync.when(
                data: (displayItems) {
                  if (displayItems.isEmpty) return const SliverToBoxAdapter(child: HeroBannerSkeleton());

                  final bool shouldAutofocus = _isAppStartup && currentCategory == 'inicio';
                  if (shouldAutofocus) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _isAppStartup = false);
                    });
                  }

                  return SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: HeroBanner(
                        key: _heroKey,
                        autofocus: shouldAutofocus,
                        items: displayItems,
                        currentCategory: currentCategory,
                        // D-pad arriba desde el hero -> cÃ¡psula activa del topbar.
                        pillFocusNode: _pillFocusNodes[currentCategory] ?? _pillFocusNodes['inicio'],
                        // D-pad abajo desde el hero -> primera tarjeta de la 1ª sección.
                        onArrowDown: () {
                          if (_sectionRowKeys.isEmpty) return false;
                          final state = _sectionRowKeys.first.currentState;
                          if (state != null) {
                            try {
                              return (state as dynamic).focusFirstCard() == true;
                            } catch (_) {}
                          }
                          return false;
                        },
                        onFocused: () {
                          // Centrar el hero al enfocarlo, con la misma cadencia que
                          // las filas (300ms) para que la navegación sea uniforme.
                          if (_scrollController.hasClients && _scrollController.offset > 1) {
                            _scrollController.animateTo(
                              0,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutQuart,
                            );
                          }
                        },
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

              const SliverToBoxAdapter(child: SizedBox(height: 0)),

              // 2. Contenido dinámico
              if (currentCategory == 'inicio') 
                layoutAsync.when(
                  data: (rawSections) {
                    final sections = _applyTVRhythm(rawSections);
                    while (_sectionRowKeys.length < sections.length) {
                      _sectionRowKeys.add(GlobalKey());
                    }
                    if (_sectionRowKeys.length > sections.length) {
                      _sectionRowKeys.length = sections.length;
                    }
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return RepaintBoundary(
                            child: _buildSection(
                              sections[index], 
                              horizontalPadding,
                              key: _sectionRowKeys[index],
                              onArrowRightOnLast: index + 1 < sections.length
                                  ? () {
                                      final state = _sectionRowKeys[index + 1].currentState;
                                      if (state != null) {
                                        try {
                                          return (state as dynamic).focusFirstCard() == true;
                                        } catch (_) {}
                                      }
                                      return false;
                                    }
                                  : null,
                              onArrowLeftOnFirst: index > 0
                                  ? () {
                                      final state = _sectionRowKeys[index - 1].currentState;
                                      if (state != null) {
                                        try {
                                          return (state as dynamic).focusLastCard() == true;
                                        } catch (_) {}
                                      }
                                      return false;
                                    }
                                  : null,
                              onArrowDownToNext: index + 1 < sections.length
                                  ? () {
                                      final state = _sectionRowKeys[index + 1].currentState;
                                      if (state != null) {
                                        try {
                                          return (state as dynamic).focusRememberedCard() == true;
                                        } catch (_) {}
                                      }
                                      return false;
                                    }
                                  : null,
                              onArrowUpToPrev: index > 0
                                  ? () {
                                      final state = _sectionRowKeys[index - 1].currentState;
                                      if (state != null) {
                                        try {
                                          return (state as dynamic).focusRememberedCard() == true;
                                        } catch (_) {}
                                      }
                                      return false;
                                    }
                                  : null,
                            ),
                          );
                        },
                        childCount: sections.length,
                      ),
                    );
                  },
                  loading: () => SliverToBoxAdapter(
                    child: Column(
                      children: List.generate(3, (index) => const RowSkeleton()),
                    ),
                  ),
                  error: (err, _) => SliverToBoxAdapter(child: Center(child: Text('Error layout: $err'))),
                )
              else
                layoutAsync.when(
                  data: (sections) {
                    while (_sectionRowKeys.length < sections.length) {
                      _sectionRowKeys.add(GlobalKey());
                    }
                    if (_sectionRowKeys.length > sections.length) {
                      _sectionRowKeys.length = sections.length;
                    }
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return RepaintBoundary(
                            child: _buildSection(
                              sections[index], 
                              horizontalPadding,
                              key: _sectionRowKeys[index],
                              onArrowRightOnLast: index + 1 < sections.length
                                  ? () {
                                      final state = _sectionRowKeys[index + 1].currentState;
                                      if (state != null) {
                                        try {
                                          return (state as dynamic).focusFirstCard() == true;
                                        } catch (_) {}
                                      }
                                      return false;
                                    }
                                  : null,
                              onArrowLeftOnFirst: index > 0
                                  ? () {
                                      final state = _sectionRowKeys[index - 1].currentState;
                                      if (state != null) {
                                        try {
                                          return (state as dynamic).focusLastCard() == true;
                                        } catch (_) {}
                                      }
                                      return false;
                                    }
                                  : null,
                              onArrowDownToNext: index + 1 < sections.length
                                  ? () {
                                      final state = _sectionRowKeys[index + 1].currentState;
                                      if (state != null) {
                                        try {
                                          return (state as dynamic).focusRememberedCard() == true;
                                        } catch (_) {}
                                      }
                                      return false;
                                    }
                                  : null,
                              onArrowUpToPrev: index > 0
                                  ? () {
                                      final state = _sectionRowKeys[index - 1].currentState;
                                      if (state != null) {
                                        try {
                                          return (state as dynamic).focusRememberedCard() == true;
                                        } catch (_) {}
                                      }
                                      return false;
                                    }
                                  : null,
                            ),
                          );
                        },
                        childCount: sections.length,
                      ),
                    );
                  },
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

          // Sticky Compact Hero Header when scrolled down past full hero (~250px)
          if (_scrollOffset > 250)
            Positioned(
              top: navHeight,
              left: 0,
              right: 0,
              child: heroBannerItemsAsync.when(
                data: (displayItems) {
                  if (displayItems.isEmpty) return const SizedBox.shrink();
                  return Material(
                    color: Colors.black,
                    elevation: 8,
                    child: HeroBanner(
                      isCompact: true,
                      items: displayItems,
                      currentCategory: currentCategory,
                      onDetails: (item) => openTVDetails(context, item, currentCategory),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
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
    final logoHeight = TVResponsiveUtils.sp(context, 30);

    return Container(
      height: navHeight,
      color: Colors.black, // Solid black background - nothing bleeds through!
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Perfil de usuario (Estilo Netflix TV: cuadrado con esquinas redondeadas)
            _buildUserAvatar(context),
            SizedBox(width: TVResponsiveUtils.sp(context, 6)), 
            AurisIcon(AurisIcons.chevronDown, color: Colors.white54, size: 14), 
            
            const Spacer(),
            
            // Barra de cápsulas central (Clon Netflix TV)
            _PillNavBar(
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
            
            const Spacer(),
            
            // Logo AurisTV en el extremo derecho
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
        return _UserAvatarFocusable(
          focusNode: homeProfileIconFocusNode,
          user: user,
          onPressed: () => context.go('/profile'),
        );
      },
    );
  }
}

class _UserAvatarFocusable extends StatefulWidget {
  final FocusNode? focusNode;
  final dynamic user;
  final VoidCallback onPressed;

  const _UserAvatarFocusable({
    this.focusNode,
    required this.user,
    required this.onPressed,
  });

  @override
  State<_UserAvatarFocusable> createState() => _UserAvatarFocusableState();
}

class _UserAvatarFocusableState extends State<_UserAvatarFocusable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
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
          curve: Curves.easeOutCubic,
          width: 36.0,
          height: 36.0,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6.0), // Avatar cuadrado redondeado clásico de Netflix
            border: Border.all(
              color: _focused ? Colors.white : Colors.white24,
              width: _focused ? 2.5 : 1.5,
            ),
            boxShadow: _focused
                ? const [
                    BoxShadow(
                      color: Color(0x44FFFFFF),
                      blurRadius: 10.0,
                      spreadRadius: 1.0,
                    ),
                  ]
                : null,
            image: widget.user?.photoUrl != null
                ? DecorationImage(
                    image: widget.user.photoUrl!.startsWith('assets/')
                        ? AssetImage(widget.user.photoUrl!) as ImageProvider
                        : NetworkImage(widget.user.photoUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: widget.user?.photoUrl == null
              ? Center(
                  child: AurisIcon(
                    AurisIcons.user,
                    size: TVResponsiveUtils.sp(context, 16),
                    color: _focused ? Colors.white : Colors.white70,
                  ),
                )
              : null,
        ),
      ),
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
      {'id': 'live', 'label': 'Live'},
    ];

    final double hPadding = TVResponsiveUtils.sp(context, 18);
    const double spacing = 10.0;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Botón Buscar (Cápsula circular estilo Netflix)
        Padding(
          padding: const EdgeInsets.only(right: spacing),
          child: _FocusIconButton(
            focusNode: searchIconFocusNode,
            icon: AurisIcons.search,
            size: TVResponsiveUtils.sp(context, 16),
            isActive: isSearchActive,
            onPressed: onSearchPressed,
            onKeyEvent: onSearchKeyEvent,
          ),
        ),
        // Cápsulas de navegación Netflix TV
        ...categories.map((cat) {
          final id = cat['id']!;
          final isSelected = id == currentCategory && !isSearchActive;
          return Padding(
            padding: const EdgeInsets.only(right: spacing),
            child: _PillNavItem(
              key: ValueKey('pill_$id'),
              label: cat['label']!,
              isActive: isSelected,
              onTap: () => onCategoryChanged(id),
              hPadding: hPadding,
              focusNode: focusNodes?[id],
            ),
          );
        }),
        // Botón Calendario / Horarios
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
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: 36.0,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: widget.hPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.0),
            color: _focused 
                ? const Color(0xFFFFFFFF) 
                : (widget.isActive ? const Color(0xFF262626) : Colors.transparent),
            border: Border.all(
              color: _focused 
                  ? Colors.transparent 
                  : (widget.isActive ? const Color(0x26FFFFFF) : Colors.transparent),
              width: 1.0,
            ),
            boxShadow: _focused
                ? const [
                    BoxShadow(
                      color: Color(0x33FFFFFF),
                      blurRadius: 10.0,
                      spreadRadius: 0.0,
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: 'NetflixSans',
              color: _focused 
                  ? const Color(0xFF0E0E0E) 
                  : (widget.isActive ? const Color(0xFFFFFFFF) : const Color(0xB3FFFFFF)),
              fontSize: TVResponsiveUtils.sp(context, 13.5),
              fontWeight: _focused 
                  ? FontWeight.w700 
                  : (widget.isActive ? FontWeight.w600 : FontWeight.w500),
              letterSpacing: -0.1,
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
  final bool scaleOnFocus;

  const _FocusIconButton({
    this.icon,
    this.child,
    required this.onPressed,
    this.size = 28,
    this.focusNode,
    this.onKeyEvent,
    this.isActive = false,
    this.scaleOnFocus = false,
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
          curve: Curves.easeOutCubic,
          width: 36.0,
          height: 36.0,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.0),
            color: _focused
                ? const Color(0xFFFFFFFF)
                : (widget.isActive ? const Color(0xFF262626) : Colors.transparent),
            border: Border.all(
              color: _focused
                  ? Colors.transparent
                  : (widget.isActive ? const Color(0x26FFFFFF) : Colors.transparent),
              width: 1.0,
            ),
            boxShadow: _focused
                ? const [
                    BoxShadow(
                      color: Color(0x33FFFFFF),
                      blurRadius: 10.0,
                      spreadRadius: 0.0,
                    ),
                  ]
                : null,
          ),
          child: widget.child ?? (widget.icon is String
              ? AurisIcon(
                  widget.icon as String,
                  color: _focused 
                      ? const Color(0xFF0E0E0E) 
                      : (widget.isActive ? const Color(0xFFFFFFFF) : const Color(0xB3FFFFFF)),
                  size: widget.size,
                )
              : Icon(
                  widget.icon as IconData?,
                  color: _focused 
                      ? const Color(0xFF0E0E0E) 
                      : (widget.isActive ? const Color(0xFFFFFFFF) : const Color(0xB3FFFFFF)),
                  size: widget.size,
                )),
        ),
      ),
    );
  }
}

class _ContinueWatchingSection extends ConsumerWidget {
  /// Key de la fila interna (la sección es stateless: la GlobalKey debe caer
  /// en un State para que el Home pueda restaurar el foco).
  final Key? rowKey;
  final double horizontalPadding;
  final bool Function()? onArrowRightOnLast;
  final bool Function()? onArrowLeftOnFirst;
  final bool Function()? onArrowDownToNext;
  final bool Function()? onArrowUpToPrev;
  const _ContinueWatchingSection({
    this.rowKey,
    required this.horizontalPadding,
    this.onArrowRightOnLast,
    this.onArrowLeftOnFirst,
    this.onArrowDownToNext,
    this.onArrowUpToPrev,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(continueWatchingProvider);
    final uiCategory = ref.watch(homeCategoryProvider);

    return historyAsync.when(
      data: (items) {
        final filteredItems =
            items.where((h) => continueWatchingMatchesCategory(h, uiCategory)).toList();

        if (filteredItems.isEmpty) return const SizedBox.shrink();

        return WideContentRow(
          key: rowKey,
          title: 'Continuar Viendo',
          onArrowRightOnLast: onArrowRightOnLast,
          onArrowLeftOnFirst: onArrowLeftOnFirst,
          onArrowDownToNext: onArrowDownToNext,
          onArrowUpToPrev: onArrowUpToPrev,
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
  final Key? rowKey;
  final String title;
  final double horizontalPadding;
  final bool Function()? onArrowRightOnLast;
  final bool Function()? onArrowLeftOnFirst;
  final bool Function()? onArrowDownToNext;
  final bool Function()? onArrowUpToPrev;
  const _Top10Section({
    this.rowKey,
    required this.title,
    required this.horizontalPadding,
    this.onArrowRightOnLast,
    this.onArrowLeftOnFirst,
    this.onArrowDownToNext,
    this.onArrowUpToPrev,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(top10GlobalProvider);
    return asyncData.when(
      data: (items) => EditorialContentRow(
        key: rowKey,
        title: title,
        items: items,
        badge: EditorialBadge.mythical,
        forceTopDesign: true,
        onItemTap: (item) => openTVDetails(context, item, 'inicio'),
        onArrowRightOnLast: onArrowRightOnLast,
        onArrowLeftOnFirst: onArrowLeftOnFirst,
        onArrowDownToNext: onArrowDownToNext,
        onArrowUpToPrev: onArrowUpToPrev,
      ),
      loading: () => const RowSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _RecentlyAddedSection extends ConsumerWidget {
  final Key? rowKey;
  final String title;
  final double horizontalPadding;
  final bool Function()? onArrowRightOnLast;
  final bool Function()? onArrowLeftOnFirst;
  final bool Function()? onArrowDownToNext;
  final bool Function()? onArrowUpToPrev;
  const _RecentlyAddedSection({
    this.rowKey,
    required this.title,
    required this.horizontalPadding,
    this.onArrowRightOnLast,
    this.onArrowLeftOnFirst,
    this.onArrowDownToNext,
    this.onArrowUpToPrev,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(recentlyAddedProvider);
    return asyncData.when(
      data: (items) => ContentRow(
        key: rowKey,
        title: title,
        items: items,
        horizontalPadding: horizontalPadding,
        onItemTap: (item) => openTVDetails(context, item, 'inicio'),
        onArrowRightOnLast: onArrowRightOnLast,
        onArrowLeftOnFirst: onArrowLeftOnFirst,
        onArrowDownToNext: onArrowDownToNext,
        onArrowUpToPrev: onArrowUpToPrev,
      ),
      loading: () => const RowSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _TrendingSection extends ConsumerWidget {
  final Key? rowKey;
  final String category;
  final String title;
  final double horizontalPadding;
  final bool isWide;
  final bool Function()? onArrowRightOnLast;
  final bool Function()? onArrowLeftOnFirst;
  final bool Function()? onArrowDownToNext;
  final bool Function()? onArrowUpToPrev;
  const _TrendingSection({
    this.rowKey,
    required this.category,
    required this.title,
    required this.horizontalPadding,
    this.isWide = false,
    this.onArrowRightOnLast,
    this.onArrowLeftOnFirst,
    this.onArrowDownToNext,
    this.onArrowUpToPrev,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(trendingListProvider(category));
    return asyncData.when(
      data: (items) {
        if (isWide) {
          return WideContentRow(
            key: rowKey,
            title: title,
            onArrowRightOnLast: onArrowRightOnLast,
            onArrowLeftOnFirst: onArrowLeftOnFirst,
            onArrowDownToNext: onArrowDownToNext,
            onArrowUpToPrev: onArrowUpToPrev,
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
          key: rowKey,
          title: title,
          items: items,
          horizontalPadding: horizontalPadding,
          onItemTap: (item) => openTVDetails(context, item, category),
          onArrowRightOnLast: onArrowRightOnLast,
          onArrowLeftOnFirst: onArrowLeftOnFirst,
          onArrowDownToNext: onArrowDownToNext,
          onArrowUpToPrev: onArrowUpToPrev,
        );
      },
      loading: () => RowSkeleton(isWide: isWide),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _RecentEpisodesSection extends ConsumerWidget {
  final Key? rowKey;
  final String title;
  final double horizontalPadding;
  final bool Function()? onArrowRightOnLast;
  final bool Function()? onArrowLeftOnFirst;
  final bool Function()? onArrowDownToNext;
  final bool Function()? onArrowUpToPrev;
  const _RecentEpisodesSection({
    this.rowKey,
    required this.title,
    required this.horizontalPadding,
    this.onArrowRightOnLast,
    this.onArrowLeftOnFirst,
    this.onArrowDownToNext,
    this.onArrowUpToPrev,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(recentEpisodesProvider);
    final bool isHomeInicio = ref.watch(homeCategoryProvider) == 'inicio';
    return asyncData.when(
      data: (items) => WideContentRow(
        key: rowKey,
        title: title,
        onArrowRightOnLast: onArrowRightOnLast,
        onArrowLeftOnFirst: onArrowLeftOnFirst,
        onArrowDownToNext: onArrowDownToNext,
        onArrowUpToPrev: onArrowUpToPrev,
        items: items.map((m) {
          final rawSub = m.subtitle;
          final bool isJustYear = rawSub != null && RegExp(r'^(?:19|20)\d{2}$').hasMatch(rawSub.trim());
          return WideContentItem(
            id: m.id, title: m.title, imageUrl: m.bannerUrl ?? m.posterUrl,
            logoUrl: m.logoUrl,
            subtitle: (isJustYear || isHomeInicio) ? null : rawSub, rating: formatRating(m.rating),
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
  bool _suppressFocusRestore = false;
  bool _pendingFocusFirstResult = false;
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

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
    // El permiso de micrófono se pide SOLO al pulsar el icono del micro
    // (en _startVoiceSearch -> _initSpeech), no al abrir el buscador.
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
            if (_suppressFocusRestore) {
              _suppressFocusRestore = false;
              if (_firstResultFocusNode.canRequestFocus) {
                _firstResultFocusNode.requestFocus();
              } else {
                _pendingFocusFirstResult = true;
              }
              return;
            }
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

  Future<void> _initSpeech() async {
    final status = await Permission.microphone.status;
    if (!status.isGranted) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) return;
    }
    await _speech.initialize(
      onError: (error) {
        if (mounted) setState(() => _isListening = false);
      },
      onStatus: (status) {
        if (mounted && status == 'done') {
          setState(() => _isListening = false);
        }
      },
    );
  }

  Future<void> _startVoiceSearch() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }
    if (!_speech.isAvailable) {
      await _initSpeech();
      if (!_speech.isAvailable) return;
    }
    if (!mounted) return;
    setState(() => _isListening = true);
    _speech.listen(
      localeId: 'es_ES',
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      onResult: (result) {
        if (!mounted) return;
        if (result.finalResult) {
          setState(() => _isListening = false);
          final text = result.recognizedWords.trim();
          if (text.isNotEmpty) {
            _searchController.text = text;
            _onSearchSubmitted(text);
          }
        }
      },
    );
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
    _suppressFocusRestore = true;
    Timer(const Duration(milliseconds: 600), () {
      if (mounted) _suppressFocusRestore = false;
    });
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

  void _focusFirstResultIfPending() {
    if (!_pendingFocusFirstResult) return;
    _pendingFocusFirstResult = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _firstResultFocusNode.canRequestFocus) {
        _firstResultFocusNode.requestFocus();
      }
    });
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

    // Navegar sin cerrar el overlay para que al pulsar ATRÁS en ContentScreen
    // el usuario regrese al search overlay.
    if (context.mounted) {
      context.push(uri, extra: result).then((_) {
        // Al regresar del contenido al search overlay, conservamos el foco en
        // la tarjeta que el usuario tenía seleccionada antes de abrir el contenido.
        // Solo si ningún elemento del overlay mantiene el foco, restauramos a la barra.
        if (mounted) {
          if (_overlayScopeNode.focusedChild == null) {
            _focusNode.requestFocus();
          }
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
          color: const Color(0xFF000000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra de búsqueda con botón de micrófono (idéntica a referencia)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  TVResponsiveUtils.horizontalPadding(context),
                  16,
                  TVResponsiveUtils.horizontalPadding(context),
                  16,
                ),
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
                              if (_suppressFocusRestore) {
                                return KeyEventResult.ignored;
                              }
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
                            color: _isListening
                                ? const Color(0xFFEF7A1E).withOpacity(0.25)
                                : _isMicFocused
                                    ? Colors.transparent
                                    : const Color(0xFF1A1A1A),
                            border: Border.all(
                              color: _isListening || _isMicFocused
                                  ? const Color(0xFFEF7A1E)
                                  : Colors.white38,
                              width: _isListening || _isMicFocused ? 2.5 : 1.5,
                            ),
                          ),
                          child: Icon(
                            _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                            color: _isListening ? const Color(0xFFEF7A1E) : Colors.white,
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
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    TVResponsiveUtils.horizontalPadding(context),
                    4,
                    TVResponsiveUtils.horizontalPadding(context),
                    12,
                  ),
                  child: Text(
                    'Lo más buscado',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ),

              const SizedBox(height: 4),

              // Grid de resultados
              Expanded(
                child: ClipRect(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: TVResponsiveUtils.horizontalPadding(context),
                    ),
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

        _focusFirstResultIfPending();

        final notifier = ref.read(
          searchResultsProvider(
            SearchParams(category: _selectedCategory, query: _currentQuery),
          ).notifier,
        );

        // Mismo ancho de tarjeta que las filas estándar de Home: el nº de
        // columnas se calcula para que la celda mida ~posterWidth.
        const double spacing = 14.0;
        final int crossAxisCount = _overlayGridColumns(context, 0);

        return GridView.builder(
          key: const ValueKey('overlay_results_grid'),
          clipBehavior: Clip.none,
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 40),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.55,
            crossAxisSpacing: spacing,
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
                if (index < 7 && event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp) {
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
              activeBorderColor: Colors.white,
              titleFontSize: TVResponsiveUtils.sp(context, 13),
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

  int _overlayGridColumns(BuildContext context, double innerHorizontalPadding) {
    final double pw = TVResponsiveUtils.posterWidth(context);
    const double spacing = 14.0;
    final double gridW = MediaQuery.sizeOf(context).width -
        2 * TVResponsiveUtils.horizontalPadding(context) -
        innerHorizontalPadding;
    return ((gridW + spacing) / (pw + spacing)).round().clamp(1, 100);
  }

  Widget _buildTrendingGrid(AsyncValue<List<SearchResult>> trendingAsync) {
    return trendingAsync.when(
      data: (items) {
        _focusFirstResultIfPending();
        return GridView.builder(
          key: const ValueKey('overlay_trending_grid'),
          clipBehavior: Clip.none,
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 40),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _overlayGridColumns(context, 0),
            childAspectRatio: 0.55,
            crossAxisSpacing: 14,
            mainAxisSpacing: 20,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final result = items[index];
          final meta = result.resolveMetadata(_selectedCategory);
          return FocusablePosterCard(
            focusNode: index == 0 ? _firstResultFocusNode : null,
            onKeyEvent: (node, event) {
              if (index < 7 && event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp) {
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
            activeBorderColor: Colors.white,
            titleFontSize: TVResponsiveUtils.sp(context, 13),
            showInfo: true,
            aspectRatio: 2 / 3,
            onTap: () => _onContentTap(result),
          );
          },
        );
      },
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
