import 'package:reicon_flutter/reicon_flutter.dart';

class AurisIcons {
  AurisIcons._();

  // =========================================================================
  // CONSTANTES SVG OFICIALES (Reproductor YouTube Web / base.js)
  // =========================================================================
  static const String _ytPlay = r'''<svg xmlns="http://www.w3.org/2000/svg" fill="none" height="36" viewBox="0 0 36 36" width="36"><path d="M 17 8.6 L 10.89 4.99 C 9.39 4.11 7.5 5.19 7.5 6.93 L 7.5 29.06 C 7.5 30.8 9.39 31.88 10.89 31 L 17 27.4 L 17 8.6 Z M 17 8.6 V 27.4 L 33 18 L 17 8.6 Z" fill="white"/></svg>''';
  static const String _ytPause = r'''<svg xmlns="http://www.w3.org/2000/svg" fill="none" height="36" viewBox="0 0 36 36" width="36"><path d="M 12.75 4.5 L 9.75 4.5 C 9.15 4.5 8.58 4.73 8.15 5.15 C 7.73 5.58 7.5 6.15 7.5 6.75 L 7.5 29.25 C 7.5 29.84 7.73 30.41 8.15 30.84 C 8.58 31.26 9.15 31.5 9.75 31.5 L 12.75 31.5 C 13.34 31.5 13.91 31.26 14.34 30.84 C 14.76 30.41 15 29.84 15 29.25 L 15 6.75 C 15 6.15 14.76 5.58 14.34 5.15 C 13.91 4.73 13.34 4.5 12.75 4.5 Z M 26.25 4.5 L 23.25 4.5 C 22.65 4.5 22.08 4.73 21.65 5.15 C 21.23 5.58 21 6.15 21 6.75 V 29.25 C 21 29.84 21.23 30.41 21.65 30.84 C 22.08 31.26 22.65 31.5 23.25 31.5 L 26.25 31.5 C 26.84 31.5 27.41 31.26 27.84 30.84 C 28.26 30.41 28.5 29.84 28.5 29.25 V 6.75 L 28.5 6.75 C 28.5 6.15 28.26 5.58 27.84 5.15 C 27.41 4.73 26.84 4.5 26.25 4.5 Z" fill="white"/></svg>''';
  static const String _ytNext = r'''<svg xmlns="http://www.w3.org/2000/svg" fill="none" height="24" viewBox="0 0 24 24" width="24"><path d="M20 20C20.26 20 20.51 19.89 20.70 19.70C20.89 19.51 21 19.26 21 19V5C21 4.73 20.89 4.48 20.70 4.29C20.51 4.10 20.26 4 20 4C19.73 4 19.48 4.10 19.29 4.29C19.10 4.48 19 4.73 19 5V19C19 19.26 19.10 19.51 19.29 19.70C19.48 19.89 19.73 20 20 20ZM5.04 19.77L18 12L5.04 4.22C4.84 4.10 4.60 4.03 4.36 4.03C4.12 4.03 3.89 4.09 3.68 4.21C3.47 4.32 3.30 4.49 3.18 4.70C3.06 4.91 2.99 5.14 3 5.38V18.61C2.99 18.85 3.06 19.08 3.18 19.29C3.30 19.50 3.47 19.67 3.68 19.79C3.89 19.90 4.12 19.96 4.36 19.96C4.60 19.96 4.84 19.89 5.04 19.77Z" fill="white"/></svg>''';
  static const String _ytPrev = r'''<svg xmlns="http://www.w3.org/2000/svg" fill="none" height="24" viewBox="0 0 24 24" width="24"><path d="M4 4C3.73 4 3.48 4.10 3.29 4.29C3.10 4.48 3 4.73 3 5V19C3 19.26 3.10 19.51 3.29 19.70C3.48 19.89 3.73 20 4 20C4.26 20 4.51 19.89 4.70 19.70C4.89 19.51 5 19.26 5 19V5C5 4.73 4.89 4.48 4.70 4.29C4.51 4.10 4.26 4 4 4ZM18.95 4.23L6 12.00L18.95 19.77C19.15 19.89 19.39 19.96 19.63 19.96C19.87 19.97 20.10 19.91 20.31 19.79C20.52 19.67 20.69 19.50 20.81 19.29C20.93 19.09 21.00 18.85 21 18.61V5.38C20.99 5.14 20.93 4.91 20.81 4.70C20.69 4.50 20.52 4.33 20.31 4.21C20.10 4.09 19.87 4.03 19.63 4.03C19.39 4.04 19.15 4.10 18.95 4.23Z" fill="white"/></svg>''';
  static const String _ytReplay = r'''<svg xmlns="http://www.w3.org/2000/svg" height="36" viewBox="0 0 36 36" width="36"><path d="M 18,11 V 7 l -5,5 5,5 v -4 c 3.3,0 6,2.7 6,6 0,3.3 -2.7,6 -6,6 -3.3,0 -6,-2.7 -6,-6 h -2 c 0,4.4 3.6,8 8,8 4.4,0 8,-3.6 8,-8 0,-4.4 -3.6,-8 -8,-8 z" fill="white"/></svg>''';
  
  // Vector oficial de YouTube Player 24x24 (Speaker, Small Ripple, Big Ripple, Mute Cross)
  static const String ytVolumeSpeakerPath = r'''M 11.60 2.08 L 11.48 2.14 L 3.91 6.68 C 3.02 7.21 2.28 7.97 1.77 8.87 C 1.26 9.77 1.00 10.79 1 11.83 V 12.16 L 1.01 12.56 C 1.07 13.52 1.37 14.46 1.87 15.29 C 2.38 16.12 3.08 16.81 3.91 17.31 L 11.48 21.85 C 11.63 21.94 11.80 21.99 11.98 21.99 C 12.16 22.00 12.33 21.95 12.49 21.87 C 12.64 21.78 12.77 21.65 12.86 21.50 C 12.95 21.35 13 21.17 13 21 V 3 C 12.99 2.83 12.95 2.67 12.87 2.52 C 12.80 2.37 12.68 2.25 12.54 2.16 C 12.41 2.07 12.25 2.01 12.08 2.00 C 11.92 1.98 11.75 2.01 11.60 2.08 Z''';
  static const String ytVolumeSmallRipplePath = r'''M 15.53 7.05 C 15.35 7.22 15.25 7.45 15.24 7.70 C 15.23 7.95 15.31 8.19 15.46 8.38 L 15.53 8.46 L 15.70 8.64 C 16.09 9.06 16.39 9.55 16.61 10.08 L 16.70 10.31 C 16.90 10.85 17 11.42 17 12 L 16.99 12.24 C 16.96 12.73 16.87 13.22 16.70 13.68 L 16.61 13.91 C 16.36 14.51 15.99 15.07 15.53 15.53 C 15.35 15.72 15.25 15.97 15.26 16.23 C 15.26 16.49 15.37 16.74 15.55 16.92 C 15.73 17.11 15.98 17.21 16.24 17.22 C 16.50 17.22 16.76 17.12 16.95 16.95 C 17.6 16.29 18.11 15.52 18.46 14.67 L 18.59 14.35 C 18.82 13.71 18.95 13.03 18.99 12.34 L 19 12 C 18.99 11.19 18.86 10.39 18.59 9.64 L 18.46 9.32 C 18.15 8.57 17.72 7.89 17.18 7.3 L 16.95 7.05 L 16.87 6.98 C 16.68 6.82 16.43 6.74 16.19 6.75 C 15.94 6.77 15.71 6.87 15.53 7.05''';
  static const String ytVolumeBigRipplePath = r'''M 18.36 4.22 C 18.18 4.39 18.08 4.62 18.07 4.87 C 18.05 5.12 18.13 5.36 18.29 5.56 L 18.36 5.63 L 18.66 5.95 C 19.36 6.72 19.91 7.60 20.31 8.55 L 20.47 8.96 C 20.82 9.94 21 10.96 21 11.99 L 20.98 12.44 C 20.94 13.32 20.77 14.19 20.47 15.03 L 20.31 15.44 C 19.86 16.53 19.19 17.52 18.36 18.36 C 18.17 18.55 18.07 18.80 18.07 19.07 C 18.07 19.33 18.17 19.59 18.36 19.77 C 18.55 19.96 18.80 20.07 19.07 20.07 C 19.33 20.07 19.59 19.96 19.77 19.77 C 20.79 18.75 21.61 17.54 22.16 16.20 L 22.35 15.70 C 22.72 14.68 22.93 13.62 22.98 12.54 L 23 12 C 22.99 10.73 22.78 9.48 22.35 8.29 L 22.16 7.79 C 21.67 6.62 20.99 5.54 20.15 4.61 L 19.77 4.22 L 19.70 4.15 C 19.51 3.99 19.26 3.91 19.02 3.93 C 18.77 3.94 18.53 4.04 18.36 4.22 Z''';
  static const String ytVolumeMuteCrossPath = r'''M 21.41 12 L 23.71 9.71 C 24.1 9.32 24.1 8.68 23.71 8.29 C 23.32 7.9 22.68 7.9 22.29 8.29 L 20 10.59 L 17.71 8.29 C 17.32 7.9 16.68 7.9 16.29 8.29 C 15.9 8.68 15.9 9.32 16.29 9.71 L 18.59 12 L 16.29 14.29 C 15.9 14.68 15.9 15.32 16.29 15.71 C 16.68 16.1 17.32 16.1 17.71 15.71 L 20 13.41 L 22.29 15.71 C 22.68 16.1 23.32 16.1 23.71 15.71 C 24.1 15.32 24.1 14.68 23.71 14.29 Z''';

  static const String _ytVolumeHigh = r'''<svg xmlns="http://www.w3.org/2000/svg" height="24" viewBox="0 0 24 24" width="24"><path d="M 11.60 2.08 L 11.48 2.14 L 3.91 6.68 C 3.02 7.21 2.28 7.97 1.77 8.87 C 1.26 9.77 1.00 10.79 1 11.83 V 12.16 L 1.01 12.56 C 1.07 13.52 1.37 14.46 1.87 15.29 C 2.38 16.12 3.08 16.81 3.91 17.31 L 11.48 21.85 C 11.63 21.94 11.80 21.99 11.98 21.99 C 12.16 22.00 12.33 21.95 12.49 21.87 C 12.64 21.78 12.77 21.65 12.86 21.50 C 12.95 21.35 13 21.17 13 21 V 3 C 12.99 2.83 12.95 2.67 12.87 2.52 C 12.80 2.37 12.68 2.25 12.54 2.16 C 12.41 2.07 12.25 2.01 12.08 2.00 C 11.92 1.98 11.75 2.01 11.60 2.08 Z" fill="white"/><path d="M 15.53 7.05 C 15.35 7.22 15.25 7.45 15.24 7.70 C 15.23 7.95 15.31 8.19 15.46 8.38 L 15.53 8.46 L 15.70 8.64 C 16.09 9.06 16.39 9.55 16.61 10.08 L 16.70 10.31 C 16.90 10.85 17 11.42 17 12 L 16.99 12.24 C 16.96 12.73 16.87 13.22 16.70 13.68 L 16.61 13.91 C 16.36 14.51 15.99 15.07 15.53 15.53 C 15.35 15.72 15.25 15.97 15.26 16.23 C 15.26 16.49 15.37 16.74 15.55 16.92 C 15.73 17.11 15.98 17.21 16.24 17.22 C 16.50 17.22 16.76 17.12 16.95 16.95 C 17.6 16.29 18.11 15.52 18.46 14.67 L 18.59 14.35 C 18.82 13.71 18.95 13.03 18.99 12.34 L 19 12 C 18.99 11.19 18.86 10.39 18.59 9.64 L 18.46 9.32 C 18.15 8.57 17.72 7.89 17.18 7.3 L 16.95 7.05 L 16.87 6.98 C 16.68 6.82 16.43 6.74 16.19 6.75 C 15.94 6.77 15.71 6.87 15.53 7.05" fill="white"/><path d="M 18.36 4.22 C 18.18 4.39 18.08 4.62 18.07 4.87 C 18.05 5.12 18.13 5.36 18.29 5.56 L 18.36 5.63 L 18.66 5.95 C 19.36 6.72 19.91 7.60 20.31 8.55 L 20.47 8.96 C 20.82 9.94 21 10.96 21 11.99 L 20.98 12.44 C 20.94 13.32 20.77 14.19 20.47 15.03 L 20.31 15.44 C 19.86 16.53 19.19 17.52 18.36 18.36 C 18.17 18.55 18.07 18.80 18.07 19.07 C 18.07 19.33 18.17 19.59 18.36 19.77 C 18.55 19.96 18.80 20.07 19.07 20.07 C 19.33 20.07 19.59 19.96 19.77 19.77 C 20.79 18.75 21.61 17.54 22.16 16.20 L 22.35 15.70 C 22.72 14.68 22.93 13.62 22.98 12.54 L 23 12 C 22.99 10.73 22.78 9.48 22.35 8.29 L 22.16 7.79 C 21.67 6.62 20.99 5.54 20.15 4.61 L 19.77 4.22 L 19.70 4.15 C 19.51 3.99 19.26 3.91 19.02 3.93 C 18.77 3.94 18.53 4.04 18.36 4.22 Z" fill="white"/></svg>''';
  static const String _ytVolumeLow = r'''<svg xmlns="http://www.w3.org/2000/svg" height="24" viewBox="0 0 24 24" width="24"><path d="M 11.60 2.08 L 11.48 2.14 L 3.91 6.68 C 3.02 7.21 2.28 7.97 1.77 8.87 C 1.26 9.77 1.00 10.79 1 11.83 V 12.16 L 1.01 12.56 C 1.07 13.52 1.37 14.46 1.87 15.29 C 2.38 16.12 3.08 16.81 3.91 17.31 L 11.48 21.85 C 11.63 21.94 11.80 21.99 11.98 21.99 C 12.16 22.00 12.33 21.95 12.49 21.87 C 12.64 21.78 12.77 21.65 12.86 21.50 C 12.95 21.35 13 21.17 13 21 V 3 C 12.99 2.83 12.95 2.67 12.87 2.52 C 12.80 2.37 12.68 2.25 12.54 2.16 C 12.41 2.07 12.25 2.01 12.08 2.00 C 11.92 1.98 11.75 2.01 11.60 2.08 Z" fill="white"/><path d="M 15.53 7.05 C 15.35 7.22 15.25 7.45 15.24 7.70 C 15.23 7.95 15.31 8.19 15.46 8.38 L 15.53 8.46 L 15.70 8.64 C 16.09 9.06 16.39 9.55 16.61 10.08 L 16.70 10.31 C 16.90 10.85 17 11.42 17 12 L 16.99 12.24 C 16.96 12.73 16.87 13.22 16.70 13.68 L 16.61 13.91 C 16.36 14.51 15.99 15.07 15.53 15.53 C 15.35 15.72 15.25 15.97 15.26 16.23 C 15.26 16.49 15.37 16.74 15.55 16.92 C 15.73 17.11 15.98 17.21 16.24 17.22 C 16.50 17.22 16.76 17.12 16.95 16.95 C 17.6 16.29 18.11 15.52 18.46 14.67 L 18.59 14.35 C 18.82 13.71 18.95 13.03 18.99 12.34 L 19 12 C 18.99 11.19 18.86 10.39 18.59 9.64 L 18.46 9.32 C 18.15 8.57 17.72 7.89 17.18 7.3 L 16.95 7.05 L 16.87 6.98 C 16.68 6.82 16.43 6.74 16.19 6.75 C 15.94 6.77 15.71 6.87 15.53 7.05" fill="white"/></svg>''';
  static const String _ytVolumeMute = r'''<svg xmlns="http://www.w3.org/2000/svg" height="24" viewBox="0 0 24 24" width="24"><path d="M 11.60 2.08 L 11.48 2.14 L 3.91 6.68 C 3.02 7.21 2.28 7.97 1.77 8.87 C 1.26 9.77 1.00 10.79 1 11.83 V 12.16 L 1.01 12.56 C 1.07 13.52 1.37 14.46 1.87 15.29 C 2.38 16.12 3.08 16.81 3.91 17.31 L 11.48 21.85 C 11.63 21.94 11.80 21.99 11.98 21.99 C 12.16 22.00 12.33 21.95 12.49 21.87 C 12.64 21.78 12.77 21.65 12.86 21.50 C 12.95 21.35 13 21.17 13 21 V 3 C 12.99 2.83 12.95 2.67 12.87 2.52 C 12.80 2.37 12.68 2.25 12.54 2.16 C 12.41 2.07 12.25 2.01 12.08 2.00 C 11.92 1.98 11.75 2.01 11.60 2.08 Z" fill="white"/><path d="M 21.41 12 L 23.71 9.71 C 24.1 9.32 24.1 8.68 23.71 8.29 C 23.32 7.9 22.68 7.9 22.29 8.29 L 20 10.59 L 17.71 8.29 C 17.32 7.9 16.68 7.9 16.29 8.29 C 15.9 8.68 15.9 9.32 16.29 9.71 L 18.59 12 L 16.29 14.29 C 15.9 14.68 15.9 15.32 16.29 15.71 C 16.68 16.1 17.32 16.1 17.71 15.71 L 20 13.41 L 22.29 15.71 C 22.68 16.1 23.32 16.1 23.71 15.71 C 24.1 15.32 24.1 14.68 23.71 14.29 Z" fill="white"/></svg>''';
  static const String _ytFullscreenEnter = r'''<svg xmlns="http://www.w3.org/2000/svg" height="24" viewBox="0 0 24 24" width="24"><path d="M10 3H3V10C3 10.26 3.10 10.51 3.29 10.70C3.48 10.89 3.73 11 4 11C4.26 11 4.51 10.89 4.70 10.70C4.89 10.51 5 10.26 5 10V6.41L9.29 10.70L9.36 10.77C9.56 10.92 9.80 11.00 10.04 10.99C10.29 10.98 10.52 10.87 10.70 10.70C10.87 10.52 10.98 10.29 10.99 10.04C11.00 9.80 10.92 9.56 10.77 9.36L10.70 9.29L6.41 5H10C10.26 5 10.51 4.89 10.70 4.70C10.89 4.51 11 4.26 11 4C11 3.73 10.89 3.48 10.70 3.29C10.51 3.10 10.26 3 10 3ZM20 13C19.73 13 19.48 13.10 19.29 13.29C19.10 13.48 19 13.73 19 14V17.58L14.70 13.29L14.63 13.22C14.43 13.07 14.19 12.99 13.95 13.00C13.70 13.01 13.47 13.12 13.29 13.29C13.12 13.47 13.01 13.70 13.00 13.95C12.99 14.19 13.07 14.43 13.22 14.63L13.29 14.70L17.58 19H14C13.73 19 13.48 19.10 13.29 19.29C13.10 19.48 13 19.73 13 20C13 20.26 13.10 20.51 13.29 20.70C13.48 20.89 13.73 21 14 21H21V14C21 13.73 20.89 13.48 20.70 13.29C20.51 13.10 20.26 13 20 13Z" fill="white"/></svg>''';
  static const String _ytFullscreenExit = r'''<svg xmlns="http://www.w3.org/2000/svg" height="24" viewBox="0 0 24 24" width="24"><path d="M3.29 3.29C3.11 3.46 3.01 3.70 3.00 3.94C2.98 4.19 3.06 4.43 3.22 4.63L3.29 4.70L7.58 8.99H5C4.73 8.99 4.48 9.10 4.29 9.29C4.10 9.47 4 9.73 4 9.99C4 10.26 4.10 10.51 4.29 10.70C4.48 10.89 4.73 10.99 5 10.99H11V4.99C11 4.73 10.89 4.47 10.70 4.29C10.51 4.10 10.26 3.99 10 3.99C9.73 3.99 9.48 4.10 9.29 4.29C9.10 4.47 9 4.73 9 4.99V7.58L4.70 3.29L4.63 3.22C4.43 3.06 4.19 2.98 3.94 3.00C3.70 3.01 3.46 3.11 3.29 3.29ZM19 13H13V19C13 19.26 13.10 19.51 13.29 19.70C13.48 19.89 13.73 20 14 20C14.26 20 14.51 19.89 14.70 19.70C14.89 19.51 15 19.26 15 19V16.41L19.29 20.70L19.36 20.77C19.56 20.92 19.80 21.00 20.04 20.99C20.29 20.98 20.52 20.87 20.70 20.70C20.87 20.52 20.98 20.29 20.99 20.04C21.00 19.80 20.92 19.56 20.77 19.36L20.70 19.29L16.41 15H19C19.26 15 19.51 14.89 19.70 14.70C19.89 14.51 20 14.26 20 14C20 13.73 19.89 13.48 19.70 13.29C19.51 13.10 19.26 13 19 13Z" fill="white"/></svg>''';
  static const String _ytSettings = r'''<svg xmlns="http://www.w3.org/2000/svg" height="24" viewBox="0 0 24 24" width="24"><path d="M12.84 1H11.15C10.72 .99 10.30 1.14 9.95 1.40C9.60 1.66 9.35 2.02 9.23 2.44L9.19 2.61C9.11 3.00 8.96 3.38 8.73 3.71C8.51 4.04 8.22 4.33 7.89 4.55L7.75 4.64C7.37 4.85 6.96 4.98 6.53 5.02C6.11 5.06 5.68 5.01 5.27 4.87C4.86 4.73 4.42 4.73 4.00 4.86C3.59 5.00 3.23 5.26 2.99 5.62L2.89 5.77L2.05 7.23C1.82 7.63 1.73 8.10 1.81 8.55C1.88 9.01 2.12 9.43 2.47 9.73L2.58 9.84C3.15 10.39 3.50 11.15 3.50 12L3.49 12.16C3.47 12.56 3.37 12.95 3.19 13.31C3.01 13.67 2.77 13.99 2.47 14.26C2.12 14.56 1.88 14.98 1.81 15.43C1.73 15.89 1.82 16.36 2.05 16.76L2.89 18.22L2.99 18.37C3.24 18.73 3.59 18.99 4.01 19.13C4.42 19.26 4.86 19.26 5.27 19.12L5.42 19.07C5.81 18.96 6.21 18.93 6.61 18.98C7.01 19.03 7.40 19.15 7.75 19.36L7.89 19.44C8.22 19.66 8.51 19.95 8.73 20.28C8.96 20.61 9.11 20.99 9.19 21.38C9.28 21.84 9.52 22.24 9.88 22.54C10.24 22.83 10.69 23.00 11.15 23H12.84C13.30 23.00 13.75 22.83 14.11 22.54C14.47 22.24 14.71 21.84 14.80 21.38C14.89 20.96 15.06 20.56 15.31 20.21C15.55 19.86 15.88 19.57 16.25 19.36L16.39 19.28C16.75 19.10 17.14 18.99 17.54 18.96C17.94 18.94 18.34 18.99 18.72 19.12L18.89 19.17C19.31 19.27 19.75 19.24 20.15 19.07C20.55 18.90 20.88 18.60 21.10 18.23L21.95 16.76C22.18 16.36 22.26 15.89 22.19 15.43C22.11 14.98 21.88 14.56 21.53 14.26C21.23 13.99 20.98 13.67 20.80 13.31C20.63 12.95 20.52 12.56 20.50 12.16L20.50 12C20.50 11.57 20.59 11.14 20.77 10.75C20.94 10.36 21.20 10.01 21.53 9.73C21.88 9.43 22.11 9.01 22.19 8.55C22.26 8.10 22.18 7.63 21.95 7.23L21.10 5.76C20.88 5.39 20.55 5.09 20.15 4.92C19.76 4.75 19.31 4.72 18.89 4.82L18.72 4.87C18.34 5.00 17.94 5.05 17.54 5.03C17.14 5.00 16.75 4.89 16.4 4.71L16.25 4.63C15.88 4.42 15.56 4.13 15.31 3.78C15.06 3.43 14.89 3.03 14.80 2.61C14.71 2.15 14.47 1.74 14.11 1.45C13.75 1.16 13.30 .99 12.84 1ZM11.15 3H12.84C12.98 3.70 13.26 4.36 13.68 4.94C14.09 5.52 14.63 6.01 15.25 6.37C15.87 6.72 16.55 6.94 17.26 7.01C17.97 7.08 18.69 6.99 19.37 6.76L20.21 8.23C19.67 8.69 19.24 9.27 18.94 9.92C18.65 10.57 18.50 11.28 18.5 12C18.50 12.71 18.65 13.42 18.95 14.07C19.24 14.72 19.67 15.29 20.21 15.76L19.37 17.23C18.69 16.99 17.97 16.91 17.26 16.98C16.55 17.05 15.86 17.27 15.25 17.63C14.63 17.98 14.09 18.47 13.68 19.05C13.26 19.63 12.98 20.29 12.84 21H11.15C11.01 20.29 10.73 19.63 10.31 19.05C9.90 18.47 9.36 17.98 8.75 17.62C8.13 17.27 7.44 17.05 6.73 16.98C6.02 16.91 5.30 16.99 4.62 17.23L3.78 15.76C4.32 15.29 4.75 14.71 5.05 14.06C5.34 13.41 5.49 12.71 5.5 12C5.50 11.28 5.34 10.57 5.05 9.92C4.75 9.27 4.32 8.69 3.78 8.23L4.62 6.76C5.30 7.00 6.02 7.08 6.73 7.01C7.44 6.94 8.13 6.72 8.75 6.37C9.36 6.01 9.90 5.52 10.31 4.94C10.73 4.36 11.01 3.70 11.15 3ZM12.00 8C10.94 8 9.92 8.42 9.17 9.17C8.42 9.92 8.00 10.93 8.00 12C8.00 13.06 8.42 14.07 9.17 14.82C9.92 15.57 10.94 16 12.00 16C13.06 16 14.08 15.57 14.83 14.82C15.58 14.07 16.00 13.06 16.00 12C16.00 10.93 15.58 9.92 14.83 9.17C14.08 8.42 13.06 8 12.00 8ZM12.00 10H12L12.20 10.01C12.69 10.06 13.15 10.29 13.48 10.65C13.81 11.02 14.00 11.50 14 12L13.99 12.20C13.95 12.58 13.80 12.95 13.55 13.25C13.31 13.55 12.98 13.78 12.62 13.90C12.25 14.02 11.85 14.03 11.48 13.93C11.11 13.83 10.77 13.62 10.51 13.34C10.25 13.05 10.08 12.69 10.02 12.31C9.96 11.93 10.01 11.54 10.17 11.18C10.32 10.83 10.58 10.53 10.91 10.32C11.23 10.11 11.61 10.00 12 10" fill="white"/></svg>''';
  static const String _ytSubtitles = r'''<svg xmlns="http://www.w3.org/2000/svg" height="24" viewBox="0 0 24 24" width="24"><path d="M21.20 3.01L21 3H3L2.79 3.01C2.30 3.06 1.84 3.29 1.51 3.65C1.18 4.02 .99 4.50 1 5V19L1.01 19.20C1.05 19.66 1.26 20.08 1.58 20.41C1.91 20.73 2.33 20.94 2.79 20.99L3 21H21L21.20 20.98C21.66 20.94 22.08 20.73 22.41 20.41C22.73 20.08 22.94 19.66 22.99 19.20L23 19V5C23.00 4.50 22.81 4.02 22.48 3.65C22.15 3.29 21.69 3.06 21.20 3.01ZM3 19V5H21V19H3ZM8 11H6C5.73 11 5.48 11.10 5.29 11.29C5.10 11.48 5 11.73 5 12C5 12.26 5.10 12.51 5.29 12.70C5.48 12.89 5.73 13 6 13H8C8.26 13 8.51 12.89 8.70 12.70C8.89 12.51 9 12.26 9 12C9 11.73 8.89 11.48 8.70 11.29C8.51 11.10 8.26 11 8 11ZM18 11H12C11.73 11 11.48 11.10 11.29 11.29C11.10 11.48 11 11.73 11 12C11 12.26 11.10 12.51 11.29 12.70C11.48 12.89 11.73 13 12 13H18C18.26 13 18.51 12.89 18.70 12.70C18.89 12.51 19 12.26 19 12C19 11.73 18.89 11.48 18.70 11.29C18.51 11.10 18.26 11 18 11ZM18 15H16C15.73 15 15.48 15.10 15.29 15.29C15.10 15.48 15 15.73 15 16C15 16.26 15.10 16.51 15.29 16.70C15.48 16.89 15.73 17 16 17H18C18.26 17 18.51 16.89 18.70 16.70C18.89 16.51 19 16.26 19 16C19 15.73 18.89 15.48 18.70 15.29C18.51 15.10 18.26 15 18 15ZM12 15H6C5.73 15 5.48 15.10 5.29 15.29C5.10 15.48 5 15.73 5 16C5 16.26 5.10 16.51 5.29 16.70C5.48 16.89 5.73 17 6 17H12C12.26 17 12.51 16.89 12.70 16.70C12.89 16.51 13 16.26 13 16C13 15.73 12.89 15.48 12.70 15.29C12.51 15.10 12.26 15 12 15Z" fill="white"/></svg>''';
  static const String _ytMiniplayer = r'''<svg xmlns="http://www.w3.org/2000/svg" height="36" viewBox="0 0 36 36" width="36"><path d="M25,17 L17,17 L17,23 L25,23 L25,17 L25,17 Z M29,25 L29,10.98 C29,9.88 28.1,9 27,9 L9,9 C7.9,9 7,9.88 7,10.98 L7,25 C7,26.1 7.9,27 9,27 L27,27 C28.1,27 29,26.1 29,25 L29,25 Z M27,25.02 L9,25.02 L9,10.97 L27,10.97 L27,25.02 L27,25.02 Z" fill="white"/></svg>''';
  static const String _ytTheaterMode = r'''<svg xmlns="http://www.w3.org/2000/svg" height="24" viewBox="0 0 24 24" width="24"><path d="M21.20 3.01L21 3H3L2.79 3.01C2.30 3.06 1.84 3.29 1.51 3.65C1.18 4.02 .99 4.50 1 5V19L1.01 19.20C1.05 19.66 1.26 20.08 1.58 20.41C1.91 20.73 2.33 20.94 2.79 20.99L3 21H21L21.20 20.98C21.66 20.94 22.08 20.73 22.41 20.41C22.73 20.08 22.94 19.66 22.99 19.20L23 19V5C23.00 4.50 22.81 4.02 22.48 3.65C22.15 3.29 21.69 3.06 21.20 3.01ZM3 15V5H21V15H3ZM7.87 6.72L7.79 6.79L4.58 10L7.79 13.20C7.88 13.30 7.99 13.37 8.11 13.43C8.23 13.48 8.37 13.51 8.50 13.51C8.63 13.51 8.76 13.48 8.89 13.43C9.01 13.38 9.12 13.31 9.21 13.21C9.31 13.12 9.38 13.01 9.43 12.89C9.48 12.76 9.51 12.63 9.51 12.50C9.51 12.37 9.48 12.23 9.43 12.11C9.37 11.99 9.30 11.88 9.20 11.79L7.41 10L9.20 8.20L9.27 8.13C9.42 7.93 9.50 7.69 9.48 7.45C9.47 7.20 9.36 6.97 9.19 6.80C9.02 6.63 8.79 6.52 8.54 6.51C8.30 6.49 8.06 6.57 7.87 6.72ZM14.79 6.79C14.60 6.98 14.50 7.23 14.50 7.5C14.50 7.76 14.60 8.01 14.79 8.20L16.58 10L14.79 11.79L14.72 11.86C14.57 12.06 14.49 12.30 14.50 12.54C14.51 12.79 14.62 13.02 14.79 13.20C14.97 13.37 15.20 13.48 15.45 13.49C15.69 13.50 15.93 13.42 16.13 13.27L16.20 13.20L19.41 10L16.20 6.79C16.01 6.60 15.76 6.50 15.5 6.50C15.23 6.50 14.98 6.60 14.79 6.79ZM3 19V17H21V19H3Z" fill="white"/></svg>''';
  static const String _ytAmbientMode = r'''<svg xmlns="http://www.w3.org/2000/svg" height="24" viewBox="0 0 24 24" width="24"><path d="M12 .5C11.73 .5 11.48 .60 11.29 .79C11.10 .98 11 1.23 11 1.5V3.5C11 3.76 11.10 4.01 11.29 4.20C11.48 4.39 11.73 4.5 12 4.5C12.26 4.5 12.51 4.39 12.70 4.20C12.89 4.01 13 3.76 13 3.5V1.5C13 1.23 12.89 .98 12.70 .79C12.51 .60 12.26 .5 12 .5ZM3.79 1.29C3.61 1.46 3.51 1.70 3.50 1.94C3.48 2.19 3.56 2.43 3.72 2.63L3.79 2.70L5.29 4.20L5.37 4.27C5.56 4.42 5.80 4.50 6.04 4.49C6.29 4.47 6.52 4.37 6.70 4.20C6.87 4.02 6.97 3.79 6.99 3.54C7.00 3.30 6.92 3.06 6.77 2.86L6.70 2.79L5.20 1.29L5.13 1.22C4.93 1.06 4.69 .98 4.44 1.00C4.20 1.01 3.96 1.11 3.79 1.29ZM18.86 1.22L18.79 1.29L17.29 2.79L17.22 2.86C17.07 3.06 16.99 3.30 17.00 3.54C17.01 3.79 17.12 4.02 17.29 4.20C17.47 4.37 17.70 4.48 17.95 4.49C18.19 4.50 18.43 4.42 18.63 4.27L18.70 4.20L20.20 2.70L20.27 2.63C20.42 2.43 20.50 2.19 20.49 1.95C20.48 1.70 20.37 1.47 20.20 1.29C20.02 1.12 19.79 1.01 19.54 1.00C19.30 .99 19.06 1.07 18.86 1.22ZM19.20 6.01L19 6H5L4.79 6.01C4.30 6.06 3.84 6.29 3.51 6.65C3.18 7.02 2.99 7.50 3 8V16L3.01 16.20C3.05 16.66 3.26 17.08 3.58 17.41C3.91 17.73 4.33 17.94 4.79 17.99L5 18H19L19.20 17.98C19.66 17.94 20.08 17.73 20.41 17.41C20.73 17.08 20.94 16.66 20.99 16.20L21 16V8C20.99 7.50 20.81 7.02 20.48 6.66C20.15 6.29 19.69 6.06 19.20 6.01ZM5 16V8H19V16H5ZM17.29 19.79C17.11 19.96 17.01 20.20 17.00 20.44C16.98 20.69 17.06 20.93 17.22 21.13L17.29 21.20L18.79 22.70L18.86 22.77C19.06 22.92 19.30 23.00 19.54 22.99C19.79 22.98 20.02 22.87 20.20 22.70C20.37 22.52 20.48 22.29 20.49 22.04C20.50 21.80 20.42 21.56 20.27 21.36L20.20 21.29L18.70 19.79L18.63 19.72C18.43 19.56 18.19 19.48 17.94 19.50C17.70 19.51 17.46 19.61 17.29 19.79ZM5.37 19.72L5.29 19.79L3.79 21.29L3.72 21.36C3.57 21.56 3.49 21.80 3.50 22.04C3.51 22.29 3.62 22.52 3.79 22.70C3.97 22.87 4.20 22.98 4.45 22.99C4.69 23.00 4.93 22.92 5.13 22.77L5.20 22.70L6.70 21.20L6.77 21.13C6.92 20.93 7.00 20.69 6.99 20.45C6.97 20.20 6.87 19.97 6.70 19.79C6.52 19.62 6.29 19.52 6.04 19.50C5.80 19.49 5.56 19.57 5.37 19.72ZM12 19.5C11.73 19.5 11.48 19.60 11.29 19.79C11.10 19.98 11 20.23 11 20.5V22.5C11 22.76 11.10 23.01 11.29 23.20C11.48 23.39 11.73 23.5 12 23.5C12.26 23.5 12.51 23.39 12.70 23.20C12.89 23.01 13 22.76 13 22.5V20.5C13 20.23 12.89 19.98 12.70 19.79C12.51 19.60 12.26 19.5 12 19.5Z" fill="white"/></svg>''';
  static const String _ytSleepTimer = r'''<svg xmlns="http://www.w3.org/2000/svg" height="24" viewBox="0 0 24 24" width="24"><path d="M12.33 1.00C12.22 1.00 12.11 1.00 12 1C5.92 1 1 5.92 1 12C1 18.07 5.92 23 12 23C13.90 23.00 15.78 22.50 17.44 21.55C19.10 20.61 20.48 19.25 21.46 17.61L21.64 17.29C22.06 16.52 21.21 15.73 20.35 15.88C18.76 16.15 17.12 15.94 15.66 15.27C14.19 14.59 12.97 13.49 12.14 12.11C11.31 10.73 10.91 9.13 11.01 7.52C11.11 5.91 11.69 4.37 12.67 3.09L12.89 2.83C13.45 2.16 13.20 1.03 12.33 1.00ZM15.56 2.60C15.45 2.84 15.43 3.11 15.51 3.36C15.59 3.61 15.77 3.82 16.01 3.94C16.91 4.39 17.73 4.99 18.44 5.71L18.73 6.03L18.80 6.10C18.99 6.27 19.22 6.36 19.47 6.37C19.72 6.37 19.96 6.28 20.15 6.12C20.33 5.95 20.45 5.72 20.48 5.48C20.51 5.23 20.44 4.98 20.29 4.78L20.23 4.70L19.87 4.31C19.01 3.43 18.01 2.70 16.90 2.15C16.67 2.03 16.39 2.01 16.14 2.10C15.89 2.18 15.68 2.36 15.56 2.60M10.24 3.17C9.42 4.64 8.99 6.31 9 8C9 13.42 13.32 17.84 18.71 17.99C17.86 18.93 16.83 19.69 15.67 20.21C14.52 20.73 13.26 21.00 12 21C9.76 21.00 7.60 20.17 5.95 18.67C4.29 17.17 3.25 15.10 3.03 12.88C2.81 10.65 3.43 8.43 4.76 6.63C6.09 4.84 8.05 3.60 10.24 3.17M21.16 7.88C20.93 7.96 20.73 8.12 20.61 8.34C20.49 8.55 20.45 8.81 20.50 9.05L20.53 9.15L20.66 9.56C20.93 10.53 21.04 11.54 20.98 12.55C20.97 12.81 21.06 13.06 21.23 13.26C21.41 13.45 21.65 13.57 21.92 13.59C22.18 13.60 22.44 13.52 22.63 13.34C22.83 13.17 22.95 12.93 22.97 12.67C23.05 11.44 22.92 10.20 22.58 9.02L22.43 8.51L22.39 8.42C22.29 8.19 22.11 8.01 21.88 7.91C21.65 7.81 21.40 7.80 21.16 7.88Z" fill="white"/></svg>''';
  static const String _ytPlaybackSpeed = r'''<svg xmlns="http://www.w3.org/2000/svg" height="24" viewBox="0 0 24 24" width="24"><path d="M12 1c1.44 0 2.87.28 4.21.83a11 11 0 0 1 3.45 2.27l-1.81 1.05A9 9 0 0 0 3 12a9 9 0 0 0 18-.00l-.01-.44a8.99 8.99 0 0 0-.14-1.20l1.81-1.05A11.00 11.00 0 0 1 10.51 22.9 11 11 0 0 1 12 1Zm7.08 6.25-7.96 3.25a1.74 1.74 0 1 0 1.73 2.99l6.8-5.26a.57.57 0 0 0-.56-.98Z" fill="white"/></svg>''';

  // =========================================================================
  // REPRODUCCIÓN, TRÁILER, EPISODIOS Y CONTROL (Estilo YouTube Player)
  // =========================================================================
  static String get play => _ytPlay;
  static String get playFilled => _ytPlay;
  static String get play3 => _ytPlay;
  static String get play3Filled => _ytPlay;
  static String get playCircleFilled => _ytPlay;
  static String get pause => _ytPause;
  static String get pauseFilled => _ytPause;
  static String get restart => _ytReplay;
  static String get repeat => _ytReplay;
  static String get rotateLeft => _ytReplay;
  static String get ytReplay => _ytReplay;

  static String get forwardStep => _ytNext;
  static String get backwardStep => _ytPrev;
  static String get skipNext => _ytNext;
  static String get skipPrev => _ytPrev;

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
  static String get fastForward => reiconSvg(Reicon.outline.fastForward);
  static String get fastForwardFilled => reiconSvg(Reicon.filled.fastForward);
  static String get trailer => reiconSvg(Reicon.outline.videoPlayH);
  static String get trailerFilled => reiconSvg(Reicon.filled.videoPlayH);
  static String get videoLib => reiconSvg(Reicon.outline.videoLib);
  static String get episodes => r'''<svg xmlns="http://w3.org" viewBox="0 0 24 24" width="24" height="24"><path d="M21 10a1 1 0 011 1v9a1 1 0 01-1 1H3a1 1 0 01-1-1v-9a1 1 0 011-1h18zm-1 2H4v7h16v-7zm0-5a1 1 0 010 2H4a1 1 0 110-2h16zm-2-3a1 1 0 010 2H6a1 1 0 110-2h12z" fill="white"/></svg>''';
  static String get episodesFilled => episodes;
  static String get docText => reiconSvg(Reicon.outline.docText);
  static String get docTextFilled => reiconSvg(Reicon.filled.docText);
  static String get server => reiconSvg(Reicon.outline.ssd2);
  static String get subtitles => _ytSubtitles;
  static String get language => _ytSubtitles;
  static String get audioLanguage => _ytSubtitles;
  static String get backward10 => reiconSvg(Reicon.outline.backward10Seconds);
  static String get forward10 => reiconSvg(Reicon.outline.forward10Seconds);
  static String get backward10Seconds => reiconSvg(Reicon.outline.backward10Seconds);
  static String get forward10Seconds => reiconSvg(Reicon.outline.forward10Seconds);
  
  // =========================================================================
  // VOLUMEN Y AUDIO (Estilo YouTube Player)
  // =========================================================================
  static String get volumeHigh => _ytVolumeHigh;
  static String get volumeDown => _ytVolumeLow;
  static String get volumeCross => _ytVolumeMute;
  static String get volumeUp => _ytVolumeHigh;
  static String get volumeMute => _ytVolumeMute;
  static String get mute => _ytVolumeMute;
  static String get bolt => reiconSvg(Reicon.outline.bolt);
  static String get boltFilled => reiconSvg(Reicon.filled.bolt);

  static String get speedometer => _ytPlaybackSpeed;
  static String get speed => _ytPlaybackSpeed;
  static String get playbackSpeed => _ytPlaybackSpeed;
  static String get flash => reiconSvg(Reicon.outline.flash);
  static String get theaterMode => _ytTheaterMode;
  static String get cinemaMode => _ytTheaterMode;
  static String get ambientLighting => _ytAmbientMode;
  static String get ambientMode => _ytAmbientMode;
  static String get sleepTimer => _ytSleepTimer;
  static String get sleep => _ytSleepTimer;

  // =========================================================================
  // PIP, PANTALLA COMPLETA Y AJUSTES (Estilo YouTube Player)
  // =========================================================================
  static String get toPip => reiconSvg(Reicon.outline.toPip);
  static String get exitPip => reiconSvg(Reicon.outline.exitPip);
  static String get miniplayer => _ytMiniplayer;
  static String get expand => _ytFullscreenEnter;
  static String get exitFullscreen => _ytFullscreenExit;
  static String get compress => _ytFullscreenExit;
  static String get maximize => _ytFullscreenEnter;
  static String get maximizeFilled => _ytFullscreenEnter;
  static String get expandFilled => _ytFullscreenEnter;

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
  static String get minimize => reiconSvg(Reicon.outline.minimize);
  static String get zoomIn => reiconSvg(Reicon.outline.searchZoomIn);

  // Aliases personalizados previos mantenidos por retrocompatibilidad
  static String get expandir => _ytTheaterMode;
  static String get customFullscreen => _ytFullscreenEnter;
  static String get customVolume => _ytVolumeHigh;
  static String get customPlay => _ytPlay;
  static String get customPause => _ytPause;
  static String get customPrev => _ytPrev;
  static String get customNext => _ytNext;

  // =========================================================================
  // NAVEGACIÓN (Outline / Filled para Navbar)
  // =========================================================================
  static String get homeOutline => reiconSvg(Reicon.outline.home6);
  static String get homeFilled => reiconSvg(Reicon.filled.home6);
  static String get searchOutline => reiconSvg(Reicon.outline.search);
  static String get searchFilled => reiconSvg(Reicon.filled.search);
  static String get compassOutline => reiconSvg(Reicon.outline.compass);
  static String get compassFilled => reiconSvg(Reicon.filled.compass);
  static String get userOutline => reiconSvg(Reicon.outline.user);
  static String get userFilled => reiconSvg(Reicon.filled.user);

  static String get home => homeOutline;
  static String get search => searchOutline;
  static String get compass => compassOutline;
  static String get user => userOutline;
  static String get grid => reiconSvg(Reicon.outline.grid);

  // =========================================================================
  // USUARIO, FAVORITOS Y ACCIONES
  // =========================================================================
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
  static String get settings => _ytSettings;
  static String get setting => _ytSettings;
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

  // =========================================================================
  // SISTEMA / TV D-PAD Y CIERRE
  // =========================================================================
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
