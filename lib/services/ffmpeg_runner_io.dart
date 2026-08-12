import 'dart:convert';
import 'dart:io';

import 'ffmpeg_runner.dart';

Future<String?> firstExistingBinary(List<String> candidates) async {
  for (final c in candidates) {
    if (c == 'ffmpeg') {
      final result = await Process.run('which', ['ffmpeg']);
      if (result.exitCode == 0) {
        final path = (result.stdout as String).trim();
        if (path.isNotEmpty) return path;
      }
      continue;
    }
    if (await File(c).exists()) return c;
  }
  return null;
}

Future<FfmpegRunResult> runFfmpeg({
  required List<String> args,
  void Function(double progress)? onProgress,
  required double durationMicros,
}) async {
  final config = await resolveFfmpegConfig();
  final finalArgs = withPlatformCodec(args, config);
  // Ensure binary is first arg via Process.start(binary, argsWithoutBinary)
  // Callers pass full ffmpeg argv without the binary.
  final process = await Process.start(config.binary, finalArgs);
  final errBuf = StringBuffer();

  process.stderr.transform(utf8.decoder).listen((line) {
    errBuf.write(line);
    final p = parseFfmpegTimeProgress(line, durationMicros);
    if (p != null) onProgress?.call(p);
  });

  final exitCode = await process.exitCode;
  return FfmpegRunResult(exitCode: exitCode, stderr: errBuf.toString());
}
