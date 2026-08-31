import 'dart:async';
import 'package:fullscreen_window/fullscreen_window.dart';
import 'package:flutter/services.dart';

Future<void> setAppFullscreenImpl(bool fullscreen) async {
  try {
    await FullScreenWindow.setFullScreen(fullscreen);
  } catch (_) {}
}

bool isAppFullscreenImpl() {
  return false;
}

Future<void> lockAppOrientationImpl() async {
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
}

Future<void> unlockAppOrientationImpl() async {
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
}

Stream<void>? onFullscreenChangedImpl() => null;
