import 'dart:async';
import 'package:flutter/material.dart';

/// Formatea un timestamp unix (segundos) a hora local "HH:mm".
String formatAiringTime(int airingAt) {
  final t = DateTime.fromMillisecondsSinceEpoch(airingAt * 1000).toLocal();
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// Badge en vivo con la hora de estreno: muestra "HOY · 21:30" en estrenos del
/// día, "EN 2H" / "EN 45M" en countdown, y el reloj en el resto.
class AiringCountdownBadge extends StatefulWidget {
  final int airingAt;
  final bool aired;

  // Etiqueta de estreno (premiere-ping): 'delayed' + min de retraso o
  // 'advanced' + min de adelanto → chip "Retrasado +37m" / "Adelantado -12m".
  final String? premiereStatus;
  final int? premiereDeltaMin;

  const AiringCountdownBadge({
    super.key,
    required this.airingAt,
    required this.aired,
    this.premiereStatus,
    this.premiereDeltaMin,
  });

  @override
  State<AiringCountdownBadge> createState() => _AiringCountdownBadgeState();
}

class _AiringCountdownBadgeState extends State<AiringCountdownBadge> {
  late DateTime _airing;
  Timer? _timer;

  /// ¿Este badge puede cambiar su etiqueta con el paso del tiempo?
  /// Solo los estrenos de hoy o los próximos a <2h (countdown) necesitan timer
  /// en vivo; el resto muestra una hora estática.
  bool get _needsLiveUpdate {
    final now = DateTime.now();
    final diff = _airing.difference(now);
    final today = DateTime(now.year, now.month, now.day);
    final airDay = DateTime(_airing.year, _airing.month, _airing.day);
    return diff.inMinutes < 120 || airDay == today;
  }

  @override
  void initState() {
    super.initState();
    _airing = DateTime.fromMillisecondsSinceEpoch(widget.airingAt * 1000).toLocal();
    if (_needsLiveUpdate) {
      // Refresca el countdown en vivo (solo para estrenos de hoy / próximos).
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// "Retrasado +37m" / "Adelantado -12m" (o la sola palabra si no hay delta).
  String? get _premiereLabel {
    switch (widget.premiereStatus) {
      case 'delayed':
        final d = widget.premiereDeltaMin;
        return (d != null && d > 0) ? 'Retrasado +${d}m' : 'Retrasado';
      case 'advanced':
        final d = widget.premiereDeltaMin;
        return (d != null && d != 0) ? 'Adelantado -${d.abs()}m' : 'Adelantado';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final aired = widget.aired || _airing.isBefore(now);

    String label;
    Color bg;
    Color fg;
    bool urgent = false;

    if (aired) {
      label = 'Emitido · ${formatAiringTime(widget.airingAt)}';
      bg = const Color(0xFFEF7A1E).withOpacity(0.85);
      fg = Colors.white;
    } else {
      final diff = _airing.difference(now);
      final inMinutes = diff.inMinutes;
      if (inMinutes < 120) {
        // Countdown: EN 45M / EN 1H
        final h = diff.inHours;
        final m = inMinutes % 60;
        label = h > 0 ? 'EN ${h}H${m > 0 ? ' ${m}M' : ''}' : 'EN ${inMinutes}M';
        bg = Colors.redAccent.withOpacity(0.85);
        fg = Colors.white;
        urgent = true;
      } else {
        final today = DateTime(now.year, now.month, now.day);
        final airDay = DateTime(_airing.year, _airing.month, _airing.day);
        final dayDiff = airDay.difference(today).inDays;
        final time = formatAiringTime(widget.airingAt);
        if (dayDiff == 0) {
          label = 'HOY $time';
          bg = const Color(0xFFEF7A1E).withOpacity(0.9);
          fg = Colors.white;
        } else if (dayDiff == 1) {
          label = 'MAÑANA $time';
          bg = const Color(0xFF1E1E26);
          fg = Colors.white;
        } else {
          label = time;
          bg = const Color(0xFF1E1E26);
          fg = Colors.white;
        }
      }
    }

    final badge = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.only(
          bottomRight: Radius.circular(8),
          // Senior Pixel-Perfect Fix: Dejamos la esquina superior izquierda a 0
          // para que el ClipRRect de la tarjeta la recorte con precisión quirúrgica.
        ),
        border: urgent ? Border.all(color: Colors.white, width: 1) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            urgent
                ? Icons.schedule
                : (aired ? Icons.check_circle : Icons.access_time_filled),
            size: 10,
            color: fg,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );

    final premiereLabel = _premiereLabel;
    if (premiereLabel == null) return badge;

    // Chip de desvío de estreno (estilo AV1): "Retrasado +37m" / "Adelantado -12m".
    final delayed = widget.premiereStatus == 'delayed';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        badge,
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: (delayed ? const Color(0xFFC62828) : const Color(0xFF2E7D32))
                .withOpacity(0.95),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                delayed ? Icons.schedule : Icons.fast_forward,
                size: 9,
                color: Colors.white,
              ),
              const SizedBox(width: 3),
              Text(
                premiereLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
