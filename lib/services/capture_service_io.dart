import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../src/messages.g.dart';
import 'app_paths.dart';
import 'capture_service.dart';

CaptureService createCaptureService() {
  if (isMacOSDesktop) return MacOSCaptureService();
  return DesktopImportCaptureService();
}

/// macOS: delegates to the existing Pigeon CaptureApi host.
class MacOSCaptureService implements CaptureService {
  final CaptureApi _api = CaptureApi();

  @override
  bool get supportsNativeCapture => true;

  @override
  bool get supportsBrowserCapture => false;

  @override
  Future<List<CaptureSource>> getAvailableSources() =>
      _api.getAvailableSources();

  @override
  Future<void> startCapture({
    required String sourceId,
    required int sourceType,
    required String outputPath,
  }) {
    return _api.startCapture(sourceId, sourceType, outputPath);
  }

  @override
  Future<String?> stopCapture() async {
    await _api.stopCapture();
    return AppPaths.findLatestXowcaseVideo();
  }

  @override
  Future<VideoPickResult?> importVideo() => _pickVideoFile();
}

/// Linux (and other desktops without a native host): import-only.
class DesktopImportCaptureService implements CaptureService {
  @override
  bool get supportsNativeCapture => false;

  @override
  bool get supportsBrowserCapture => false;

  @override
  Future<List<CaptureSource>> getAvailableSources() async {
    return [
      CaptureSource(
        id: 'import',
        name: 'Import a video file',
        type: 3,
      ),
      if (!kIsWeb)
        CaptureSource(
          id: 'hint',
          name: 'Native screen capture is available on macOS',
          type: 0,
        ),
    ];
  }

  @override
  Future<void> startCapture({
    required String sourceId,
    required int sourceType,
    required String outputPath,
  }) async {
    throw UnsupportedError(
      'Native screen capture is only available on macOS. Import a video instead.',
    );
  }

  @override
  Future<String?> stopCapture() async => null;

  @override
  Future<VideoPickResult?> importVideo() => _pickVideoFile();
}

Future<VideoPickResult?> _pickVideoFile() async {
  final result = await FilePicker.pickFiles(
    type: FileType.video,
    withData: false,
  );
  if (result == null || result.files.isEmpty) return null;
  final path = result.files.single.path;
  if (path == null || path.isEmpty) return null;
  return VideoPickResult(pathOrUrl: path);
}
