import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import 'video_source_stub.dart'
    if (dart.library.io) 'video_source_io.dart'
    if (dart.library.html) 'video_source_web.dart' as impl;

/// How the editor should open a video on the current platform.
class VideoSource {
  final String pathOrUrl;
  final bool isNetworkUrl;
  final List<int>? bytes;

  const VideoSource({
    required this.pathOrUrl,
    this.isNetworkUrl = false,
    this.bytes,
  });

  VideoPlayerController createController() =>
      impl.createController(this);
}

VideoPlayerController createFileController(String path) {
  if (kIsWeb) {
    return VideoPlayerController.networkUrl(Uri.parse(path));
  }
  return impl.createFileController(path);
}
