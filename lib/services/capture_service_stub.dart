import 'package:file_picker/file_picker.dart';

import '../src/messages.g.dart';
import 'capture_service.dart';

CaptureService createCaptureService() => StubCaptureService();

class StubCaptureService implements CaptureService {
  @override
  bool get supportsNativeCapture => false;

  @override
  bool get supportsBrowserCapture => false;

  @override
  Future<List<CaptureSource>> getAvailableSources() async => [];

  @override
  Future<void> startCapture({
    required String sourceId,
    required int sourceType,
    required String outputPath,
  }) async {
    throw UnsupportedError('Screen capture is not available on this platform');
  }

  @override
  Future<String?> stopCapture() async => null;

  @override
  Future<VideoPickResult?> importVideo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.video,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    if (file.path != null && file.path!.isNotEmpty) {
      return VideoPickResult(pathOrUrl: file.path!);
    }
    if (file.bytes != null) {
      return VideoPickResult(
        pathOrUrl: file.name,
        isNetworkUrl: true,
        bytes: file.bytes,
      );
    }
    return null;
  }
}
