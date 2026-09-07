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
      imageUrl: h.posterUrl ?? h.bannerUrl ?? '',
      progress: h.progress,
      subtitle: remainingText,
      onDelete: () {
        ref.read(playbackHistoryStateProvider.notifier).deleteProgress(h.contentId, h.season, h.episode);
      },
      originalItem: h,
    );
  }

  void _onHistoryTap(BuildContext context, PlaybackHistory item) {
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
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final horizontalPadding = ResponsiveUtils.horizontalPadding(context);
    
    final favorites = ref.watch(favoritesProvider);
    final historyAsync = ref.watch(playbackHistoryStateProvider);
    final user = ref.watch(authProvider);

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
            filter: ImageFilter.blur(sigmaX: _isScrolled ? 15.0 : 0.0, sigmaY: _isScrolled ? 15.0 : 0.0),
            child: AppBar(
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
          
          // 1. SECCIÓN: CONTINUAR VIENDO (HISTORIAL UNIFICADO)
          historyAsync.when(
            data: (items) {
              if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24, top: 12),
                  child: WideContentRow(
                    title: 'Continuar Viendo',
                    items: items.map((h) => _mapHistoryToWide(ref, h)).toList(),
                    onItemTap: (wideItem) => _onHistoryTap(context, wideItem.originalItem as PlaybackHistory),
                  ),
                ),
              );
            },
            loading: () => SliverToBoxAdapter(child: RowSkeleton(isWide: true)),
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
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.65,
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
              backgroundColor: Colors.white.withValues(alpha: 0.05),
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
