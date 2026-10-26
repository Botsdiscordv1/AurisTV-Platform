import 'package:flutter/material.dart';
import '../../auris_core.dart';

/// Pantalla dedicada `content_sport` para eventos deportivos en vivo y próximos.
/// Muestra los detalles completos del evento (liga, equipos, sinopsis, estado en vivo)
/// y un selector directo de canales de transmisión (`channels`).
class ContentSportScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
              onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
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
                  if (event.channels.isEmpty)
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

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E24),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFEF7A1E),
                              child: Icon(Icons.play_arrow, color: Colors.white),
                            ),
                            title: Text(
                              channelName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'Calidad: $channelQuality',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                            onTap: () {
                              if (onChannelSelected != null) {
                                onChannelSelected!(channel);
                              } else {
                                // Default action: play stream using activePlayerProvider or navigate
                                debugPrint('[ContentSportScreen] Selected channel: $channelName (${channel['url']})');
                              }
                            },
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
