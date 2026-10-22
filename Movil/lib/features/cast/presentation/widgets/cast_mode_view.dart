import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:auris_core/auris_core.dart';

import '../providers/cast_provider.dart';

/// Modo "transmitiendo a Chromecast": overlay completo estilo Netflix que
/// sustituye al reproductor local mientras el video corre en el receptor.
///
/// El PlayerScreen decide mostrarlo cuando `chromecastProvider` estÃ¡ en fase
/// casting; aquÃ­ solo se controla el receptor nativo (play/pause/seek/stop).
///
/// Handback: "DETENER TRANSMISIÃ“N" corta la sesiÃ³n nativa; el evento
/// `sessionEnded` (con la Ãºltima posiciÃ³n) la recibe el PlayerScreen y
/// retoma la reproducciÃ³n local desde ahÃ­.
class ChromecastModeView extends ConsumerWidget {
  final String title;
  final String episodeLabel;
  final String? posterUrl;
  final String? bannerUrl;
  final String? logoUrl;

  const ChromecastModeView({
    super.key,
    required this.title,
    required this.episodeLabel,
    this.posterUrl,
    this.bannerUrl,
    this.logoUrl,
  });

  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final castState = ref.watch(chromecastProvider);
    final notifier = ref.read(chromecastProvider.notifier);
    final media = castState.media;
    final device = castState.device;
    const accent = Color(0xFFEF7A1E);

    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    final image = (bannerUrl ?? posterUrl ?? '').isNotEmpty
        ? ApiEndpoints.proxyImage(bannerUrl ?? posterUrl)
        : null;

    final double maxMs = media.durationMs > 0 ? media.durationMs.toDouble() : 1.0;
    final double posMs = media.positionMs.clamp(0, media.durationMs).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fondo editorial: banner/poster difuminado
          if (image != null) ...[
            CachedNetworkImage(
              imageUrl: image,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xB3000000), Color(0xE6000000), Color(0xFF000000)],
                ),
              ),
            ),
          ],

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: [
                    // ---------------- Header: pill del dispositivo ----------------
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: accent.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AurisIcon(AurisIcons.castTv, color: accent, size: 18),
                                const SizedBox(width: 10),
                                Text(
                                  (device?.name.isEmpty ?? true)
                                      ? 'CHROMECAST'
                                      : device!.name.toUpperCase(),
                                  style: const TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => notifier.stopCasting(),
                                child: const Center(
                                  child: Icon(Icons.close_rounded,
                                      color: Colors.white, size: 22),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ---------------- Centro: arte del contenido ----------------
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                            horizontal: isLandscape ? 40 : 32, vertical: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (posterUrl != null && posterUrl!.isNotEmpty)
                              _buildPoster(constraints, isLandscape),
                            const SizedBox(height: 16),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (episodeLabel.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                episodeLabel,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 13),
                              ),
                            ],
                            const SizedBox(height: 12),
                            if (!media.loaded)
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: accent),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Cargando en el Chromecast...',
                                      style: TextStyle(
                                          color: Colors.white60,
                                          fontSize: 13)),
                                ],
                              )
                            else if (media.buffering)
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: accent),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Buffering...',
                                      style: TextStyle(
                                          color: Colors.white60,
                                          fontSize: 13)),
                                ],
                              )
                            else if (castState.error != null)
                              Text(castState.error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.redAccent, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),

                    // ---------------- Timeline + controles ----------------
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (media.loaded) ...[
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 5,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 8),
                                overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 16),
                              ),
                              child: Slider(
                                value: posMs,
                                min: 0,
                                max: maxMs,
                                activeColor: accent,
                                inactiveColor: Colors.white24,
                                onChanged: (v) => notifier.seekTo(v.toInt()),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(media.positionMs),
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 12),
                                  ),
                                  Text(
                                    _formatDuration(media.durationMs),
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _CastControlButton(
                                icon: AurisIcons.backward10,
                                onTap: () => notifier.seekTo(
                                    (media.positionMs - 10000).clamp(0, 1 << 31)),
                                size: 56,
                              ),
                              Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 20),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () => notifier.togglePlay(),
                                    child: SizedBox(
                                      width: 72,
                                      height: 72,
                                      child: Center(
                                        child: AurisIcon(
                                          media.loaded && !media.isPlaying
                                              ? AurisIcons.play
                                              : AurisIcons.pauseFilled,
                                          color: Colors.black,
                                          size: 34,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              _CastControlButton(
                                icon: AurisIcons.forward10,
                                onTap: () => notifier.seekTo(
                                    (media.positionMs + 10000)
                                        .clamp(0, 1 << 31)),
                                size: 56,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Footer: handback (retomar reproducciÃ³n local)
                          TextButton.icon(
                            onPressed: () => notifier.stopCasting(),
                            icon: AurisIcon(AurisIcons.cast, color: Colors.redAccent, size: 16),
                            label: const Text('DETENER TRANSMISIÃ“N',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2)),
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.redAccent),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  /// Poster vertical del contenido, dimensionado en función del espacio
  /// disponible (LayoutBuilder) para verse proporcional en portrait y landscape.
  Widget _buildPoster(BoxConstraints constraints, bool isLandscape) {
    final double posterH = isLandscape
        ? constraints.maxHeight * 0.62
        : constraints.maxHeight * 0.42;
    final double posterW = (posterH * 2 / 3)
        .clamp(140.0, constraints.maxWidth - 16)
        .toDouble();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 40,
            spreadRadius: 4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: posterH,
          width: posterW,
          child: CachedNetworkImage(
            imageUrl: ApiEndpoints.proxyImage(posterUrl!),
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _CastControlButton extends StatelessWidget {
  final String icon;
  final VoidCallback onTap;
  final double size;

  const _CastControlButton({
    required this.icon,
    required this.onTap,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(child: AurisIcon(icon, color: Colors.white, size: 24)),
        ),
      ),
    );
  }
}
