import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:auris_core/auris_core.dart';
import 'package:auris_core/auris_core.dart';

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

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final hPadding = isMobile ? 16.0 : ResponsiveUtils.horizontalPadding(context);
    
    final favorites = ref.watch(favoritesProvider);
    final user = ref.watch(authProvider);

    // Filtro centralizado en Core (library_providers).
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
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
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
              backgroundColor: _isScrolled ? const Color(0xFF0B0B0D).withValues(alpha: 0.5) : Colors.transparent,
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

          // 1. SECCIÓN: HISTORIAL (todas las reproducciones, una tarjeta por obra;
          // lógica en Core, aquí solo diseño con _HistoryCard).
          ref.watch(contentHistoryProvider).when(
            data: (grouped) {
              if (grouped.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
              return SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 16),
                      child: _SectionHeader(title: 'Historial', count: grouped.length),
                    ),
                    SizedBox(
                      height: 180,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: hPadding),
                        itemCount: grouped.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final h = grouped[index];
                          return _HistoryCard(
                            item: h,
                            displayTitle: libraryDisplayTitle(h),
                            imageUrl: ApiEndpoints.proxyImage(
                              libraryCardImage(h),
                              width: 800,
                            ),
                            logoUrl: h.logoUrl,
                            remainingText: libraryHistorySubtitle(h),
                            // En Historial el borrado sí es real (toda la obra).
                            onDelete: () {
                              ref.read(playbackHistoryStateProvider.notifier).deleteContentHistory(h.contentId);
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
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
                icon: Icons.favorite_border_rounded,
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

class _HistoryCard extends StatelessWidget {
  final PlaybackHistory item;
  final String displayTitle;
  final String imageUrl;
  final String? logoUrl;
  final String remainingText;
  final VoidCallback? onDelete;

  const _HistoryCard({
    required this.item,
    required this.displayTitle,
    required this.imageUrl,
    this.logoUrl,
    required this.remainingText,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final detailParams = item.toUnifiedDetailParams();
        // FIX continuar-viendo: ver home (kind/year/type/metadataTitle + seed).
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
      child: SizedBox(
        width: 260,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: ApiEndpoints.proxyImage(imageUrl),
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.white10),
                      errorWidget: (_, __, ___) => Container(color: Colors.white10),
                    ),
                    if (logoUrl != null && logoUrl!.isNotEmpty)
                      Positioned(
                        bottom: 12,
                        left: 8,
                        right: 8,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 180,
                              maxHeight: 60,
                            ),
                            child: CachedNetworkImage(
                              imageUrl: ApiEndpoints.proxyImage(logoUrl!),
                              fit: BoxFit.contain,
                              errorWidget: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        height: 4, color: Colors.white24,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: item.progress.clamp(0.0, 1.0),
                          child: Container(color: const Color(0xFFEF7A1E)),
                        ),
                      ),
                    ),
                    if (onDelete != null)
                      Positioned(
                        top: 8, left: 8,
                        child: GestureDetector(
                          onTap: onDelete,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white70, size: 16),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            if (remainingText.isNotEmpty)
              Text(remainingText, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _LibraryMediaCard extends ConsumerWidget {
  final FavoriteItem item;
  const _LibraryMediaCard({required this.item});

  String _getDisplayCategory(FavoriteItem item) {
    final source = item.source.toLowerCase();
    // Senior Fix: Hints para identificar el servidor de procedencia
    const kdramaHints = ['tudorama', 'doramasyt', 'doramasmp4', 'pandrama'];
    const animeHints = ['jkanime', 'animeav1', 'aniyae', 'animelatino', 'fiuzidragon', 'animed23', 'animejara', 'katanime', 'animegratis'];
    const movieHints = ['gnula', 'gnulahd'];

    if (kdramaHints.any((h) => source.contains(h))) return 'KDRAMA';
    if (animeHints.any((h) => source.contains(h))) return 'ANIME';

    // Senior Fix para fuentes de películas/series (GnulaHD)
    if (movieHints.any((h) => source.contains(h))) {
      if (item.category.toLowerCase().contains('anime')) return 'ANIME';
      return 'Película';
    }

    // Para el puerto 3001 (Películas y Series)
    final cat = item.category.toLowerCase();
    if (cat.contains('movie') || cat.contains('pelicula')) return 'Película';
    if (cat.contains('serie') || cat.contains('tv')) return 'SERIE';

    return item.category.toUpperCase();
  }

  void _openDetail(BuildContext context) {
    // URI completa (kind/year/type/season) + seed (ver Movil).
    final uri = '/content/${Uri.encodeComponent(item.title)}'
        '?source=${Uri.encodeComponent(item.source)}'
        '&category=${Uri.encodeComponent(item.category)}'
        '&url=${Uri.encodeComponent(item.url)}'
        '${item.season != null ? '&season=${item.season}' : ''}'
        '${item.year != null ? '&year=${item.year}' : ''}'
        '${item.kind != null && item.kind!.isNotEmpty ? '&kind=${Uri.encodeComponent(item.kind!)}' : ''}'
        '${item.type != null && item.type!.isNotEmpty ? '&type=${Uri.encodeComponent(item.type!)}' : ''}'
        '&metadataTitle=${Uri.encodeComponent(item.title)}&banner=${Uri.encodeComponent(item.bannerUrl)}';
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
              leading: const Icon(Icons.info_outline, color: Colors.white70),
              title: const Text('Ver detalles', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(ctx);
                _openDetail(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close_rounded, color: Colors.redAccent),
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
        subtitle: _getDisplayCategory(item),
        showInfo: true,
        onTap: () => _openDetail(context),
      ),
    );
  }
}

