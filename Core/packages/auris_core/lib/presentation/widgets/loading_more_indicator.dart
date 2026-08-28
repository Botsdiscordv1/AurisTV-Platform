import 'dart:async';

import 'package:flutter/material.dart';

/// Indicador animado mostrado mientras la búsqueda suplementaria (SLOW) sigue
/// trayendo más fuentes (p.ej. AV1/AnimeJara). Spin nativo + puntos animados
/// para comunicar al usuario que aún hay contenido cargando.
///
/// Es un único widget compartido por Móvil/Web/TV, pero sus dimensiones son
/// parametrizables porque en TV (UI de 10 pies, visto a distancia) la tipografía
/// debe ser mucho más grande y contrastada que en móvil/web.
class LoadingMoreIndicator extends StatefulWidget {
  final String text;
  final double fontSize;
  final double spinnerSize;
  final Color textColor;

  const LoadingMoreIndicator({
    super.key,
    this.text = 'Buscando más servidores',
    this.fontSize = 13,
    this.spinnerSize = 14,
    this.textColor = const Color(0xFFC8C8CE),
  });

  @override State<LoadingMoreIndicator> createState() => _LoadingMoreIndicatorState();
}

class _LoadingMoreIndicatorState extends State<LoadingMoreIndicator> {
  int _dots = 0;
  late final Timer _timer;

  @override void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => setState(() => _dots = (_dots + 1) % 4));
  }

  @override void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override Widget build(BuildContext context) {
    final dotStr = '.' * _dots;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: widget.spinnerSize,
            height: widget.spinnerSize,
          child: CircularProgressIndicator(
            strokeWidth: widget.spinnerSize * 0.16,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
          ),
        ),
        SizedBox(width: widget.fontSize * 0.7),
        Text(
          '${widget.text}$dotStr',
          style: TextStyle(color: widget.textColor, fontSize: widget.fontSize),
        ),
      ]),
    );
  }
}
