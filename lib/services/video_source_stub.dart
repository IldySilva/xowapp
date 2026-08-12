import 'package:video_player/video_player.dart';

import 'video_source.dart';

VideoPlayerController createController(VideoSource source) {
  return VideoPlayerController.networkUrl(Uri.parse(source.pathOrUrl));
}

VideoPlayerController createFileController(String path) {
  return VideoPlayerController.networkUrl(Uri.parse(path));
}
