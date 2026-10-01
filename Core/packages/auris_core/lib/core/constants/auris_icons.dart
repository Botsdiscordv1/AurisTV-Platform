import 'package:reicon_flutter/reicon_flutter.dart';

class AurisIcons {
  AurisIcons._();

  // Reproducción, Tráiler, Episodios, Servidor y Repetir
  static String get play => reiconSvg(Reicon.outline.play);
  static String get playFilled => reiconSvg(Reicon.filled.play);
  static String get play3 => reiconSvg(Reicon.outline.play3);
  static String get play3Filled => reiconSvg(Reicon.filled.play3);
  static String get pause => reiconSvg(Reicon.outline.pause);
  static String get forwardStep => reiconSvg(Reicon.outline.forwardStep);
  static String get backwardStep => reiconSvg(Reicon.outline.backwardStep);
  static String get skipNext => forwardStep;
  static String get skipPrev => backwardStep;
  static String get fastForward => reiconSvg(Reicon.outline.fastForward);
  static String get trailer => reiconSvg(Reicon.outline.videoPlayH);
  static String get videoLib => reiconSvg(Reicon.outline.videoLib);
  static String get episodes => reiconSvg(Reicon.outline.videoLib);
  static String get server => reiconSvg(Reicon.outline.ssd2);
  static String get subtitles => reiconSvg(Reicon.outline.subtitles);
  static String get language => reiconSvg(Reicon.outline.subtitles);
  static String get audioLanguage => reiconSvg(Reicon.outline.subtitles);
  static String get restart => reiconSvg(Reicon.outline.restart);
  static String get repeat => reiconSvg(Reicon.outline.restart);
  static String get backward10 => reiconSvg(Reicon.outline.backward10Seconds);
  static String get forward10 => reiconSvg(Reicon.outline.forward10Seconds);
  static String get backward10Seconds => reiconSvg(Reicon.outline.backward10Seconds);
  static String get forward10Seconds => reiconSvg(Reicon.outline.forward10Seconds);
  
  // Volumen, Mute y Boost (volume-high, volume-down, volume-cross, bolt)
  static String get volumeHigh => reiconSvg(Reicon.outline.volumeHigh);
  static String get volumeDown => reiconSvg(Reicon.outline.volumeDown);
  static String get volumeCross => reiconSvg(Reicon.outline.volumeCross);
  static String get volumeUp => volumeHigh;
  static String get volumeMute => volumeCross;
  static String get mute => volumeCross;
  static String get bolt => reiconSvg(Reicon.outline.bolt);
  static String get boltFilled => reiconSvg(Reicon.filled.bolt);

  static String get speedometer => reiconSvg(Reicon.outline.speedometer);
  static String get speed => reiconSvg(Reicon.outline.speedometer);

  // PiP (Picture in Picture), Cast, Rotación, Candados y Pantalla Completa
  static String get toPip => reiconSvg(Reicon.outline.toPip);
  static String get exitPip => reiconSvg(Reicon.outline.exitPip);
  static String get cast => reiconSvg(Reicon.outline.screencast);
  static String get phoneRotate => reiconSvg(Reicon.outline.phoneRotate2);
  static String get lockOpen => reiconSvg(Reicon.outline.lockKeyholeOpen);
  static String get lockClosed => reiconSvg(Reicon.outline.lockKeyhole);
  static String get aspectRatioSquare => reiconSvg(Reicon.outline.aspectRatioSquare);
  static String get expand => reiconSvg(Reicon.outline.expand);
  static String get exitFullscreen => reiconSvg(Reicon.outline.exitFullscreen);
  static String get maximize => reiconSvg(Reicon.outline.maximize);
  static String get minimize => reiconSvg(Reicon.outline.minimize);

  // Navegación (Outline / Filled para Navbar)
  static String get homeOutline => reiconSvg(Reicon.outline.home6);
  static String get homeFilled => reiconSvg(Reicon.filled.home6);
  static String get searchOutline => reiconSvg(Reicon.outline.search);
  static String get searchFilled => reiconSvg(Reicon.filled.search);
  static String get compassOutline => reiconSvg(Reicon.outline.compass);
  static String get compassFilled => reiconSvg(Reicon.filled.compass);
  static String get userOutline => reiconSvg(Reicon.outline.user);
  static String get userFilled => reiconSvg(Reicon.filled.user);

  // Aliases por compatibilidad
  static String get home => homeOutline;
  static String get search => searchOutline;
  static String get compass => compassOutline;
  static String get user => userOutline;
  static String get grid => reiconSvg(Reicon.outline.grid);

  // Usuario, Favoritos y Acciones (Outline / Filled)
  static String get bookmarkOutline => reiconSvg(Reicon.outline.bookmark);
  static String get bookmarkFilled => reiconSvg(Reicon.filled.bookmark);
  static String get add => reiconSvg(Reicon.outline.add);
  static String get addCircleOutline => reiconSvg(Reicon.outline.addCircle);
  static String get addCircleFilled => reiconSvg(Reicon.filled.addCircle);
  static String get star => reiconSvg(Reicon.outline.star);
  static String get bell => reiconSvg(Reicon.outline.bell);
  static String get settings => reiconSvg(Reicon.outline.setting2);
  static String get setting => reiconSvg(Reicon.outline.setting2);
  static String get microphone => reiconSvg(Reicon.outline.microphone);
  static String get download => reiconSvg(Reicon.outline.download);
  static String get link => reiconSvg(Reicon.outline.link);
  static String get forwardRight => reiconSvg(Reicon.outline.forwardRight);
  static String get share => reiconSvg(Reicon.outline.forwardRight);
  static String get verify => reiconSvg(Reicon.outline.verify);
  static String get verified => reiconSvg(Reicon.outline.verify);
  static String get like => reiconSvg(Reicon.outline.like);
  static String get dislike => reiconSvg(Reicon.outline.dislike);
  static String get thumbUp => like;
  static String get thumbDown => dislike;

  // Sistema / TV D-Pad y Cierre
  static String get close => reiconSvg(Reicon.outline.x);
  static String get info => reiconSvg(Reicon.outline.infoCircle);
  static String get chevronLeft => reiconSvg(Reicon.outline.chevronLeft);
  static String get chevronRight => reiconSvg(Reicon.outline.chevronRight);
  static String get chevronUp => reiconSvg(Reicon.outline.chevronUp);
  static String get chevronDown => reiconSvg(Reicon.outline.chevronDown);
}
