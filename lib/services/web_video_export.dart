import 'dart:typed_data';
import 'dart:ui' show Color;

import 'web_video_export_stub.dart'
    if (dart.library.html) 'web_video_export_web.dart' as impl;

class WebExportLayout {
  final int canvasW;
  final int canvasH;
  final Color backgroundColor;
  final List<Color>? backgroundGradient;
  final String? frameAssetPath;
  final Uint8List? framePngBytes;
  final Map<String, dynamic>? frameBounds;
  final double padding;
  final double cropTop;
  final double cropBottom;
  final double cropLeft;
  final double cropRight;
  final double borderRadius;
  final double shadowOpacity;
  final double shadowBlur;
  final bool frameless;

  const WebExportLayout({
    required this.canvasW,
    required this.canvasH,
    required this.backgroundColor,
    required this.backgroundGradient,
    required this.frameAssetPath,
    required this.framePngBytes,
    required this.frameBounds,
    required this.padding,
    required this.cropTop,
    required this.cropBottom,
    required this.cropLeft,
    required this.cropRight,
    required this.borderRadius,
    required this.shadowOpacity,
    required this.shadowBlur,
    required this.frameless,
  });
}

/// Composites video + background + device frame in the browser and returns WebM bytes.
Future<Uint8List> exportComposedWebVideo({
  required String videoUrl,
  required WebExportLayout layout,
  void Function(double progress)? onProgress,
}) {
  return impl.exportComposedWebVideo(
    videoUrl: videoUrl,
    layout: layout,
    onProgress: onProgress,
  );
}
