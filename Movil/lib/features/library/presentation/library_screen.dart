import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:auris_core/auris_core.dart';
import '../../../core/utils/responsive_utils.dart';
import '../widgets/library_media_card.dart';
import '../../home/widgets/wide_content_row.dart';

import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';

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

  WideContentItem _mapHistoryToWide(WidgetRef ref, PlaybackHistory h) {
    // Lógica centralizada en Core (library_providers): solo diseño aquí.
    final bool isMovieish = libraryIsMovieish(h);

    String displayTitle = libraryDisplayTitle(h);

    String remainingText = libraryRemainingText(h);

    final String? rawUrl = libraryCardImage(h);
    final String? logoUrl = h.logoUrl;

    return WideContentItem(
      id: h.contentId,
      title: displayTitle,
      imageUrl: ApiEndpoints.proxyImage(
        rawUrl,
        // Senior Optimization: 1280px para películas/movie_anime para nitidez en Wide Cards
        width: isMovieish ? 1280 : 800,
      ),
      logoUrl: logoUrl != null ? ApiEndpoints.proxyImage(logoUrl) : null,
      progress: h.progress,
      subtitle: remainingText,
      onDelete: () {
        // En Historial el borrado sí es real (toda la obra).
        ref.read(playbackHistoryStateProvider.notifier).deleteContentHistory(h.contentId);
      },
      originalItem: h,
    );
  }

  void _onHistoryTap(BuildContext context, PlaybackHistory item) {
    final detailParams = item.toUnifiedDetailParams();
    // FIX continuar-viendo: ver _onTap del home (kind/year/type/metadataTitle + seed).
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
    if (context.mounted) {
      context.push(uri, extra: seed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final horizontalPadding = ResponsiveUtils.horizontalPadding(context);
    
    final favorites = ref.watch(favoritesProvider);
    final user = ref.watch(authProvider);

    final filteredFavorites = filterLibraryFavorites(favorites, _activeFilter);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: _isScrolled ? 15.0 : 0.0, sigmaY: _isScrolled ? 15.0 : 0.0),
            child: AppBar(
              leadingWidth: 44,
              titleSpacing: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
                padding: EdgeInsets.zero,
                onPressed: () => context.pop(),
              ),
              title: Text('Mi biblioteca', 
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20)),
              backgroundColor: _isScrolled ? const Color(0xFF0B0B0D).withValues(alpha: 0.6) : Colors.transparent,
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
                  padding: const EdgeInsets.only(bottom: 24),
                  child: WideContentRow(
                    title: 'Historial',
                    items: grouped.map((h) {
                      final base = _mapHistoryToWide(ref, h);
                      // Subtítulo con contexto del último visionado (T2 E7 • Quedan…).
                      // WideContentItem es inmutable: reconstruir con el subtítulo.
                      return WideContentItem(
                        id: base.id,
                        title: base.title,
                        imageUrl: base.imageUrl,
                        logoUrl: base.logoUrl,
                        progress: base.progress,
                        subtitle: libraryHistorySubtitle(h),
                        favoriteItem: favoriteFromHistory(
                            h,
                            ref.read(authProvider)?.activeProfileId ??
                                'guest_profile'),
                        onDelete: () {
                          ref.read(playbackHistoryStateProvider.notifier).deleteContentHistory(h.contentId);
                        },
                        originalItem: h,
                      );
                    }).toList(),
                    onItemTap: (wideItem) => _onHistoryTap(context, wideItem.originalItem as PlaybackHistory),
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          // 2. SECCIÓN: FAVORITOS CON FILTROS
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
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
                icon: Icons.favorite_border_rounded,
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 12,
                  childAspectRatio: isMobile ? 0.54 : 0.58,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => LibraryMediaCard(item: filteredFavorites[index]),
                  childCount: filteredFavorites.length,
                ),
              ),
            ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
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

    final horizontalPadding = ResponsiveUtils.horizontalPadding(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.fromLTRB(horizontalPadding, 0, 0, 0),
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
                    color: isSelected ? const Color(0xFFEF7A1E) : Colors.white.withValues(alpha: 0.08),
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
  final IconData icon;
  const _EmptyState({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 64, color: Colors.white10),
        const SizedBox(height: 16),
        Text(message, style: const TextStyle(color: Colors.white24, fontSize: 16)),
      ],
    ),
  );
}
