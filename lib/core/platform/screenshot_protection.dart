import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:screen_protector/screen_protector.dart';

/// Blocks screenshots and app-switcher previews for sensitive on-screen content.
abstract final class ScreenshotProtection {
  static Future<void> enable() async {
    if (kIsWeb) return;

    if (Platform.isAndroid) {
      await ScreenProtector.protectDataLeakageOn();
      return;
    }
    if (Platform.isIOS) {
      await ScreenProtector.preventScreenshotOn();
    }
  }

  static Future<void> disable() async {
    if (kIsWeb) return;

    await ScreenProtector.protectDataLeakageOff();
    await ScreenProtector.preventScreenshotOff();
  }
}
