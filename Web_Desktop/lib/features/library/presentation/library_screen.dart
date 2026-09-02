import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:auris_core/auris_core.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/utils/url_utils.dart';

import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:auristv_web/features/player/presentation/player_screen.dart';

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

  bool _isHighQualityThumbnail(String? url) {
    if (url == null || url.isEmpty) return false;
    final highResHints = ['tmdb.org', 'anilist.co', 'amazon.com', 'googleusercontent.com', 'blogspot.com'];
    return highResHints.any((hint) => url.contains(hint));
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final width = MediaQuery.of(context).size.width;
    final hPadding = isMobile ? 16.0 : (width - 1000).clamp(32.0, double.infinity) / 2;
    
    final favorites = ref.watch(favoritesProvider);
    final historyAsync = ref.watch(playbackHistoryStateProvider);
    final user = ref.watch(authProvider);

    // Senior Fix: Filtrado Inteligente basado en Procedencia y Categoría
    final filteredFavorites = favorites.where((f) {
      if (_activeFilter == 'todos') return true;
      
      final source = f.source.toLowerCase();
      final cat = f.category.toLowerCase();
      const kdramaHints = ['tudorama', 'doramasyt', 'doramasmp4', 'pandrama'];
      const animeHints = ['jkanime', 'animeav1', 'aniyae', 'animelatino', 'fiuzidragon', 'animed23', 'animejara', 'katanime', 'animegratis'];
      const movieHints = ['gnula', 'gnulahd'];

      if (_activeFilter == 'kdrama') return kdramaHints.any((h) => source.contains(h));
      if (_activeFilter == 'anime') {
        return animeHints.any((h) => source.contains(h)) || (movieHints.any((h) => source.contains(h)) && cat.contains('anime'));
      }
      if (_activeFilter == 'peliculas') {
        return (cat.contains('movie') || cat.contains('pelicula') || movieHints.any((h) => source.contains(h))) && !cat.contains('anime');
      }
      if (_activeFilter == 'series') return cat.contains('serie') || cat.contains('tv');
      
      return false;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: _isScrolled ? 20 : 0, sigmaY: _isScrolled ? 20 : 0),
            child: AppBar(
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
          
          // 1. SECCIÓN: CONTINUAR VIENDO (HISTORIAL)
          historyAsync.when(
            data: (history) {
              if (history.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
              return SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 16),
                      child: _SectionHeader(title: 'Recién vistos', count: history.length),
                    ),
                    SizedBox(
                      height: 180,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: hPadding),
                        itemCount: history.take(10).length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final h = history[index];
                          
                          // Senior Logic: Misma lógica de imagen que en Home
                          final bool useEpisodeThumb = _isHighQualityThumbnail(h.posterUrl);
                          final String finalImageUrl = useEpisodeThumb 
                              ? (h.posterUrl ?? '') 
                              : (h.bannerUrl ?? h.posterUrl ?? '');

                          // Formateo de Título
                          String displayTitle = h.title ?? 'Contenido';
                          final bool isMovie = h.category?.toLowerCase().contains('movie') ?? false;
                          if (!isMovie && h.episode != null && h.episode!.isNotEmpty) {
                            displayTitle = 'Ep ${h.episode} • $displayTitle';
                          }

                          // Tiempo restante
                          String remainingText = '';
                          final remainingMs = h.durationInMilliseconds - h.positionInMilliseconds;
                          if (remainingMs > 0) {
                            final duration = Duration(milliseconds: remainingMs);
                            final hours = duration.inHours;
                            final minutes = duration.inMinutes % 60;
                            if (hours > 0) {
                              remainingText = '$hours h $minutes min restantes';
                            } else {
                              remainingText = '${minutes > 0 ? minutes : 1} min restantes';
                            }
                          }

                          return _HistoryCard(
                            item: h,
                            displayTitle: displayTitle,
                            imageUrl: finalImageUrl,
                            remainingText: remainingText,
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
                  _CategoryFilters(
                    activeFilter: _activeFilter,
                    onFilterChanged: (filter) => setState(() => _activeFilter = filter),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

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
                  crossAxisCount: isMobile ? 3 : 6,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.65,
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

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = activeFilter == f['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ChoiceChip(
              label: Text(f['label']!),
              selected: isSelected,
              onSelected: (_) => onFilterChanged(f['id']!),
              backgroundColor: Colors.white.withOpacity(0.05),
              selectedColor: const Color(0xFFEF7A1E),
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
              showCheckmark: false,
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
  final String remainingText;

  const _HistoryCard({
    required this.item,
    required this.displayTitle,
    required this.imageUrl,
    required this.remainingText,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
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
          language: item.language,
        );
        
        UrlUtils.openPlayer(context, player);
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

class _LibraryMediaCard extends StatelessWidget {
  final FavoriteItem item;
  const _LibraryMediaCard({required this.item});

  String _getDisplayCategory(FavoriteItem item) {
    final source = item.source.toLowerCase();
    // Senior Fix: Hints para identificar el servidor de procedencia
    const kdramaHints = ['tudorama', 'doramasyt', 'doramasmp4', 'pandrama'];
    const animeHints = ['jkanime', 'animeav1', 'animeflv', 'aniyae', 'animelatino', 'fiuzidragon', 'tioanime', 'animed23', 'animejara', 'katanime', 'animegratis'];
    const movieHints = ['gnula', 'gnulahd'];

    if (kdramaHints.any((h) => source.contains(h))) return 'KDRAMA';
    if (animeHints.any((h) => source.contains(h))) return 'ANIME';
    
    // Senior Fix para fuentes de películas/series (GnulaHD)
    if (movieHints.any((h) => source.contains(h))) {
      if (item.category.toLowerCase().contains('anime')) return 'ANIME';
      return 'PELÍCULA';
    }
    
    // Para el puerto 3001 (Películas y Series)
    final cat = item.category.toLowerCase();
    if (cat.contains('movie') || cat.contains('pelicula')) return 'PELÍCULA';
    if (cat.contains('serie') || cat.contains('tv')) return 'SERIE';
    
    return item.category.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final uri = UrlUtils.buildShareableUri(
          title: item.title,
          source: item.source,
          url: item.url,
          category: item.category,
        );
        context.push(uri);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: ApiEndpoints.proxyImage(item.posterUrl),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (_, __) => Container(color: Colors.white10),
                  errorWidget: (_, __, ___) => Container(color: Colors.white10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, 
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
          Text(_getDisplayCategory(item), style: const TextStyle(fontSize: 9, color: Colors.white38, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

