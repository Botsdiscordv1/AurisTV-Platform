import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auris_core.dart';

/// Proveedor de Estado para gestionar la acumulación de páginas y scroll infinito.
class SectionExplorerNotifier extends StateNotifier<AsyncValue<List<MediaItem>>> {
  final Ref ref;
  final FilterParams baseParams;
  final SectionSeeMore? verMasSource;
  
  final List<MediaItem> _accumulatedItems = [];
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  // Senior Fix: Mantenemos una caché estática de los barajados iniciales por sección
  // para que si el usuario entra y sale de la misma pantalla, el orden sea estable.
  static final Map<String, List<MediaItem>> _stableInitialShuffle = {};

  SectionExplorerNotifier({
    required this.ref,
    required this.baseParams,
    required String sectionTitle,
    this.verMasSource,
    List<MediaItem>? initialItems,
  }) : super(_getInitialState(sectionTitle, initialItems)) {
    
    // 1. Recuperar o generar el shuffle estable inicial
    if (initialItems != null && initialItems.isNotEmpty) {
      if (!_stableInitialShuffle.containsKey(sectionTitle)) {
        _stableInitialShuffle[sectionTitle] = List<MediaItem>.from(initialItems)..shuffle();
      }
      _accumulatedItems.addAll(_stableInitialShuffle[sectionTitle]!);
    }

    // 2. Determinar la página inicial basada en la respuesta del servidor
    if (verMasSource != null) {
      _currentPage = (verMasSource!.params['page'] as num?)?.toInt() ?? 2;
    } else {
      _currentPage = baseParams.page;
    }
    _loadInitialPage();
  }

  static AsyncValue<List<MediaItem>> _getInitialState(String title, List<MediaItem>? initial) {
    if (initial == null || initial.isEmpty) return const AsyncValue.loading();
    
    // Si ya tenemos un shuffle en caché para este título, lo usamos de inmediato
    if (_stableInitialShuffle.containsKey(title)) {
      return AsyncValue.data(List.unmodifiable(_stableInitialShuffle[title]!));
    }
    
    // Si es la primera vez, generamos uno nuevo
    final shuffled = List<MediaItem>.from(initial)..shuffle();
    _stableInitialShuffle[title] = shuffled;
    return AsyncValue.data(List.unmodifiable(shuffled));
  }

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  Future<void> _loadInitialPage() async {
    try {
      // Intentar cargar la página que pide el servidor
      final results = await ref.read(filterResultsProvider(baseParams).future);
      
      _appendUniqueItems(results);
      if (results.isEmpty) {
        _hasMore = false;
      } else {
        // Senior Fix: Si cargamos con éxito la página inicial (ej: 2),
        // la siguiente petición de scroll infinito DEBE ser la 3.
        _currentPage++;
      }
      state = AsyncValue.data(List.unmodifiable(_accumulatedItems));
    } catch (e, stack) {
      // Si ya tenemos items (shuffled), no mostramos error total, solo logeamos
      if (_accumulatedItems.isNotEmpty) {
        debugPrint('[SectionExplorer] Error initial fetch: $e');
        state = AsyncValue.data(List.unmodifiable(_accumulatedItems));
      } else {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  void _appendUniqueItems(List<MediaItem> newItems) {
    for (final item in newItems) {
      if (!_accumulatedItems.any((existing) => existing.id == item.id)) {
        _accumulatedItems.add(item);
      }
    }
  }

  Future<void> loadNextPage() async {
    if (_isLoadingMore || !_hasMore) return;
    
    _isLoadingMore = true;
    // Forzamos rebuild para mostrar el loader inferior si es necesario
    state = AsyncValue.data(List.unmodifiable(_accumulatedItems)); 

    try {
      FilterParams nextParams;
      
      if (verMasSource != null) {
        // Explotación Máxima del Servidor 3001: Seguimos el link directo incrementando la página
        nextParams = FilterParams.fromSeeMore(verMasSource!, overridePage: _currentPage);
      } else {
        // Fallback para Servidores 3000/3002: Re-construcción local de filtros
        nextParams = FilterParams(
          genre: baseParams.genre,
          year: baseParams.year,
          category: baseParams.category,
          source: baseParams.source,
          status: baseParams.status,
          idioma: baseParams.idioma,
          page: _currentPage,
        );
      }

      debugPrint('[SectionExplorer] Cargando página $_currentPage para endpoint de filtros...');
      final results = await ref.read(filterResultsProvider(nextParams).future);

      if (results.isEmpty) {
        _hasMore = false;
      } else {
        _appendUniqueItems(results);
        _currentPage++;
      }
      
      if (mounted) {
        state = AsyncValue.data(List.unmodifiable(_accumulatedItems));
      }
    } catch (e) {
      debugPrint('[SectionExplorer] Error cargando página $_currentPage: $e');
      _hasMore = false; 
    } finally {
      _isLoadingMore = false;
    }
  }
}

class SectionExplorerArgs {
  final String title;
  final FilterParams baseParams;
  final SectionSeeMore? verMas;
  final List<MediaItem>? initialItems;
  final void Function(MediaItem)? onItemTap;

  const SectionExplorerArgs({
    required this.title,
    required this.baseParams,
    this.verMas,
    this.initialItems,
    this.onItemTap,
  });
}

/// Auto-dispose provider dinámico por familia de argumentos.
final sectionExplorerStateProvider = StateNotifierProvider.autoDispose.family<SectionExplorerNotifier, AsyncValue<List<MediaItem>>, SectionExplorerArgs>((ref, args) {
  return SectionExplorerNotifier(
    ref: ref, 
    baseParams: args.baseParams, 
    sectionTitle: args.title,
    verMasSource: args.verMas,
    initialItems: args.initialItems,
  );
});

/// Vista de producción responsiva para desplegar el Catálogo Infinito.
class SectionGridExplorer extends ConsumerStatefulWidget {
  final SectionExplorerArgs args;

  const SectionGridExplorer({Key? key, required this.args}) : super(key: key);

  @override
  ConsumerState<SectionGridExplorer> createState() => _SectionGridExplorerState();
}

class _SectionGridExplorerState extends ConsumerState<SectionGridExplorer> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    // Senior Threshold: Disparar el fetch 300px antes de llegar abajo para que la UX sea invisible
    if (maxScroll - currentScroll <= 300) {
      ref.read(sectionExplorerStateProvider(widget.args).notifier).loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sectionExplorerStateProvider(widget.args));
    final notifier = ref.read(sectionExplorerStateProvider(widget.args).notifier);
    
    final isMobile = ResponsiveUtils.isMobile(context);
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Senior Search Grid Strategy: Unificación milimétrica con el motor de búsqueda
    int crossAxisCount = 3;
    if (!isMobile) {
      if (screenWidth > 1800) {
        crossAxisCount = 8;
      } else if (screenWidth > 1400) {
        crossAxisCount = 7;
      } else if (screenWidth > 1000) {
        crossAxisCount = 6;
      } else {
        crossAxisCount = 5;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D), // Fondo unificado con search
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.args.title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: ResponsiveUtils.rowTitleFontSize(context), // Prominente pero unificado
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2, // Misma separación que en portadas
          ),
        ),
        elevation: 0,
        backgroundColor: const Color(0xFF0B0B0D),
        surfaceTintColor: Colors.transparent,
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFEF7A1E))),
        error: (err, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'No pudimos recuperar el catálogo completo.\nError: $err',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No hay elementos disponibles en esta sección.'));
          }

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 16 : 24, 
                  8, 
                  isMobile ? 16 : 24, 
                  40
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: isMobile ? 0.54 : 0.58, // Senior: Aspect ratio idéntico a search
                    crossAxisSpacing: isMobile ? 12 : 20, 
                    mainAxisSpacing: isMobile ? 12 : 16, 
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = items[index];
                      return _GridItemCard(
                        item: item, 
                        index: index,
                        sessionKey: widget.args.title, // Senior: Clave para el tracker de animaciones
                        onTap: widget.args.onItemTap,
                      );
                    },
                    childCount: items.length,
                  ),
                ),
              ),
              if (notifier.hasMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(child: CircularProgressIndicator.adaptive()),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _GridItemCard extends StatefulWidget {
  final MediaItem item;
  final int index;
  final String sessionKey;
  final void Function(MediaItem)? onTap;

  const _GridItemCard({
    required this.item, 
    required this.index,
    required this.sessionKey,
    this.onTap,
  });

  @override
  State<_GridItemCard> createState() => _GridItemCardState();
}

class _GridItemCardState extends State<_GridItemCard> with SingleTickerProviderStateMixin {
  late AnimationController _appearController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Senior State Tracking: Mantenemos registro de qué posters ya se animaron en este scroll
  static final Set<String> _animatedPosterIds = {};
  static String _activeSessionKey = '';

  @override
  void initState() {
    super.initState();

    // Resetear el set si cambiamos de sección para permitir nuevas animaciones
    if (_activeSessionKey != widget.sessionKey) {
      _animatedPosterIds.clear();
      _activeSessionKey = widget.sessionKey;
    }

    final bool alreadyAnimated = _animatedPosterIds.contains(widget.item.id);

    _appearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      // Senior Fix: Si ya se animó, forzamos estado final (1.0) para evitar que desaparezca al hacer scroll-up
      value: alreadyAnimated ? 1.0 : 0.0,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _appearController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _appearController,
      curve: Curves.easeOutCubic,
    ));

    if (!alreadyAnimated) {
      _animatedPosterIds.add(widget.item.id);
      // Senior Optimization: Staggered animation based on grid index
      final delay = Duration(milliseconds: (widget.index % 12) * 50);
      Future.delayed(delay, () {
        if (mounted) _appearController.forward();
      });
    }
  }

  @override
  void dispose() {
    _appearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Consumer(
          builder: (context, ref, _) {
            // Senior Fix: Escuchamos el historial de reproducción para inyectar la barra de progreso en tiempo real
            final historyAsync = ref.watch(playbackHistoryStateProvider);
            final latestWatched = historyAsync.when(
              data: (list) => list.cast<PlaybackHistory?>().firstWhere(
                (h) => h?.contentId == widget.item.id, 
                orElse: () => null
              ),
              loading: () => null,
              error: (_, __) => null,
            );

            return FocusablePosterCard(
              key: ValueKey('explorer_${widget.item.id}'),
              title: widget.item.title,
              posterUrl: widget.item.posterUrl,
              rating: formatRating(widget.item.rating),
              progress: latestWatched?.progress, // Senior Fix: Inyectamos progreso dinámico
              showInfo: true,
              onTap: () {
                if (widget.onTap != null) {
                  widget.onTap!(widget.item);
                }
              },
            );
          },
        ),
      ),
    );
  }

  MediaItem get item => widget.item;
}
