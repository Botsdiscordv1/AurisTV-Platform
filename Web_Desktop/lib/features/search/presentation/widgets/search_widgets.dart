import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:auris_core/auris_core.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../providers/search_provider.dart';

class SearchHistorySection extends ConsumerWidget {
  final Function(String) onQueryTap;
  const SearchHistorySection({super.key, required this.onQueryTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(searchHistoryProvider);
    if (history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Búsquedas recientes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              TextButton(
                onPressed: () => ref.read(searchHistoryProvider.notifier).clearHistory(),
                child: const Text('Borrar todo', style: TextStyle(color: Colors.white54, fontSize: 13)),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final item = history[index];
            return ListTile(
              leading: const Icon(Icons.history_rounded, color: Colors.white38, size: 22),
              title: Text(item.query, style: const TextStyle(color: Colors.white70, fontSize: 15)),
              trailing: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
                onPressed: () => ref.read(searchHistoryProvider.notifier).removeQuery(item.query),
              ),
              onTap: () => onQueryTap(item.query),
            );
          },
        ),
      ],
    );
  }
}

class SearchGenresGrid extends StatelessWidget {
  final Function(String) onGenreTap;
  const SearchGenresGrid({super.key, required this.onGenreTap});

  static final List<Map<String, dynamic>> genres = [
    {'name': 'Acción', 'color': const Color(0xFFEF7A1E), 'icon': Icons.flash_on_rounded},
    {'name': 'Comedia', 'color': const Color(0xFF1A1A1A), 'icon': Icons.sentiment_satisfied_alt_rounded},
    {'name': 'Drama', 'color': const Color(0xFF262626), 'icon': Icons.theater_comedy_rounded},
    {'name': 'Fantasía', 'color': const Color(0xFFEF7A1E), 'icon': Icons.auto_fix_high_rounded},
    {'name': 'Romance', 'color': const Color(0xFF1A1A1A), 'icon': Icons.favorite_rounded},
    {'name': 'Sci-Fi', 'color': const Color(0xFF262626), 'icon': Icons.rocket_launch_rounded},
    {'name': 'Terror', 'color': const Color(0xFFEF7A1E), 'icon': Icons.psychology_alt_rounded},
    {'name': 'Aventura', 'color': const Color(0xFF1A1A1A), 'icon': Icons.explore_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isDesktop = MediaQuery.sizeOf(context).width >= 1200;

    int crossAxisCount = isMobile ? 2 : (isDesktop ? 4 : 3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text('Explorar géneros',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: isDesktop ? 2.8 : 2.5,
          ),
          itemCount: genres.length,
          itemBuilder: (context, index) {
            final genre = genres[index];
            return _GenreCard(
              name: genre['name'] as String,
              color: genre['color'] as Color,
              icon: genre['icon'] as IconData,
              onTap: () => onGenreTap(genre['name'] as String),
            );
          },
        ),
      ],
    );
  }
}

class _GenreCard extends StatefulWidget {
  final String name;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _GenreCard({
    required this.name,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_GenreCard> createState() => _GenreCardState();
}

class _GenreCardState extends State<_GenreCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isHovered ? Colors.white24 : Colors.white.withValues(alpha: 0.05),
                width: 1.2,
              ),
              boxShadow: _isHovered ? [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ] : [],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -5,
                  bottom: -5,
                  child: Icon(
                    widget.icon,
                    size: 48,
                    color: Colors.white.withValues(alpha: _isHovered ? 0.35 : 0.25),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Text(
                      widget.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
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
}

class SearchDiscoveryFeed extends ConsumerWidget {
  final String category;
  final Function(SearchResult) onContentTap;

  const SearchDiscoveryFeed({
    super.key,
    required this.category,
    required this.onContentTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discoveryAsync = ref.watch(searchDiscoveryProvider(category));

    return discoveryAsync.when(
      data: (charts) {
        if (charts.isEmpty) return const SizedBox.shrink();

        return Column(
          children: charts.map((chart) => _ChartRow(
            chart: chart,
            onTap: onContentTap,
          )).toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: Color(0xFFEF7A1E))),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _ChartRow extends StatefulWidget {
  final SearchChart chart;
  final Function(SearchResult) onTap;

  const _ChartRow({required this.chart, required this.onTap});

  @override
  State<_ChartRow> createState() => _ChartRowState();
}

class _ChartRowState extends State<_ChartRow> {
  final ScrollController _scrollController = ScrollController();
  bool _isHovered = false;
  bool _showLeft = false;
  bool _showRight = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateArrows);
  }

  void _updateArrows() {
    if (!mounted || !_scrollController.hasClients) return;
    final left = _scrollController.offset > 20;
    final right = _scrollController.offset < _scrollController.position.maxScrollExtent - 20;
    if (left != _showLeft || right != _showRight) {
      setState(() { _showLeft = left; _showRight = right; });
    }
  }

  void _scroll(bool right) {
    final offset = right ? 800.0 : -800.0;
    _scrollController.animateTo(
      (_scrollController.offset + offset).clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutQuart,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final double posterHeight = isMobile ? 180 : 220;
    final double itemWidth = widget.chart.isTop10 ? posterHeight * 1.1 : posterHeight * 0.7;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(isMobile ? 16 : 32, 40, 16, 16),
            child: Text(
              widget.chart.title,
              style: TextStyle(
                fontSize: isMobile ? 22 : 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.6,
              ),
            ),
          ),
          SizedBox(
            height: posterHeight + 30,
            child: Stack(
              children: [
                ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: widget.chart.items.length,
                  itemBuilder: (context, index) {
                    final item = widget.chart.items[index];

                    if (widget.chart.isTop10) {
                      return _TrendingPosterCard(
                        index: index,
                        item: item,
                        height: posterHeight,
                        width: itemWidth,
                        onTap: () => widget.onTap(item),
                      );
                    }

                    return _StandardDiscoveryCard(
                      item: item,
                      width: itemWidth,
                      height: posterHeight,
                      onTap: () => widget.onTap(item),
                    );
                  },
                ),
                if (!isMobile) ...[
                  _buildArrow(false),
                  _buildArrow(true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArrow(bool isRight) {
    final bool isVisible = isRight ? _showRight : _showLeft;
    return Positioned(
      left: isRight ? null : 0,
      right: isRight ? 0 : null,
      top: 0, bottom: 30,
      child: AnimatedOpacity(
        opacity: (_isHovered && isVisible) ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: IgnorePointer(
          ignoring: !(_isHovered && isVisible),
          child: Container(
            width: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: isRight ? Alignment.centerLeft : Alignment.centerRight,
                end: isRight ? Alignment.centerRight : Alignment.centerLeft,
                colors: [Colors.black.withOpacity(0), Colors.black.withOpacity(0.8)],
              ),
            ),
            child: Center(
              child: NavArrow(
                icon: isRight ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded,
                useBackground: true,
                onTap: () => _scroll(isRight),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StandardDiscoveryCard extends StatefulWidget {
  final SearchResult item;
  final double width;
  final double height;
  final VoidCallback onTap;

  const _StandardDiscoveryCard({
    required this.item,
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  State<_StandardDiscoveryCard> createState() => _StandardDiscoveryCardState();
}

class _StandardDiscoveryCardState extends State<_StandardDiscoveryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: Container(
            width: widget.width,
            margin: const EdgeInsets.only(right: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isHovered ? Colors.white70 : Colors.white10,
                        width: _isHovered ? 2.0 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(_isHovered ? 0.6 : 0.4),
                          blurRadius: _isHovered ? 20 : 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: ApiEndpoints.proxyImage(widget.item.thumbnail, fallbackUrl: widget.item.tmdbThumbnail),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        filterQuality: FilterQuality.medium,
                        placeholder: (context, url) => Container(color: Colors.white.withOpacity(0.05)),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.white10,
                          child: const Icon(Icons.movie_outlined, color: Colors.white24),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  cleanTitleForDisplay(widget.item.title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _isHovered ? Colors.white : Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SearchTrendingSection extends ConsumerStatefulWidget {
  final Function(SearchResult) onTrendingTap;
  const SearchTrendingSection({super.key, required this.onTrendingTap});

  @override
  ConsumerState<SearchTrendingSection> createState() => _SearchTrendingSectionState();
}

class _SearchTrendingSectionState extends ConsumerState<SearchTrendingSection> {
  final ScrollController _scrollController = ScrollController();
  bool _showLeftArrow = false;
  bool _showRightArrow = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateArrows);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateArrows);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateArrows() {
    if (!mounted || !_scrollController.hasClients) return;
    final bool left = _scrollController.offset > 20;
    final bool right = _scrollController.offset < _scrollController.position.maxScrollExtent - 20;
    
    // Senior Optimization: Solo setState si el estado visual CAMBIA
    if (left != _showLeftArrow || right != _showRightArrow) {
      setState(() {
        _showLeftArrow = left;
        _showRightArrow = right;
      });
    }
  }

  void _scroll(bool right) {
    final double offset = right ? 600 : -600;
    _scrollController.animateTo(
      (_scrollController.offset + offset).clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final trendingAsync = ref.watch(searchTrendingProvider);
    final isMobile = ResponsiveUtils.isMobile(context);
    final double posterHeight = isMobile ? 160 : 220;
    final double itemWidth = posterHeight * 1.1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(32, 32, 16, 16),
          child: Text('Lo más buscado hoy',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        SizedBox(
          height: posterHeight + 20,
          child: trendingAsync.when(
            data: (items) {
              if (items.isEmpty) return const SizedBox.shrink();
              return RepaintBoundary(
                child: Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      scrollDirection: Axis.horizontal,
                      cacheExtent: 600,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _TrendingPosterCard(
                          key: ValueKey('trending_search_${item.url}'),
                          index: index,
                          item: item,
                          height: posterHeight,
                          width: itemWidth,
                          onTap: () => widget.onTrendingTap(item),
                        );
                      },
                    ),
                    
                    if (!isMobile) ...[
                      Positioned(
                        left: 0, top: 0, bottom: 0,
                        child: _buildArrow(false),
                      ),
                      Positioned(
                        right: 0, top: 0, bottom: 0,
                        child: _buildArrow(true),
                      ),
                    ],
                  ],
                ),
              );
            },
            loading: () => SizedBox(
              height: posterHeight + 20,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 5,
                itemBuilder: (context, index) => Container(
                  width: itemWidth,
                  margin: const EdgeInsets.only(right: 20),
                  child: SkeletonContainer(
                    width: itemWidth,
                    height: posterHeight,
                    borderRadius: 8,
                  ),
                ),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildArrow(bool isRight) {
    final bool isVisible = isRight ? _showRightArrow : _showLeftArrow;
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        ignoring: !isVisible,
        child: Container(
          width: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: isRight ? Alignment.centerLeft : Alignment.centerRight,
              end: isRight ? Alignment.centerRight : Alignment.centerLeft,
              colors: [Colors.black.withOpacity(0), Colors.black.withOpacity(0.7)],
            ),
          ),
          child: Center(
            child: IconButton(
              icon: Icon(isRight ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded),
              color: Colors.white,
              iconSize: 32,
              onPressed: () => _scroll(isRight),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendingPosterCard extends StatelessWidget {
  final int index;
  final SearchResult item;
  final double height;
  final double width;
  final VoidCallback onTap;

  const _TrendingPosterCard({
    super.key,
    required this.index,
    required this.item,
    required this.height,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final int number = index + 1;
    final bool isDoubleDigit = number >= 10;
    final bool isNumberOne = number == 1;
    
    // ESCALADO UNIFICADO: El número mide el 90% del póster para que este sea más alto
    final double dynamicNumberSize = isDoubleDigit ? height * 0.8 : height * 0.9;
    final double posterWidth = height * 0.7; 
    
    // SOLAPAMIENTO UNIFICADO AL 22% (Fiel al diseño de Home)
    double numberVisiblePart;
    if (isNumberOne) {
      numberVisiblePart = posterWidth * 0.42; 
    } else if (isDoubleDigit) {
      numberVisiblePart = posterWidth * 0.77;
    } else {
      numberVisiblePart = posterWidth * 0.62;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: numberVisiblePart + posterWidth,
        margin: const EdgeInsets.only(right: 20),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. NÚMERO GIGANTE (Capa Inferior)
            Positioned(
              left: isDoubleDigit ? 4 : 0,
              bottom: 0, 
              child: Stack(
                children: [
                  Text(
                    '$number',
                    style: TextStyle(
                      fontSize: dynamicNumberSize,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      letterSpacing: isDoubleDigit ? -15 : -15,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = height * 0.045
                        ..strokeJoin = StrokeJoin.round
                        ..strokeCap = StrokeCap.round
                        ..color = const Color(0xFF9E9E9E),
                    ),
                  ),
                  Stack(
                    children: [
                      Text(
                        '$number',
                        style: TextStyle(
                          fontSize: dynamicNumberSize,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          letterSpacing: isDoubleDigit ? -15 : -15,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = height * 0.02
                            ..strokeJoin = StrokeJoin.round
                            ..strokeCap = StrokeCap.round
                            ..color = const Color(0xFF050505),
                        ),
                      ),
                      Text(
                        '$number',
                        style: TextStyle(
                          fontSize: dynamicNumberSize,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          letterSpacing: isDoubleDigit ? -15 : -15,
                          color: const Color(0xFF050505),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 2. PÓSTER (Capa Superior)
            Positioned(
              left: numberVisiblePart,
              top: 0,
              bottom: 0,
              child: Container(
                width: posterWidth,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.9),
                      blurRadius: 18,
                      spreadRadius: 3,
                      offset: const Offset(-8, 0),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(
                    imageUrl: ApiEndpoints.proxyImage(item.thumbnail),
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.low, // Senior: Rendimiento Web
                    placeholder: (context, url) => Container(color: Colors.white.withOpacity(0.05)),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.white10,
                      child: const Icon(Icons.movie_outlined, color: Colors.white24),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
