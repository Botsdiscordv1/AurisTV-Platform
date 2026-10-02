import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:auris_core/auris_core.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/utils/url_utils.dart';

import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import '../../home/widgets/unified_section.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String _activeFilter = 'todos';
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final scrolled = _scrollController.offset > 5;
      if (scrolled != _isScrolled) setState(() => _isScrolled = scrolled);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onHistoryTap(BuildContext context, MediaItem item) {
    final history = item.playbackHistory;
    if (history == null) return;

    final detailParams = history.toUnifiedDetailParams();
    // FIX continuar-viendo: ver home (kind/year/metadataTitle/season + seed).
    final uri = UrlUtils.buildShareableUri(
      title: detailParams.title,
      source: detailParams.source,
      url: detailParams.url ?? history.contentId,
      category: detailParams.category,
      year: detailParams.year,
      type: detailParams.type,
      kind: detailParams.kind,
      metadataTitle: detailParams.metadataTitle,
      season: detailParams.season,
      sectionId: detailParams.sectionId,
      from: '/settings/library',
    );
    // Seed centralizado en Core (null si no hay URL http real).
    final seed = historyToSeed(history);
    if (context.mounted) {
      context.push(uri, extra: seed);
    }
  }

  MediaItem _historyToMediaItem(PlaybackHistory h, {String? subtitle}) {
    // Lógica centralizada en Core (library_providers): solo diseño aquí.
    final bool isMovieish = libraryIsMovieish(h);
    final String displayTitle = libraryDisplayTitle(h);
    final String remainingText = subtitle ?? libraryRemainingText(h);
    final String? rawUrl = libraryCardImage(h);

    return MediaItem(
      id: h.contentId,
      title: displayTitle,
      posterUrl: h.posterUrl ?? '',
      bannerUrl: ApiEndpoints.proxyImage(
        rawUrl,
        // Senior Optimization: 1280px para películas/movie_anime para nitidez en Wide Cards
        width: isMovieish ? 1280 : 800,
      ),
      logoUrl: h.logoUrl != null ? ApiEndpoints.proxyImage(h.logoUrl!) : null,
      type: isMovieish ? MediaType.movie : MediaType.anime,
      subtitle: remainingText,
      playbackHistory: h,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final hPadding = isMobile ? 16.0 : ResponsiveUtils.horizontalPadding(context);
    
    final favorites = ref.watch(favoritesProvider);
    final user = ref.watch(authProvider);

    final filteredFavorites =
        filterLibraryFavorites(favorites, _activeFilter);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: _isScrolled ? 20 : 0, sigmaY: _isScrolled ? 20 : 0),
            child: AppBar(
              leading: IconButton(
                icon: AurisIcon(AurisIcons.chevronLeft),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/inicio');
                  }
                },
              ),
              title: Text('Mi biblioteca', 
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20)),
              backgroundColor: _isScrolled ? const Color(0xFF0B0B0D).withOpacity(0.5) : Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              centerTitle: false,
              actions: [
                if (user?.photoUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundImage: user!.photoUrl!.startsWith('assets/')
                          ? AssetImage(user.photoUrl!) as ImageProvider
                          : CachedNetworkImageProvider(user.photoUrl!),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.top + 60)),

          // 1. SECCIÓN: HISTORIAL (todas las reproducciones, una tarjeta por obra)
          ref.watch(contentHistoryProvider).when(
            data: (grouped) {
              if (grouped.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: UnifiedSection(
                    presentation: SectionPresentation.wide,
                    title: 'Historial',
                    items: grouped.map((h) => _historyToMediaItem(h, subtitle: libraryHistorySubtitle(h))).toList(),
                    onItemTap: (item) => _onHistoryTap(context, item),
                    onItemDelete: (item) {
                      final h = item.playbackHistory;
                      if (h != null) {
                        ref.read(playbackHistoryStateProvider.notifier).deleteContentHistory(h.contentId);
                      }
                    },
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          // 2. SECCIÓN: FAVORITOS CON FILTROS
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: hPadding),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(title: 'Mi Lista', count: favorites.length),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _CategoryFilters(
              activeFilter: _activeFilter,
              onFilterChanged: (filter) => setState(() => _activeFilter = filter),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          if (filteredFavorites.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(
                message: _activeFilter == 'todos' 
                    ? 'Tu lista está vacía' 
                    : 'No tienes $_activeFilter en tu lista',
                icon: AurisIcons.bookmarkOutline,
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: hPadding),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: switch (context.breakpoint) {
                    Breakpoint.base => 3,
                    Breakpoint.sm => 4,
                    Breakpoint.md => 5,
                    Breakpoint.lg => 6,
                    Breakpoint.xl => 7,
                    Breakpoint.xxl => 8,
                  },
                  mainAxisSpacing: context.breakpoint < Breakpoint.md ? 12 : 24,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.55,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _LibraryMediaCard(item: filteredFavorites[index]),
                  childCount: filteredFavorites.length,
                ),
              ),
            ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});
  
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(title, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
      const SizedBox(width: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
        child: Text('$count', style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    ],
  );
}

class _CategoryFilters extends StatelessWidget {
  final String activeFilter;
  final ValueChanged<String> onFilterChanged;

  const _CategoryFilters({required this.activeFilter, required this.onFilterChanged});

  @override
  Widget build(BuildContext context) {
    final filters = [
      {'id': 'todos', 'label': 'Todos'},
      {'id': 'anime', 'label': 'Anime'},
      {'id': 'peliculas', 'label': 'Películas'},
      {'id': 'series', 'label': 'Series'},
      {'id': 'kdrama', 'label': 'KDrama'},
    ];

    final isMobile = ResponsiveUtils.isMobile(context);
    final hPadding = isMobile ? 16.0 : ResponsiveUtils.horizontalPadding(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.fromLTRB(hPadding, 0, 0, 0),
      child: Row(
        children: filters.map((f) {
          final isSelected = activeFilter == f['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onFilterChanged(f['id']!),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEF7A1E) : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFEF7A1E) : Colors.white12,
                    ),
                  ),
                  child: Text(
                    f['label']!,
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final String icon;
  const _EmptyState({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AurisIcon(icon, size: 64, color: Colors.white10),
        const SizedBox(height: 16),
        Text(message, style: const TextStyle(color: Colors.white24, fontSize: 16)),
      ],
    ),
  );
}

class _LibraryMediaCard extends ConsumerWidget {
  final FavoriteItem item;
  const _LibraryMediaCard({required this.item});

  void _openDetail(BuildContext context) {
    // URI completa + seed (ver Movil).
    final uri = UrlUtils.buildShareableUri(
      title: item.title,
      source: item.source,
      url: item.url,
      category: item.category,
      year: item.year,
      kind: item.kind,
      metadataTitle: item.title,
      season: item.season,
      from: '/settings/library',
    );
    context.push(uri, extra: seedFromFavorite(item));
  }

  /// Menú long-press: ver detalles / quitar (con Deshacer).
  void _showOptionsMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2D2D2D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: AurisIcon(AurisIcons.info, color: Colors.white70),
              title: const Text('Ver detalles', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(ctx);
                _openDetail(context);
              },
            ),
            ListTile(
              leading: AurisIcon(AurisIcons.close, color: Colors.redAccent),
              title: const Text('Quitar de Mi lista', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(favoritesProvider.notifier).toggleFavorite(item);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Quitado de Mi lista'),
                    action: SnackBarAction(
                      label: 'Deshacer',
                      onPressed: () {
                        ref.read(favoritesProvider.notifier).toggleFavorite(item);
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onLongPress: () => _showOptionsMenu(context, ref),
      child: FocusablePosterCard(
        title: item.title,
        posterUrl: ApiEndpoints.proxyImage(item.posterUrl),
        subtitle: null,
        showInfo: true,
        onTap: () => _openDetail(context),
      ),
    );
  }
}
