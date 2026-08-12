import 'ffmpeg_runner.dart';

Future<String?> firstExistingBinary(List<String> candidates) async => null;

Future<FfmpegRunResult> runFfmpeg({
  required List<String> args,
  void Function(double progress)? onProgress,
  required double durationMicros,
}) async {
  throw UnsupportedError('FFmpeg is not available on this platform');
}
