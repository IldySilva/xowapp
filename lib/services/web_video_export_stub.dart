import 'dart:typed_data';

import 'web_video_export.dart';

Future<Uint8List> exportComposedWebVideo({
  required String videoUrl,
  required WebExportLayout layout,
  void Function(double progress)? onProgress,
}) async {
  throw UnsupportedError('Web composed export is only available in the browser');
}
