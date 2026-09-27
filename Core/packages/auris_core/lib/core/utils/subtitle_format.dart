import 'package:flutter/material.dart';

/// Convención de formato de los subtítulos de Continuar Viendo
/// (generados por `continueCardSubtitle` en library_providers):
/// - "T1:E7 . Título" → negrita hasta ' . ' (el "T1:E7").
/// - "Quedan: 21 min" → negrita hasta ':' (el "Quedan:").
/// Sin marcador se devuelve texto plano (mismo render que antes).
InlineSpan subtitleRichSpan(String text, TextStyle base) {
  int cut = -1;
  final dot = text.indexOf(' . ');
  if (dot > 0) {
    cut = dot;
  } else {
    final colon = text.indexOf(':');
    if (colon > 0) cut = colon + 1;
  }
  if (cut <= 0) return TextSpan(text: text, style: base);
  return TextSpan(
    children: [
      TextSpan(
        text: text.substring(0, cut),
        style: base.copyWith(fontWeight: FontWeight.w800),
      ),
      TextSpan(text: text.substring(cut), style: base),
    ],
  );
}
