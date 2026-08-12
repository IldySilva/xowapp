import 'dart:io';

import 'package:video_player/video_player.dart';

import 'video_source.dart';

VideoPlayerController createController(VideoSource source) {
  if (source.isNetworkUrl) {
    return VideoPlayerController.networkUrl(Uri.parse(source.pathOrUrl));
  }
  return VideoPlayerController.file(File(source.pathOrUrl));
}

VideoPlayerController createFileController(String path) {
  return VideoPlayerController.file(File(path));
}
