import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/url_utils.dart';
import '../../../core/utils/responsive_utils.dart';
import 'package:auristv_web/core/router/app_router.dart';
import 'package:auris_core/auris_core.dart';
import '../../../shared/widgets/airing_countdown_badge.dart';
import '../../../shared/widgets/focusable_poster_card.dart';

final _scheduleProvider = FutureProvider<ScheduleResponse>((ref) async {
  final repo = ref.watch(aurisRepositoryProvider);
  return repo.getSchedule();
});

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  @override
  Widget build(BuildContext context) {
    final scheduleAsync = ref.watch(_scheduleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario'),
        backgroundColor: const Color(0xFF0B0B0D),
        surfaceTintColor: Colors.transparent,
      ),
      body: scheduleAsync.when(
        data: (schedule) => _ScheduleBody(schedule: schedule),
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFEF7A1E))),
        error: (err, _) => Center(
          child: Text('Error: $err',
              style: const TextStyle(color: Colors.white54)),
        ),
      ),
    );
  }
}

class _ScheduleBody extends StatelessWidget {
  final ScheduleResponse schedule;

  const _ScheduleBody({required this.schedule});

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final hPadding = ResponsiveUtils.horizontalPadding(context);

    // Crear días filtrados: solo items disponibles en fuentes
    final filteredDays = schedule.days.map((day) {
      final filtered = day.items.where((item) => item.sourceAvailable).toList();
      return ScheduleDay(day: day.day, dayIndex: day.dayIndex, isToday: day.isToday, items: filtered);
    }).toList();

    // Calcular el total real sumando los items de cada día
    final actualTotal = filteredDays.fold<int>(0, (sum, day) => sum + day.items.length);
    
    // Título dinámico
    final String displayTitle = (schedule.season.isEmpty || schedule.year == 0)
        ? 'ESTRENOS DE LA SEMANA'
        : '${schedule.season} ${schedule.year}';

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          // Encabezado estilizado
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPadding, 40, hPadding, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        displayTitle.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 20 : 36,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(width: 24),
                      if (!isMobile) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Text(
                              '$actualTotal series en emisión',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: _LocalTimeWidget(),
                        ),
                      ],
                    ],
                  ),
                  if (isMobile) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          '$actualTotal series en emisión',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        const _LocalTimeWidget(),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    width: 60,
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF7A1E),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Filas de carruseles
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final day = filteredDays[index];
                return ScheduleRow(day: day, isToday: day.isToday);
              },
              childCount: filteredDays.length,
            ),
          ),
          
          const SliverPadding(padding: EdgeInsets.only(bottom: 12)),
        ],
      ),
    );
  }
}

class ScheduleRow extends StatefulWidget {
  final ScheduleDay day;
  final bool isToday;

  const ScheduleRow({super.key, required this.day, required this.isToday});

  @override
  State<ScheduleRow> createState() => _ScheduleRowState();
}

class _ScheduleRowState extends State<ScheduleRow> {
  final ScrollController _scrollController = ScrollController();
  bool _isHovered = false;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollIndicators());
  }

  @override
  void didUpdateWidget(covariant ScheduleRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.day.items.length != oldWidget.day.items.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollIndicators());
    }
  }

  void _updateScrollIndicators() {
    if (!mounted || !_scrollController.hasClients) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    
    final canLeft = currentScroll > 5;
    final canRight = maxScroll > currentScroll + 5;
    
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  void _scroll(double offset) {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentOffset = _scrollController.offset;
    final target = (currentOffset + offset).clamp(0.0, maxScroll);

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutQuart,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.day.items.isEmpty) return const SizedBox.shrink();
    final isMobile = ResponsiveUtils.isMobile(context);
    final hPadding = ResponsiveUtils.horizontalPadding(context);

    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 12 : 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPadding),
            child: Row(
              children: [
                Text(
                  widget.day.day.toUpperCase(),
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 22,
                    fontWeight: FontWeight.w900,
                    color: widget.isToday ? Colors.white : Colors.white38,
                    letterSpacing: 1.2,
                  ),
                ),
                if (widget.isToday) ...[
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.circle, color: Colors.redAccent, size: 8),
                        SizedBox(width: 8),
                        Text(
                          'HOY',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: isMobile ? 8 : 24),
          MouseRegion(
            onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _isHovered = true); }),
            onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _isHovered = false); }),
            child: Stack(
              children: [
                SizedBox(
                  height: isMobile ? ResponsiveUtils.sp(context, 220) : 380, // Senior Fix: Ajustado para ancho de 125
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      _updateScrollIndicators();
                      return false;
                    },
                    child: ListView.separated(
                      controller: _scrollController,
                      physics: const ClampingScrollPhysics(),
                      cacheExtent: 500,
                      clipBehavior: Clip.none,
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(
                        horizontal: hPadding, 
                        vertical: 0
                      ),
                      itemCount: widget.day.items.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final item = widget.day.items[index];
                        final metaTitle = item.romaji ?? item.english ?? item.title;
                        final itemYear = item.year ?? (item.airingAt != null ? DateTime.fromMillisecondsSinceEpoch(item.airingAt! * 1000).year : null);
                        return SizedBox(
                          width: isMobile ? ResponsiveUtils.sp(context, 125) : 200,
                          child: FocusablePosterCard(
                            title: item.title,
                            posterUrl: ApiEndpoints.proxyImage(item.coverImage),
                            badgeOverlay: item.airingAt != null
                                ? AiringCountdownBadge(airingAt: item.airingAt!, aired: item.aired)
                                : null,
                            subtitle: _buildSubtitle(item),
                            rating: formatRating(item.averageScore),
                            onTap: () {
                              final uri = UrlUtils.buildShareableUri(
                                title: item.title,
                                source: item.source ?? '',
                                url: item.url ?? '',
                                category: 'anime',
                                year: itemYear,
                                quality: item.quality,
                                type: item.type,
                                from: '/horario',
                              );
                              
                              context.push(uri, extra: SearchResult(
                                title: item.title,
                                source: item.source ?? '',
                                url: item.url ?? '',
                                thumbnail: ApiEndpoints.proxyImage(item.coverImage),
                                quality: item.quality ?? 'HD',
                                kind: 'anime',
                                type: item.type,
                                slug: item.slug,
                                year: itemYear,
                                sources: item.sources.map((s) => SourceItem(
                                  source: s.source,
                                  url: s.url,
                                  quality: s.quality,
                                  slug: s.slug,
                                  type: s.type,
                                )).toList(),
                              ));
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Flecha Izquierda (Centrada respecto al póster)
                Positioned(
                  left: 0,
                  top: 0,
                  height: isMobile ? 210 : 300, // Sincronizado con el alto del póster (ancho * 1.5)
                  child: AnimatedOpacity(
                    opacity: (_isHovered && _canScrollLeft) ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: IgnorePointer(
                      ignoring: !(_isHovered && _canScrollLeft),
                      child: Center(
                        child: NavArrow(
                          icon: Icons.arrow_back_ios_new,
                          useBackground: true,
                          enableScale: false,
                          onTap: () => _scroll(-600),
                        ),
                      ),
                    ),
                  ),
                ),

                // Flecha Derecha (Centrada respecto al póster)
                Positioned(
                  right: 0,
                  top: 0,
                  height: isMobile ? 210 : 300, // Sincronizado con el alto del póster
                  child: AnimatedOpacity(
                    opacity: (_isHovered && _canScrollRight) ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: IgnorePointer(
                      ignoring: !(_isHovered && _canScrollRight),
                      child: Center(
                        child: NavArrow(
                          icon: Icons.arrow_forward_ios,
                          useBackground: true,
                          enableScale: false,
                          onTap: () => _scroll(600),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String? _buildSubtitle(ScheduleItem item) {
  final ep = (item.episode ?? 0) > 0 ? 'Episodio ${item.episode}' : null;
  if (ep != null) return ep;
  return item.format;
}

class _LocalTimeWidget extends StatefulWidget {
  const _LocalTimeWidget();

  @override
  State<_LocalTimeWidget> createState() => _LocalTimeWidgetState();
}

class _LocalTimeWidgetState extends State<_LocalTimeWidget> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String timeStr = 
        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.access_time, color: Color(0xFFEF7A1E), size: 14),
          const SizedBox(width: 8),
          const Text(
            'HORA LOCAL: ',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            timeStr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
