import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Window chrome helpers. Real resizing/dragging only works on macOS native host.
class WindowService {
  WindowService._();

  static const MethodChannel _channel = MethodChannel('app.xowcase/window');

  static bool get isDesktopNative =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows);

  static Future<void> setSize({
    required double width,
    required double height,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;
    try {
      await _channel.invokeMethod('setSize', {
        'width': width,
        'height': height,
      });
    } catch (_) {
      // Host may not implement the channel (Linux/web).
    }
  }

  static Future<void> startDragging() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;
    try {
      await _channel.invokeMethod('startDragging');
    } catch (_) {}
  }
}
