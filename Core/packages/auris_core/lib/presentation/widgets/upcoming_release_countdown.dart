import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auris_core.dart';
import '../../core/utils/release_countdown_logic.dart';

/// Componente visual reutilizable para mostrar el estado de "Próximo estreno"
/// con cuenta regresiva en vivo o estados posteriores (sin episodios / sin fecha).
class UpcomingReleaseCountdown extends StatefulWidget {
  final String? releaseStatus;
  final String? releaseDate;
  final String? releaseTimestamp;
  final List<EpisodeInfo> episodes;
  final VoidCallback? onCountdownZero;

  const UpcomingReleaseCountdown({
    super.key,
    this.releaseStatus,
    this.releaseDate,
    this.releaseTimestamp,
    this.episodes = const [],
    this.onCountdownZero,
  });

  factory UpcomingReleaseCountdown.fromState({
    Key? key,
    required UnifiedContentState state,
    VoidCallback? onCountdownZero,
  }) {
    final detail = state.detail.valueOrNull;
    final main = detail?.main;
    
    // Verificación 1: Extraer fecha de estreno del Detail (AnimeDetail o MovieDetail)
    final releaseDate = detail?.releaseDate ?? 
        (main is MovieDetail ? main.releaseDate : null) ?? 
        (main is AnimeDetail ? (main.year != null ? '${main.year}-01-01' : null) : null);
        
    final releaseTimestamp = detail?.releaseTimestamp ?? 
        (main is MovieDetail ? main.releaseTimestamp : null);
        
    final releaseStatus = detail?.releaseStatus ?? 
        (main is MovieDetail ? main.releaseStatus : null) ?? 
        (main is AnimeDetail ? main.status : null);

    // Verificación 2: Extraer la lista de episodios para confirmar si están vacíos
    final episodes = state.episodes.valueOrNull?.response.episodes ?? [];

    return UpcomingReleaseCountdown(
      key: key,
      releaseStatus: releaseStatus,
      releaseDate: releaseDate,
      releaseTimestamp: releaseTimestamp,
      episodes: episodes,
      onCountdownZero: onCountdownZero,
    );
  }

  @override
  State<UpcomingReleaseCountdown> createState() => _UpcomingReleaseCountdownState();
}

class _UpcomingReleaseCountdownState extends State<UpcomingReleaseCountdown> {
  Timer? _timer;
  late DateTime? _targetDateTime;
  late ReleaseState _currentState;
  Duration _timeRemaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _targetDateTime = ReleaseCountdownLogic.parseReleaseDateTime(
      widget.releaseTimestamp,
      widget.releaseDate,
    );
    _updateStateAndCountdown();

    if (_currentState == ReleaseState.upcoming || _currentState == ReleaseState.releasingToday) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(covariant UpcomingReleaseCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.releaseTimestamp != widget.releaseTimestamp ||
        oldWidget.releaseDate != widget.releaseDate ||
        oldWidget.episodes != widget.episodes) {
      _targetDateTime = ReleaseCountdownLogic.parseReleaseDateTime(
        widget.releaseTimestamp,
        widget.releaseDate,
      );
      _updateStateAndCountdown();
      if (_currentState == ReleaseState.upcoming || _currentState == ReleaseState.releasingToday) {
        _startTimer();
      } else {
        _stopTimer();
      }
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_targetDateTime != null) {
        final remaining = ReleaseCountdownLogic.calculateTimeRemaining(_targetDateTime!);
        setState(() {
          _timeRemaining = remaining;
        });

        if (remaining == Duration.zero) {
          timer.cancel();
          _updateStateAndCountdown();
          widget.onCountdownZero?.call();
        }
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _updateStateAndCountdown() {
    _currentState = ReleaseCountdownLogic.evaluate(
      episodes: widget.episodes,
      releaseStatus: widget.releaseStatus,
      releaseDate: widget.releaseDate,
      releaseTimestamp: widget.releaseTimestamp,
    );

    if (_targetDateTime != null &&
        (_currentState == ReleaseState.upcoming || _currentState == ReleaseState.releasingToday)) {
      _timeRemaining = ReleaseCountdownLogic.calculateTimeRemaining(_targetDateTime!);
    } else {
      _timeRemaining = Duration.zero;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si ya hay episodios (Disponible), no renderizamos el countdown
    if (_currentState == ReleaseState.available) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth > 600;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: isWide ? 0 : 24, vertical: 16),
      padding: EdgeInsets.all(isWide ? 32 : 24),
      decoration: BoxDecoration(
        color: const Color(0xFF141418),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Cabecera de Estado
          _buildHeader(),
          const SizedBox(height: 16),

          // Contenido según el estado
          if (_currentState == ReleaseState.upcoming || _currentState == ReleaseState.releasingToday)
            _buildCountdownContent()
          else if (_currentState == ReleaseState.releasedWithoutEpisodes)
            _buildReleasedWithoutEpisodesContent()
          else
            _buildNoReleaseDateContent(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    String titleText = 'PRÓXIMO ESTRENO';
    if (_currentState == ReleaseState.releasingToday) {
      titleText = 'ESTRENA HOY';
    } else if (_currentState == ReleaseState.releasedWithoutEpisodes) {
      titleText = 'EPISODIOS PRÓXIMAMENTE';
    } else if (_currentState == ReleaseState.noReleaseDate) {
      titleText = 'PRÓXIMAMENTE';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFFEF7A1E),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          titleText,
          style: GoogleFonts.poppins(
            color: const Color(0xFFEF7A1E),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFFEF7A1E),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  Widget _buildCountdownContent() {
    final days = _timeRemaining.inDays;
    final hours = _timeRemaining.inHours % 24;
    final minutes = _timeRemaining.inMinutes % 60;
    final seconds = _timeRemaining.inSeconds % 60;

    return Column(
      children: [
        // Números del contador
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildTimeUnit(days.toString().padLeft(2, '0'), 'DÍAS'),
            _buildSeparator(),
            _buildTimeUnit(hours.toString().padLeft(2, '0'), 'HORAS'),
            _buildSeparator(),
            _buildTimeUnit(minutes.toString().padLeft(2, '0'), 'MINUTOS'),
            _buildSeparator(),
            _buildTimeUnit(seconds.toString().padLeft(2, '0'), 'SEGUNDOS'),
          ],
        ),
        const SizedBox(height: 24),

        // Fecha formateada
        if (_targetDateTime != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_today_rounded, color: Color(0xFFA5A5AA), size: 16),
              const SizedBox(width: 8),
              Text(
                ReleaseCountdownLogic.formatDate(_targetDateTime!),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // Mensaje descriptivo
        Text(
          'Los episodios estarán disponibles cuando comience su emisión.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: const Color(0xFFA5A5AA),
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeUnit(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: const Color(0xFFA5A5AA),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeparator() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        ':',
        style: GoogleFonts.poppins(
          color: Colors.white.withOpacity(0.4),
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildReleasedWithoutEpisodesContent() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          'El contenido ya fue estrenado,\npero los episodios todavía no están disponibles.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.9),
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Vuelve a consultar más tarde para ver los nuevos capítulos.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: const Color(0xFFA5A5AA),
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildNoReleaseDateContent() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          'Aún no hay una fecha de estreno confirmada.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.9),
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Mantén este contenido en tu lista para enterarte cuando se anuncien novedades.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: const Color(0xFFA5A5AA),
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
