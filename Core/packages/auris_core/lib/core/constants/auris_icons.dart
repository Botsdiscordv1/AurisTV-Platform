import 'package:reicon_flutter/reicon_flutter.dart';

class AurisIcons {
  AurisIcons._();

  // Reproducción, Tráiler, Episodios y Repetir
  static String get play => reiconSvg(Reicon.outline.play);
  static String get pause => reiconSvg(Reicon.outline.pause);
  static String get skipNext => reiconSvg(Reicon.outline.skipNext);
  static String get skipPrev => reiconSvg(Reicon.outline.skipPrev);
  static String get trailer => reiconSvg(Reicon.outline.videoPlayH);
  static String get videoLib => reiconSvg(Reicon.outline.videoLib);
  static String get episodes => reiconSvg(Reicon.outline.videoLib);
  static String get language => reiconSvg(Reicon.outline.language);
  static String get audioLanguage => reiconSvg(Reicon.outline.language);
  static String get restart => reiconSvg(Reicon.outline.restart);
  static String get repeat => reiconSvg(Reicon.outline.restart);
  static String get volumeUp => reiconSvg(Reicon.outline.volumeUp);
  static String get volumeDown => reiconSvg(Reicon.outline.volumeDown);
  static String get volumeMute => reiconSvg(Reicon.outline.volumeMute);

  // PiP (Picture in Picture) y Cast
  static String get toPip => reiconSvg(Reicon.outline.toPip);
  static String get exitPip => reiconSvg(Reicon.outline.exitPip);
  static String get cast => reiconSvg(Reicon.outline.screencast);

  // Navegación
  static String get home => reiconSvg(Reicon.outline.home);
  static String get search => reiconSvg(Reicon.outline.search);
  static String get compass => reiconSvg(Reicon.outline.compass);
  static String get grid => reiconSvg(Reicon.outline.grid);

  // Usuario, Favoritos y Acciones (Outline / Filled)
  static String get bookmarkOutline => reiconSvg(Reicon.outline.bookmark);
  static String get bookmarkFilled => reiconSvg(Reicon.filled.bookmark);
  static String get addCircleOutline => reiconSvg(Reicon.outline.addCircle);
  static String get addCircleFilled => reiconSvg(Reicon.filled.addCircle);
  static String get star => reiconSvg(Reicon.outline.star);
  static String get user => reiconSvg(Reicon.outline.user);
  static String get bell => reiconSvg(Reicon.outline.bell);
  static String get settings => reiconSvg(Reicon.outline.settings);
  static String get microphone => reiconSvg(Reicon.outline.microphone);
  static String get download => reiconSvg(Reicon.outline.download);
  static String get link => reiconSvg(Reicon.outline.link);
  static String get share => reiconSvg(Reicon.outline.share);

  // Sistema / TV D-Pad y Cierre
  static String get close => reiconSvg(Reicon.outline.x);
  static String get info => reiconSvg(Reicon.outline.infoCircle);
  static String get chevronLeft => reiconSvg(Reicon.outline.chevronLeft);
  static String get chevronRight => reiconSvg(Reicon.outline.chevronRight);
  static String get chevronUp => reiconSvg(Reicon.outline.chevronUp);
  static String get chevronDown => reiconSvg(Reicon.outline.chevronDown);
}
