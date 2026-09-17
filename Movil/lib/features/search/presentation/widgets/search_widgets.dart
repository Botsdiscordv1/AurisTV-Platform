import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:auris_core/auris_core.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../data/models/search_history.dart';
import '../providers/search_provider.dart';

class SearchCategorySelector extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;

  const SearchCategorySelector({
    super.key,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    final categories = [
      {'id': 'all', 'label': 'Todo'},
      {'id': 'peliculas', 'label': 'Películas'},
      {'id': 'series', 'label': 'Series'},
      {'id': 'anime', 'label': 'Anime'},
    ];

    final double spacing = isMobile ? 8.0 : 12.0;
    final double height = isMobile ? 38.0 : 46.0;
    final double fontSize = isMobile ? 14.0 : 16.0;
    
    final Map<String, double> itemWidths = isMobile ? {
      'all': 65.0,
      'peliculas': 95.0,
      'series': 80.0,
      'anime': 80.0,
    } : {
      'all': 90.0,
      'peliculas': 130.0,
      'series': 110.0,
      'anime': 110.0,
    };

    final activeIndex = categories.indexWhere((c) => c['id'] == selectedCategory);
    
    double leftOffset = 0;
    for (int i = 0; i < activeIndex; i++) {
      leftOffset += itemWidths[categories[i]['id']]! + spacing;
    }

    return SizedBox(
      height: height,
      child: ShaderMask(
        shaderCallback: (Rect rect) {
          return const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Colors.black, Colors.transparent],
            stops: [0.92, 1.0],
          ).createShader(rect);
        },
        blendMode: BlendMode.dstIn,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(right: isMobile ? 32 : 48),
          child: Stack(
            children: [
              // FONDO DESLIZANTE (PÍLDORA)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                left: leftOffset,
                child: Container(
                  width: itemWidths[selectedCategory],
                  height: height,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(height / 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              
              // ITEMS DE TEXTO
              Row(
                mainAxisSize: MainAxisSize.min,
                children: categories.map((cat) {
                  final isSelected = cat['id'] == selectedCategory;
                  return Padding(
                    padding: EdgeInsets.only(right: spacing),
                    child: GestureDetector(
                      onTap: () => onCategoryChanged(cat['id']!),
                      child: Container(
                        width: itemWidths[cat['id']],
                        height: height,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(height / 2),
                        ),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 250),
                          style: GoogleFonts.poppins(
                            color: isSelected ? Colors.black : Colors.white70,
                            fontSize: fontSize,
                            fontWeight: FontWeight.w700,
                          ),
                          child: Text(cat['label']!),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
          padding: EdgeInsets.zero,
          itemCount: history.length,
          itemBuilder: (context, index) {
            final item = history[index];
            return ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: const Icon(Icons.history_rounded, color: Color(0xFFEF7A1E), size: 20),
              title: Text(
                item.query, 
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 15)
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white24, size: 18),
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
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
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
            return InkWell(
              onTap: () => onGenreTap(genre['name'] as String),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  color: genre['color'] as Color,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -5,
                      bottom: -5,
                      child: Icon(genre['icon'] as IconData, size: 48, color: Colors.white.withOpacity(0.12)),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16.0),
                        child: Text(
                          genre['name'] as String,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
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
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: Color(0xFFEF7A1E))),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _ChartRow extends StatelessWidget {
  final SearchChart chart;
  final Function(SearchResult) onTap;

  const _ChartRow({required this.chart, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final double posterHeight = isMobile ? (chart.isTop10 ? 160 : 180) : 220;
    final double itemWidth = chart.isTop10 ? posterHeight * 1.1 : posterHeight * 0.7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            chart.title,
            style: TextStyle(
              fontSize: isMobile ? 20 : 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
        SizedBox(
          height: posterHeight + (chart.isTop10 ? 20 : 10),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: chart.items.length,
            itemBuilder: (context, index) {
              final item = chart.items[index];

              if (chart.isTop10) {
                return _TrendingPosterCard(
                  index: index,
                  item: item,
                  height: posterHeight,
                  width: itemWidth,
                  onTap: () => onTap(item),
                );
              }

              return GestureDetector(
                onTap: () => onTap(item),
                child: Container(
                  width: itemWidth,
                  margin: const EdgeInsets.only(right: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: ApiEndpoints.proxyImage(item.thumbnail, fallbackUrl: item.tmdbThumbnail),
                              fit: BoxFit.cover,
                              width: double.infinity,
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
            },
          ),
        ),
      ],
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
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text('Lo más buscado hoy',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        SizedBox(
          height: posterHeight + 20,
          child: trendingAsync.when(
            data: (items) {
              if (items.isEmpty) return const SizedBox.shrink();
              return Stack(
                children: [
                  ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      return _TrendingPosterCard(
                        index: index,
                        item: items[index],
                        height: posterHeight,
                        width: itemWidth,
                        onTap: () => widget.onTrendingTap(items[index]),
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
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFEF7A1E))),
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
                    imageUrl: ApiEndpoints.proxyImage(item.thumbnail, fallbackUrl: item.tmdbThumbnail),
                    fit: BoxFit.cover,
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
