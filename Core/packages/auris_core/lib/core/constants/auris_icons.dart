import 'package:reicon_flutter/reicon_flutter.dart';

class AurisIcons {
  AurisIcons._();

  // Reproducción, Tráiler, Episodios, Servidor y Repetir
  static String get play => reiconSvg(Reicon.outline.play);
  static String get playFilled => reiconSvg(Reicon.filled.play);
  static String get play3 => reiconSvg(Reicon.outline.play3);
  static String get play3Filled => reiconSvg(Reicon.filled.play3);
  static String get playCircleFilled => reiconSvg(Reicon.filled.playCircle);
  static String get rewind => reiconSvg(Reicon.outline.rewind);
  static String get sunHigh => reiconSvg(Reicon.outline.sun);
  static String get sunMid => reiconSvg(Reicon.outline.sun2);
  static String get sunLow => reiconSvg(Reicon.outline.sun4);
  static String get autoBrightness => reiconSvg(Reicon.outline.autobrightness);
  static String get autobrightness => reiconSvg(Reicon.outline.autobrightness);
  static String get alertCircle => reiconSvg(Reicon.outline.alertCircle);
  static String get checkCircleFilled => reiconSvg(Reicon.filled.checkCircle);
  static String get hd => reiconSvg(Reicon.outline.hd);
  static String get arrowLeft => reiconSvg(Reicon.outline.arrowLeft);
  static String get arrowLeft2 => reiconSvg(Reicon.outline.arrowLeft2);
  static String get arrowRight2 => reiconSvg(Reicon.outline.arrowRight2);
  static String get export => reiconSvg(Reicon.outline.export);
  static String get arrowUpRight => reiconSvg(Reicon.outline.arrowUpRight);
  static String get squareArrowUp => reiconSvg(Reicon.outline.squareArrowUp);
  static String get film => reiconSvg(Reicon.outline.film);
  static String get pause => reiconSvg(Reicon.outline.pause);
  static String get pauseFilled => reiconSvg(Reicon.filled.pause);
  static String get forwardStep => reiconSvg(Reicon.outline.forwardStep);
  static String get backwardStep => reiconSvg(Reicon.outline.backwardStep);
  static String get skipNext => forwardStep;
  static String get skipPrev => backwardStep;
  static String get fastForward => reiconSvg(Reicon.outline.fastForward);
  static String get fastForwardFilled => reiconSvg(Reicon.filled.fastForward);
  static String get trailer => reiconSvg(Reicon.outline.videoPlayH);
  static String get trailerFilled => reiconSvg(Reicon.filled.videoPlayH);
  static String get videoLib => reiconSvg(Reicon.outline.videoLib);
  static String get episodes => reiconSvg(Reicon.outline.videoLib);
  static String get episodesFilled => reiconSvg(Reicon.filled.videoLib);
  static String get docText => reiconSvg(Reicon.outline.docText);
  static String get docTextFilled => reiconSvg(Reicon.filled.docText);
  static String get server => reiconSvg(Reicon.outline.ssd2);
  static String get subtitles => reiconSvg(Reicon.outline.subtitles);
  static String get language => reiconSvg(Reicon.outline.subtitles);
  static String get audioLanguage => reiconSvg(Reicon.outline.subtitles);
  static String get restart => reiconSvg(Reicon.outline.rotateLeft);
  static String get repeat => reiconSvg(Reicon.outline.rotateLeft);
  static String get rotateLeft => reiconSvg(Reicon.outline.rotateLeft);
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

  static String get speedometer => reiconSvg(Reicon.outline.flash);
  static String get speed => reiconSvg(Reicon.outline.flash);
  static String get flash => reiconSvg(Reicon.outline.flash);

  // PiP (Picture in Picture), Cast, Rotación, Candados y Pantalla Completa
  static String get toPip => reiconSvg(Reicon.outline.toPip);
  static String get exitPip => reiconSvg(Reicon.outline.exitPip);
  static String get cast => reiconSvg(Reicon.outline.screencast);
  static String get castTv => reiconSvg(Reicon.outline.screencast2);
  static String get castDesktop => reiconSvg(Reicon.outline.desktop);
  static String get castMobile => reiconSvg(Reicon.outline.mobile);
  static String get tv => reiconSvg(Reicon.outline.screencast2);
  static String get desktop => reiconSvg(Reicon.outline.desktop);
  static String get mobile => reiconSvg(Reicon.outline.mobile);
  static String get phoneRotate => reiconSvg(Reicon.outline.phoneRotate2);
  static String get gamepadButtons => reiconSvg(Reicon.outline.gamepadButtons);
  static String get dpad => gamepadButtons;
  static String get gamepad => gamepadButtons;
  static String get lockOpen => reiconSvg(Reicon.outline.lockKeyholeOpen);
  static String get lockClosed => reiconSvg(Reicon.outline.lockKeyhole);
  static String get aspectRatioSquare => reiconSvg(Reicon.outline.aspectRatioSquare);
  static String get expand => reiconSvg(Reicon.outline.expand);
  static String get exitFullscreen => reiconSvg(Reicon.outline.compress);
  static String get compress => reiconSvg(Reicon.outline.compress);
  static String get maximize => reiconSvg(Reicon.outline.maximize);
  static String get maximizeFilled => reiconSvg(Reicon.filled.maximize);
  static String get expandFilled => reiconSvg(Reicon.filled.expand);
  static String get minimize => reiconSvg(Reicon.outline.minimize);
  static String get zoomIn => reiconSvg(Reicon.outline.searchZoomIn);

  // Iconos SVG Personalizados (E:\AurisTV_plataformas\AurisIcon)
  static String get expandir => r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path d="M21.20 3.01L21 3H3L2.79 3.01C2.30 3.06 1.84 3.29 1.51 3.65C1.18 4.02 .99 4.50 1 5V19L1.01 19.20C1.05 19.66 1.26 20.08 1.58 20.41C1.91 20.73 2.33 20.94 2.79 20.99L3 21H21L21.20 20.98C21.66 20.94 22.08 20.73 22.41 20.41C22.73 20.08 22.94 19.66 22.99 19.20L23 19V5C23.00 4.50 22.81 4.02 22.48 3.65C22.15 3.29 21.69 3.06 21.20 3.01ZM3 15V5H21V15H3ZM7.87 6.72L7.79 6.79L4.58 10L7.79 13.20C7.88 13.30 7.99 13.37 8.11 13.43C8.23 13.48 8.37 13.51 8.50 13.51C8.63 13.51 8.76 13.48 8.89 13.43C9.01 13.38 9.12 13.31 9.21 13.21C9.31 13.12 9.38 13.01 9.43 12.89C9.48 12.76 9.51 12.63 9.51 12.50C9.51 12.37 9.48 12.23 9.43 12.11C9.37 11.99 9.30 11.88 9.20 11.79L7.41 10L9.20 8.20L9.27 8.13C9.42 7.93 9.50 7.69 9.48 7.45C9.47 7.20 9.36 6.97 9.19 6.80C9.02 6.63 8.79 6.52 8.54 6.51C8.30 6.49 8.06 6.57 7.87 6.72ZM14.79 6.79C14.60 6.98 14.50 7.23 14.50 7.5C14.50 7.76 14.60 8.01 14.79 8.20L16.58 10L14.79 11.79L14.72 11.86C14.57 12.06 14.49 12.30 14.50 12.54C14.51 12.79 14.62 13.02 14.79 13.20C14.97 13.37 15.20 13.48 15.45 13.49C15.69 13.50 15.93 13.42 16.13 13.27L16.20 13.20L19.41 10L16.20 6.79C16.01 6.60 15.76 6.50 15.5 6.50C15.23 6.50 14.98 6.60 14.79 6.79ZM3 19V17H21V19H3Z" fill="white"/></svg>''';
  static String get customFullscreen => r'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path d="M10 3H3V10C3 10.26 3.10 10.51 3.29 10.70C3.48 10.89 3.73 11 4 11C4.26 11 4.51 10.89 4.70 10.70C4.89 10.51 5 10.26 5 10V6.41L9.29 10.70L9.36 10.77C9.56 10.92 9.80 11.00 10.04 10.99C10.29 10.98 10.52 10.87 10.70 10.70C10.87 10.52 10.98 10.29 10.99 10.04C11.00 9.80 10.92 9.56 10.77 9.36L10.70 9.29L6.41 5H10C10.26 5 10.51 4.89 10.70 4.70C10.89 4.51 11 4.26 11 4C11 3.73 10.89 3.48 10.70 3.29C10.51 3.10 10.26 3 10 3ZM20 13C19.73 13 19.48 13.10 19.29 13.29C19.10 13.48 19 13.73 19 14V17.58L14.70 13.29L14.63 13.22C14.43 13.07 14.19 12.99 13.95 13.00C13.70 13.01 13.47 13.12 13.29 13.29C13.12 13.47 13.01 13.70 13.00 13.95C12.99 14.19 13.07 14.43 13.22 14.63L13.29 14.70L17.58 19H14C13.73 19 13.48 19.10 13.29 19.29C13.10 19.48 13 19.73 13 20C13 20.26 13.10 20.51 13.29 20.70C13.48 20.89 13.73 21 14 21H21V14C21 13.73 20.89 13.48 20.70 13.29C20.51 13.10 20.26 13 20 13Z" fill="white"/></svg>''';
  static String get customVolume => r'''<svg xmlns="http://www.w3.org/2000/svg" height="24" viewBox="0 0 24 24" width="24"><path class="ytp-svg-fill ytp-svg-volume-animation-speaker" d="M 11.60 2.08 L 11.48 2.14 L 3.91 6.68 C 3.02 7.21 2.28 7.97 1.77 8.87 C 1.26 9.77 1.00 10.79 1 11.83 V 12.16 L 1.01 12.56 C 1.07 13.52 1.37 14.46 1.87 15.29 C 2.38 16.12 3.08 16.81 3.91 17.31 L 11.48 21.85 C 11.63 21.94 11.80 21.99 11.98 21.99 C 12.16 22.00 12.33 21.95 12.49 21.87 C 12.64 21.78 12.77 21.65 12.86 21.50 C 12.95 21.35 13 21.17 13 21 V 3 C 12.99 2.83 12.95 2.67 12.87 2.52 C 12.80 2.37 12.68 2.25 12.54 2.16 C 12.41 2.07 12.25 2.01 12.08 2.00 C 11.92 1.98 11.75 2.01 11.60 2.08 Z" fill="#fff"></path><path class="ytp-svg-volume-animation-small-ripple" d=" M 15.53 7.05 C 15.35 7.22 15.25 7.45 15.24 7.70 C 15.23 7.95 15.31 8.19 15.46 8.38 L 15.53 8.46 L 15.70 8.64 C 16.09 9.06 16.39 9.55 16.61 10.08 L 16.70 10.31 C 16.90 10.85 17 11.42 17 12 L 16.99 12.24 C 16.96 12.73 16.87 13.22 16.70 13.68 L 16.61 13.91 C 16.36 14.51 15.99 15.07 15.53 15.53 C 15.35 15.72 15.25 15.97 15.26 16.23 C 15.26 16.49 15.37 16.74 15.55 16.92 C 15.73 17.11 15.98 17.21 16.24 17.22 C 16.50 17.22 16.76 17.12 16.95 16.95 C 17.6 16.29 18.11 15.52 18.46 14.67 L 18.59 14.35 C 18.82 13.71 18.95 13.03 18.99 12.34 L 19 12 C 18.99 11.19 18.86 10.39 18.59 9.64 L 18.46 9.32 C 18.15 8.57 17.72 7.89 17.18 7.3 L 16.95 7.05 L 16.87 6.98 C 16.68 6.82 16.43 6.74 16.19 6.75 C 15.94 6.77 15.71 6.87 15.53 7.05" fill="#fff" transform="translate(18, 12) scale(1) translate(-18,-12)"></path><path class="ytp-svg-volume-animation-big-ripple" d="M18.36 4.22C18.18 4.39 18.08 4.62 18.07 4.87C18.05 5.12 18.13 5.36 18.29 5.56L18.36 5.63L18.66 5.95C19.36 6.72 19.91 7.60 20.31 8.55L20.47 8.96C20.82 9.94 21 10.96 21 11.99L20.98 12.44C20.94 13.32 20.77 14.19 20.47 15.03L20.31 15.44C19.86 16.53 19.19 17.52 18.36 18.36C18.17 18.55 18.07 18.80 18.07 19.07C18.07 19.33 18.17 19.59 18.36 19.77C18.55 19.96 18.80 20.07 19.07 20.07C19.33 20.07 19.59 19.96 19.77 19.77C20.79 18.75 21.61 17.54 22.16 16.20L22.35 15.70C22.72 14.68 22.93 13.62 22.98 12.54L23 12C22.99 10.73 22.78 9.48 22.35 8.29L22.16 7.79C21.67 6.62 20.99 5.54 20.15 4.61L19.77 4.22L19.70 4.15C19.51 3.99 19.26 3.91 19.02 3.93C18.77 3.94 18.53 4.04 18.36 4.22 Z" fill="#fff" transform="translate(22, 12) scale(1) translate(-22, -12)"></path></svg>''';
  static String get customPlay => r'''<svg xmlns="http://www.w3.org/2000/svg" fill="none" height="36" viewBox="0 0 36 36" width="36"><path d="M 17 8.6 L 10.89 4.99 C 9.39 4.11 7.5 5.19 7.5 6.93 C 7.5 6.93 7.5 6.93 7.5 6.93 L 7.5 29.06 C 7.5 30.8 9.39 31.88 10.89 31 C 10.89 31 10.89 31 10.89 31 L 17 27.4 C 17 27.4 17 27.4 17 27.4 C 17 27.4 17 27.4 17 27.4 L 17 8.6 C 17 8.6 17 8.6 17 8.6 C 17 8.6 17 8.6 17 8.6 Z M 17 8.6 L 17 8.6 C 17 8.6 17 8.6 17 8.6 C 17 8.6 17 8.6 17 8.6 V 27.4 C 17 27.4 17 27.4 17 27.4 C 17 27.4 17 27.4 17 27.4 L 33 18 C 33 18 33 18 33 18 C 33 18 33 18 33 18 V 18 L 17 8.6 C 17 8.6 17 8.6 17 8.6 C 17 8.6 17 8.6 17 8.6 Z" fill="white"/></svg>''';
  static String get customPause => r'''<svg xmlns="http://www.w3.org/2000/svg" fill="none" height="36" viewBox="0 0 36 36" width="36"><path d="M 12.75 4.5 L 9.75 4.5 C 9.15 4.5 8.58 4.73 8.15 5.15 C 7.73 5.58 7.5 6.15 7.5 6.75 L 7.5 29.25 C 7.5 29.84 7.73 30.41 8.15 30.84 C 8.58 31.26 9.15 31.5 9.75 31.5 L 12.75 31.5 C 13.34 31.5 13.91 31.26 14.34 30.84 C 14.76 30.41 15 29.84 15 29.25 L 15 6.75 C 15 6.15 14.76 5.58 14.34 5.15 C 13.91 4.73 13.34 4.5 12.75 4.5 Z M 26.25 4.5 L 23.25 4.5 C 22.65 4.5 22.08 4.73 21.65 5.15 C 21.23 5.58 21 6.15 21 6.75 V 29.25 C 21 29.84 21.23 30.41 21.65 30.84 C 22.08 31.26 22.65 31.5 23.25 31.5 L 26.25 31.5 C 26.84 31.5 27.41 31.26 27.84 30.84 C 28.26 30.41 28.5 29.84 28.5 29.25 V 6.75 L 28.5 6.75 C 28.5 6.15 28.26 5.58 27.84 5.15 C 27.41 4.73 26.84 4.5 26.25 4.5 Z" fill="white"></path></svg>''';
  static String get customPrev => r'''<svg xmlns="http://www.w3.org/2000/svg" fill="none" height="24" viewBox="0 0 24 24" width="24"><path d="M4 4C3.73 4 3.48 4.10 3.29 4.29C3.10 4.48 3 4.73 3 5V19C3 19.26 3.10 19.51 3.29 19.70C3.48 19.89 3.73 20 4 20C4.26 20 4.51 19.89 4.70 19.70C4.89 19.51 5 19.26 5 19V5C5 4.73 4.89 4.48 4.70 4.29C4.51 4.10 4.26 4 4 4ZM18.95 4.23L6 12.00L18.95 19.77C19.15 19.89 19.39 19.96 19.63 19.96C19.87 19.97 20.10 19.91 20.31 19.79C20.52 19.67 20.69 19.50 20.81 19.29C20.93 19.09 21.00 18.85 21 18.61V5.38C20.99 5.14 20.93 4.91 20.81 4.70C20.69 4.50 20.52 4.33 20.31 4.21C20.10 4.09 19.87 4.03 19.63 4.03C19.39 4.04 19.15 4.10 18.95 4.23Z" fill="white"></path></svg>''';
  static String get customNext => r'''<svg xmlns="http://www.w3.org/2000/svg" fill="none" height="24" viewBox="0 0 24 24" width="24"><path d="M20 20C20.26 20 20.51 19.89 20.70 19.70C20.89 19.51 21 19.26 21 19V5C21 4.73 20.89 4.48 20.70 4.29C20.51 4.10 20.26 4 20 4C19.73 4 19.48 4.10 19.29 4.29C19.10 4.48 19 4.73 19 5V19C19 19.26 19.10 19.51 19.29 19.70C19.48 19.89 19.73 20 20 20ZM5.04 19.77L18 12L5.04 4.22C4.84 4.10 4.60 4.03 4.36 4.03C4.12 4.03 3.89 4.09 3.68 4.21C3.47 4.32 3.30 4.49 3.18 4.70C3.06 4.91 2.99 5.14 3 5.38V18.61C2.99 18.85 3.06 19.08 3.18 19.29C3.30 19.50 3.47 19.67 3.68 19.79C3.89 19.90 4.12 19.96 4.36 19.96C4.60 19.96 4.84 19.89 5.04 19.77Z" fill="white"></path></svg>''';

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
  static String get pen => reiconSvg(Reicon.outline.pen);
  static String get penFilled => reiconSvg(Reicon.filled.pen);
  static String get edit => pen;
  static String get editFilled => penFilled;
  static String get transferH => reiconSvg(Reicon.outline.transferH);
  static String get transferHFilled => reiconSvg(Reicon.filled.transferH);
  static String get swap => transferH;
  static String get bookmarkOutline => reiconSvg(Reicon.outline.bookmark);
  static String get bookmark => bookmarkOutline;
  static String get bookmarkFilled => reiconSvg(Reicon.filled.bookmark);
  static String get bookmarkMinusFilled => reiconSvg(Reicon.filled.bookmarkMinus);
  static String get add => reiconSvg(Reicon.outline.add);
  static String get addCircleOutline => reiconSvg(Reicon.outline.addCircle);
  static String get addCircleFilled => reiconSvg(Reicon.filled.addCircle);
  static String get star => reiconSvg(Reicon.filled.star);
  static String get bell => reiconSvg(Reicon.outline.bell);
  static String get settings => reiconSvg(Reicon.outline.setting2);
  static String get setting => reiconSvg(Reicon.outline.setting2);
  static String get microphone => reiconSvg(Reicon.outline.microphone);
  static String get download => reiconSvg(Reicon.outline.download);
  static String get link => reiconSvg(Reicon.outline.link);
  static String get forwardRight => reiconSvg(Reicon.outline.forwardRight);
  static String get share => reiconSvg(Reicon.outline.forwardRight);
  static String get check => reiconSvg(Reicon.outline.tickCircle);
  static String get tickCircle => reiconSvg(Reicon.outline.tickCircle);
  static String get checkCircle => reiconSvg(Reicon.outline.tickCircle);
  static String get verify => reiconSvg(Reicon.outline.verify);
  static String get verified => reiconSvg(Reicon.outline.verify);
  static String get like => reiconSvg(Reicon.outline.like);
  static String get dislike => reiconSvg(Reicon.outline.dislike);
  static String get thumbUp => like;
  static String get thumbDown => dislike;

  // Sistema / TV D-Pad y Cierre
  static String get close => reiconSvg(Reicon.outline.x);
  static String get closeFilled => reiconSvg(Reicon.filled.x);
  static String get filter => reiconSvg(Reicon.outline.filter);
  static String get info => reiconSvg(Reicon.outline.infoCircle);
  static String get moreH => reiconSvg(Reicon.outline.moreH);
  static String get moreHFilled => reiconSvg(Reicon.filled.moreH);
  static String get chevronLeft => reiconSvg(Reicon.outline.chevronLeft);
  static String get chevronRight => reiconSvg(Reicon.outline.chevronRight);
  static String get chevronUp => reiconSvg(Reicon.outline.chevronUp);
  static String get chevronDown => reiconSvg(Reicon.outline.chevronDown);

  static String get library => reiconSvg(Reicon.outline.library);
}
