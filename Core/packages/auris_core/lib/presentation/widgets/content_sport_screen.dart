import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auris_core.dart';

/// Pantalla dedicada `content_sport` para eventos deportivos en vivo y próximos.
/// Muestra los detalles completos del evento (liga, equipos, sinopsis, estado en vivo)
/// y un selector directo de canales de transmisión (`channels`).
///
/// Al abrirse busca el detalle del evento (`/es/ver/<id>` en la fuente lacancha)
/// para sustituir los canales marcadores por los servidores reales (`embed_url`).
/// Al tocar un servidor delega la reproducción en el [sportsChannelLauncherProvider]
/// que cada app inyecta (resolvedor m3u8 → media_kit en Android; embed en Web).
class ContentSportScreen extends ConsumerStatefulWidget {
  final ContentSports event;
  final ValueChanged<Map<String, dynamic>>? onChannelSelected;
  final VoidCallback? onBackPressed;

  const ContentSportScreen({
    super.key,
    required this.event,
    this.onChannelSelected,
    this.onBackPressed,
  });

  @override
  ConsumerState<ContentSportScreen> createState() => _ContentSportScreenState();
}

class _ContentSportScreenState extends ConsumerState<ContentSportScreen> {
  late ContentSports _event;
  bool _loadingDetail = true;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _loadDetail();
  }

  /// Busca los servidores reales del evento y los fusiona con la metadata del
  /// catálogo (thumbnail, colores, viewers) que el detalle no trae.
  Future<void> _loadDetail() async {
    final id = widget.event.id;
    // Solo la fuente lacancha tiene endpoint de detalle; los eventos del
    // backend 3003 ya traen canales con `url` directa y no deben fetchear.
    final looksLikeLacancha = widget.event.channels.isEmpty ||
        widget.event.channels.any((c) =>
            (c['embed_url']?.toString() ?? '').isNotEmpty ||
            (c['url']?.toString() ?? '').isEmpty);
    if (!looksLikeLacancha) {
      setState(() => _loadingDetail = false);
      return;
    }

    final source = ref.read(lacanchaEventsSourceProvider);
    final detail = await source.fetchEventDetail(id);
    if (!mounted || detail == null) {
      if (mounted) setState(() => _loadingDetail = false);
      return;
    }

    setState(() {
      _event = ContentSports(
        id: widget.event.id,
        title: detail.title.isNotEmpty ? detail.title : widget.event.title,
        sport: widget.event.sport,
        sportLabel: widget.event.sportLabel ?? detail.sportLabel,
        league: detail.league ?? widget.event.league,
        leagueLogo: widget.event.leagueLogo,
        teams: detail.teams.isNotEmpty ? detail.teams : widget.event.teams,
        channels: detail.channels,
        posterUrl: widget.event.posterUrl.isNotEmpty
            ? widget.event.posterUrl
            : detail.posterUrl,
        bannerUrl: widget.event.bannerUrl.isNotEmpty
            ? widget.event.bannerUrl
            : detail.bannerUrl,
        colors: widget.event.colors,
        synopsis: widget.event.synopsis,
        viewers: widget.event.viewers,
        startsAtMs: widget.event.startsAtMs,
        startsAt: detail.startsAt ?? widget.event.startsAt,
        endsAtMs: widget.event.endsAtMs,
        isLive: detail.isLive || widget.event.isLive,
        alwaysLive: widget.event.alwaysLive,
        status: detail.isLive ? 'EN VIVO' : widget.event.status,
        source: 'ppv',
      );
      _loadingDetail = false;
    });
  }

  void _onChannelTap(Map<String, dynamic> channel) {
    debugPrint('[ContentSportScreen] canal: ${channel['name']} '
        '(${channel['url'] ?? channel['embed_url']})');
    if (widget.onChannelSelected != null) {
      widget.onChannelSelected!(channel);
      return;
    }
    // Delega en el lanzador que la app inyectó (go_router + resolvedor).
    ref.read(sportsChannelLauncherProvider)(context, _event, channel);
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    debugPrint('[ContentSportScreen] OPENED successfully -> Title: "${event.title}", ID: ${event.id}, League: ${event.league}, Channels count: ${event.channels.length}');
    // El BACKEND calcula el estado real: usar event.isLive/status, no recalcular.
    final isLive = event.effectiveIsLive;
    final statusLabel = event.statusLabel;

    return Scaffold(
      backgroundColor: const Color(0xFF121216),
      body: CustomScrollView(
        slivers: [
          // Header con Backdrop / Banner
          SliverAppBar(
            expandedHeight: 300.0,
            pinned: true,
            backgroundColor: const Color(0xFF18181C),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: widget.onBackPressed ?? () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CuredNetworkImage(
                    imageUrl: event.bannerUrl.isNotEmpty ? event.bannerUrl : event.posterUrl,
                    fit: BoxFit.cover,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          const Color(0xFF121216).withValues(alpha: 0.9),
                          const Color(0xFF121216),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Información y Canales del Evento
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges y Liga
                  Row(
                    children: [
                      if (isLive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
                              SizedBox(width: 6),
                              Text(
                                'EN VIVO',
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )
                      else if (statusLabel == 'FINALIZADO')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'FINALIZADO',
                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      if (event.sportLabel != null) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            event.sportLabel!,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (event.league != null)
                        Text(
                          event.league!,
                          style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Título del Evento
                  Text(
                    event.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (event.teams.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      event.teams.join(' vs '),
                      style: const TextStyle(color: Color(0xFFEF7A1E), fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ],
                  if (event.synopsis != null && event.synopsis!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      event.synopsis!,
                      style: const TextStyle(color: Colors.white60, fontSize: 14, height: 1.5),
                    ),
                  ],
                  const SizedBox(height: 32),
                  // Sección de Canales de Transmisión
                  const Text(
                    'Canales de Transmisión',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_loadingDetail && event.channels.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(
                        child: CircularProgressIndicator(color: Color(0xFFEF7A1E)),
                      ),
                    )
                  else if (event.channels.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(
                        child: Text(
                          'No hay canales disponibles para este evento en este momento.',
                          style: TextStyle(color: Colors.white38, fontSize: 14),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: event.channels.length,
                      itemBuilder: (context, index) {
                        final channel = event.channels[index];
                        final channelName = channel['name']?.toString() ?? 'Canal ${index + 1}';
                        final channelQuality = channel['quality']?.toString() ?? 'HD';
                        final url = (channel['url']?.toString() ??
                                channel['embed_url']?.toString() ??
                                '')
                            .trim();
                        final playable = url.isNotEmpty;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E24),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: ListTile(
                            enabled: playable,
                            leading: CircleAvatar(
                              backgroundColor: playable
                                  ? const Color(0xFFEF7A1E)
                                  : Colors.white24,
                              child: Icon(Icons.play_arrow,
                                  color: playable ? Colors.white : Colors.white38),
                            ),
                            title: Text(
                              channelName,
                              style: TextStyle(
                                color: playable ? Colors.white : Colors.white38,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              playable ? 'Calidad: $channelQuality' : 'No disponible',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            trailing: Icon(Icons.chevron_right,
                                color: playable ? Colors.white54 : Colors.transparent),
                            onTap: playable ? () => _onChannelTap(channel) : null,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
