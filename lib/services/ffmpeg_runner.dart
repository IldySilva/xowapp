import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'ffmpeg_runner_stub.dart'
    if (dart.library.io) 'ffmpeg_runner_io.dart' as impl;

class FfmpegConfig {
  final String binary;
  final List<String> videoCodecArgs;

  const FfmpegConfig({
    required this.binary,
    required this.videoCodecArgs,
  });
}

class FfmpegRunResult {
  final int exitCode;
  final String stderr;

  const FfmpegRunResult({required this.exitCode, required this.stderr});

  bool get success => exitCode == 0;
}

/// Resolves ffmpeg binary + codec flags for the current OS.
Future<FfmpegConfig> resolveFfmpegConfig() async {
  if (kIsWeb) {
    throw UnsupportedError(
      'FFmpeg export is not available in the browser. Use the desktop app.',
    );
  }

  if (defaultTargetPlatform == TargetPlatform.macOS) {
    final candidates = [
      '/opt/homebrew/bin/ffmpeg',
      '/usr/local/bin/ffmpeg',
      'ffmpeg',
    ];
    final binary = await impl.firstExistingBinary(candidates) ?? 'ffmpeg';
    return FfmpegConfig(
      binary: binary,
      videoCodecArgs: const ['-c:v', 'h264_videotoolbox', '-allow_sw', '1'],
    );
  }

  // Linux / Windows: software x264 (or whatever ffmpeg provides as libx264).
  final candidates = [
    '/usr/bin/ffmpeg',
    '/usr/local/bin/ffmpeg',
    'ffmpeg',
  ];
  final binary = await impl.firstExistingBinary(candidates) ?? 'ffmpeg';
  return FfmpegConfig(
    binary: binary,
    videoCodecArgs: const ['-c:v', 'libx264', '-pix_fmt', 'yuv420p'],
  );
}

Future<FfmpegRunResult> runFfmpeg({
  required List<String> args,
  void Function(double progress)? onProgress,
  required double durationMicros,
}) async {
  return impl.runFfmpeg(
    args: args,
    onProgress: onProgress,
    durationMicros: durationMicros,
  );
}

/// Replaces macOS-only codec flags in an args list with the resolved config.
List<String> withPlatformCodec(List<String> args, FfmpegConfig config) {
  final out = <String>[];
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '-c:v' && i + 1 < args.length) {
      out.addAll(config.videoCodecArgs);
      // Skip original codec token (and optional -allow_sw pair later).
      i++;
      continue;
    }
    if (a == '-allow_sw') {
      // Drop macOS-only flag (+ value if present).
      if (i + 1 < args.length) i++;
      continue;
    }
    out.add(a);
  }
  return out;
}

double? parseFfmpegTimeProgress(String line, double durationMicros) {
  final timeRegex = RegExp(r'time=(\d+):(\d+):(\d+\.\d+)');
  final match = timeRegex.firstMatch(line);
  if (match == null || durationMicros <= 0) return null;
  final hours = int.parse(match.group(1)!);
  final minutes = int.parse(match.group(2)!);
  final seconds = double.parse(match.group(3)!);
  final currentMicros = (hours * 3600 + minutes * 60 + seconds) * 1000000;
  var p = currentMicros / durationMicros;
  if (p > 1.0) p = 1.0;
  return p;
}

String decodeUtf8(List<int> bytes) => utf8.decode(bytes, allowMalformed: true);
