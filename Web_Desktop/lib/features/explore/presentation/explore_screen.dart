import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';
import 'package:auris_core/auris_core.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/utils/url_utils.dart';
import '../../../shared/widgets/airing_countdown_badge.dart';
import '../../../shared/widgets/focusable_poster_card.dart';
import '../../schedule/presentation/schedule_screen.dart';

final _exploreFilterProvider = StateProvider<String>((ref) => 'En Emisión');
final _exploreSearchQueryProvider = StateProvider<String>((ref) => '');

enum ExploreSort { recent, oldest, nameAZ, nameZA }

final _exploreSortProvider = StateProvider<ExploreSort>((ref) => ExploreSort.recent);

final _exploreContentProvider = FutureProvider<List<MediaItem>>((ref) async {
  final filter = ref.watch(_exploreFilterProvider);
  final query = ref.watch(_exploreSearchQueryProvider).toLowerCase();
  final sort = ref.watch(_exploreSortProvider);

  if (filter == 'Calendario') return [];

  List<MediaItem> results = [];

  // Obtenemos la lista base según el filtro (Sin llamar a búsqueda completa de API)
  if (filter == 'En Emisión') {
    // Para "En Emisión" buscamos en TODO el calendario semanal disponible
    final schedule = await ref.watch(scheduleProvider.future);
    results = schedule.days.expand((d) => d.items).where((item) => item.sourceAvailable).map((item) {
      final ep = item.episode ?? 0;
      final isMovie = item.format?.toUpperCase() == 'MOVIE';
      return MediaItem(
        id: item.id.toString(),
        title: item.title,
        romaji: item.romaji,
        english: item.english,
        posterUrl: ApiEndpoints.proxyImage(item.coverImage),
        bannerUrl: item.banner != null ? ApiEndpoints.proxyImage(item.banner!) : null,
        type: isMovie ? MediaType.movie : MediaType.anime,
        rating: item.averageScore,
        subtitle: (isMovie || ep == 0) ? null : 'Episodio $ep',
        source: '',
        episode: ep == 0 ? null : ep,
        airingAt: item.airingAt,
        year: item.year,
        aired: isMovie || item.aired || item.status?.toLowerCase() == 'finished',
      );
    }).toList();
  } else if (filter == 'Animes') {
    final list = await ref.watch(trendingListProvider('animes').future);
    results = List.from(list);
  } else if (filter == 'Mas vistos') {
    final list = await ref.watch(trendingListProvider('animes').future);
    results = List.from(list);
    results.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0)); 
  } else if (filter == 'Populares') {
    final list = await ref.watch(trendingListProvider('animes').future);
    results = List.from(list);
  } else if (filter == 'Películas') {
    final list = await ref.watch(trendingListProvider('películas').future);
    results = List.from(list);
  }

  // Filtrado LOCAL: solo sobre lo que el filtro actual ofrece
  if (query.isNotEmpty) {
    results = results.where((item) {
      final t = item.title.toLowerCase();
      final r = item.romaji?.toLowerCase() ?? '';
      final e = item.english?.toLowerCase() ?? '';
      return t.contains(query) || r.contains(query) || e.contains(query);
    }).toList();
  }

  // Aplicar ordenamiento
  switch (sort) {
    case ExploreSort.recent:
      results.sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
      break;
    case ExploreSort.oldest:
      results.sort((a, b) => (a.year ?? 0).compareTo(b.year ?? 0));
      break;
    case ExploreSort.nameAZ:
      results.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      break;
    case ExploreSort.nameZA:
      results.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
      break;
  }

  return results;
});

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = context.isMobile;
    final width = MediaQuery.of(context).size.width;
    final hPadding = isMobile ? 16.0 : (width - 1024).clamp(32.0, double.infinity) / 2;
    final selectedFilter = ref.watch(_exploreFilterProvider);
    final contentAsync = ref.watch(_exploreContentProvider);
    final scheduleAsync = ref.watch(scheduleProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D), // Color de fondo de la app
      body: SafeArea(
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            // Barra superior de filtros
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: hPadding),
                  child: Row(
                    children: [
                      _FilterButton(
                        label: 'En Emisión',
                        isSelected: selectedFilter == 'En Emisión',
                        onTap: () => ref.read(_exploreFilterProvider.notifier).state = 'En Emisión',
                      ),
                      const SizedBox(width: 8),
                      _FilterButton(
                        label: 'Calendario',
                        isSelected: selectedFilter == 'Calendario',
                        onTap: () => ref.read(_exploreFilterProvider.notifier).state = 'Calendario',
                      ),
                      const SizedBox(width: 8),
                      _FilterButton(
                        label: 'Animes',
                        isSelected: selectedFilter == 'Animes',
                        onTap: () => ref.read(_exploreFilterProvider.notifier).state = 'Animes',
                      ),
                      const SizedBox(width: 8),
                      _FilterButton(
                        label: 'Películas',
                        isSelected: selectedFilter == 'Películas',
                        onTap: () => ref.read(_exploreFilterProvider.notifier).state = 'Películas',
                      ),
                      const SizedBox(width: 8),
                      _FilterButton(
                        label: 'Mas vistos',
                        isSelected: selectedFilter == 'Mas vistos',
                        onTap: () => ref.read(_exploreFilterProvider.notifier).state = 'Mas vistos',
                      ),
                      const SizedBox(width: 8),
                      _FilterButton(
                        label: 'Populares',
                        isSelected: selectedFilter == 'Populares',
                        onTap: () => ref.read(_exploreFilterProvider.notifier).state = 'Populares',
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Buscador y botón de filtro (Solo si no es Calendario)
            if (selectedFilter != 'Calendario')
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hPadding, 0, hPadding, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1D23),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            onChanged: (val) => ref.read(_exploreSearchQueryProvider.notifier).state = val,
                            textAlignVertical: TextAlignVertical.center, // Senior Fix: Centrado vertical real
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            decoration: const InputDecoration(
                              isDense: true, // Senior Fix: Mejor centrado
                              hintText: 'Buscar...',
                              hintStyle: TextStyle(color: Colors.white38),
                              prefixIcon: Icon(Icons.search, color: Colors.white38),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero, // Eliminamos padding manual que causa desfase
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Theme(
                        data: Theme.of(context).copyWith(
                          hoverColor: Colors.transparent,
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                        ),
                        child: PopupMenuButton<ExploreSort>(
                          initialValue: ref.watch(_exploreSortProvider),
                          onSelected: (sort) => ref.read(_exploreSortProvider.notifier).state = sort,
                          offset: const Offset(0, 56),
                          color: const Color(0xFF1A1D23),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          itemBuilder: (context) => [
                            _buildPopupItem(context, 'Más recientes', ExploreSort.recent, ref),
                            _buildPopupItem(context, 'Más antiguos', ExploreSort.oldest, ref),
                            _buildPopupItem(context, 'Nombre (A-Z)', ExploreSort.nameAZ, ref),
                            _buildPopupItem(context, 'Nombre (Z-A)', ExploreSort.nameZA, ref),
                          ],
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1D23),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.filter_list, color: Color(0xFFEF7A1E)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Grid de contenido o Calendario
            if (selectedFilter == 'Calendario')
              ...[
                scheduleAsync.when(
                  data: (schedule) => _ScheduleSlivers(schedule: schedule),
                  loading: () => const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => SliverFillRemaining(
                    child: Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white54))),
                  ),
                ),
              ]
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: hPadding),
                sliver: contentAsync.when(
                  data: (items) => SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isMobile ? 3 : 5,
                      mainAxisSpacing: isMobile ? 12 : 24, // Senior Fix: Compactado igual que el calendario
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.55, // Senior Fix: Proporción ajustada para evitar aire muerto
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = items[index];

                        // Senior Fix: Obtener el progreso del historial si existe
                        final historyAsync = ref.watch(playbackHistoryStateProvider);
                        double? progress;
                        historyAsync.whenData((items) {
                          final match = items.firstWhereOrNull((h) => h.contentId == item.id);
                          if (match != null) progress = match.progress;
                        });

                        return FocusablePosterCard(
                          title: item.title,
                          posterUrl: item.posterUrl,
                          badgeOverlay: (item.airingAt != null && selectedFilter != 'En Emisión')
                              ? AiringCountdownBadge(airingAt: item.airingAt!, aired: item.aired)
                              : null,
                          subtitle: item.subtitle,
                          rating: formatRating(item.rating),
                          showInfo: true,
                          progress: progress, // Senior Fix: Mostrar progreso en el grid de explorar
                          onTap: () {
                            final uri = UrlUtils.buildShareableUri(
                              title: item.title,
                              source: item.source,
                              url: item.id,
                              category: item.type.name,
                              year: item.year,
                              type: item.card?.kind ?? item.type.name,
                              from: '/explore',
                            );
                            context.go(uri, extra: item.toContentSeed());
                          },
                        );
                      },
                      childCount: items.length,
                    ),
                  ),
                  loading: () => const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => SliverFillRemaining(
                    child: Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white54))),
                  ),
                ),
              ),
            
            if (selectedFilter != 'Calendario')
              const SliverPadding(padding: EdgeInsets.only(bottom: 24)), // Solo aire al final si es el Grid
          ],
        ),
      ),
    );
  }

  PopupMenuItem<ExploreSort> _buildPopupItem(
    BuildContext context, 
    String label, 
    ExploreSort value, 
    WidgetRef ref
  ) {
    final isSelected = ref.read(_exploreSortProvider) == value;
    return PopupMenuItem<ExploreSort>(
      value: value,
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? const Color(0xFFEF7A1E) : Colors.white,
          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _ScheduleSlivers extends StatelessWidget {
  final ScheduleResponse schedule;
  const _ScheduleSlivers({required this.schedule});

  @override
  Widget build(BuildContext context) {
    final filteredDays = schedule.days.map((day) {
      final filtered = day.items.where((item) => item.sourceAvailable).toList();
      return ScheduleDay(day: day.day, dayIndex: day.dayIndex, isToday: day.isToday, items: filtered);
    }).toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final day = filteredDays[index];
          if (day.items.isEmpty) return const SizedBox.shrink();
          return ScheduleRow(day: day, isToday: day.isToday);
        },
        childCount: filteredDays.length,
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEF7A1E) : const Color(0xFF1A1D23),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}


