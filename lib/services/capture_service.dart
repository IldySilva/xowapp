import 'package:flutter/foundation.dart';

import '../src/messages.g.dart';
import 'capture_service_stub.dart'
    if (dart.library.io) 'capture_service_io.dart'
    if (dart.library.html) 'capture_service_web.dart' as impl;

/// Cross-platform capture / import facade.
abstract class CaptureService {
  static CaptureService create() => impl.createCaptureService();

  /// True when OS-level screen/window capture is available (macOS today).
  bool get supportsNativeCapture;

  /// True when the browser can record the display (web).
  bool get supportsBrowserCapture;

  Future<List<CaptureSource>> getAvailableSources();

  Future<void> startCapture({
    required String sourceId,
    required int sourceType,
    required String outputPath,
  });

  Future<String?> stopCapture();

  /// Pick a local video file. Returns a playable path/URL for the editor.
  Future<VideoPickResult?> importVideo();
}

class VideoPickResult {
  final String pathOrUrl;
  final bool isNetworkUrl;
  final List<int>? bytes;

  const VideoPickResult({
    required this.pathOrUrl,
    this.isNetworkUrl = false,
    this.bytes,
  });

  CaptureSource get asSource => CaptureSource(
        id: 'imported',
        name: 'Imported video',
        type: 3,
      );
}

bool get isMacOSDesktop =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

bool get isLinuxDesktop =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
