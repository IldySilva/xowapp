import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:web/web.dart' as web;

import '../src/messages.g.dart';
import 'capture_service.dart';

CaptureService createCaptureService() => WebCaptureService();

class WebCaptureService implements CaptureService {
  web.MediaRecorder? _recorder;
  web.MediaStream? _stream;
  final List<web.Blob> _chunks = [];
  Completer<String?>? _stopCompleter;
  String? _objectUrl;

  @override
  bool get supportsNativeCapture => false;

  @override
  bool get supportsBrowserCapture => true;

  @override
  Future<List<CaptureSource>> getAvailableSources() async {
    return [
      CaptureSource(
        id: 'display',
        name: 'Browser screen / window',
        type: 0,
      ),
      CaptureSource(
        id: 'import',
        name: 'Import a video file',
        type: 3,
      ),
    ];
  }

  @override
  Future<void> startCapture({
    required String sourceId,
    required int sourceType,
    required String outputPath,
  }) async {
    if (sourceType == 3 || sourceId == 'import') {
      throw StateError('Use importVideo() for imported files');
    }

    final mediaDevices = web.window.navigator.mediaDevices;
    final stream = await mediaDevices
        .getDisplayMedia(
          web.DisplayMediaStreamOptions(video: true.toJS, audio: true.toJS),
        )
        .toDart;

    _stream = stream;
    _chunks.clear();
    _stopCompleter = Completer<String?>();

    final mime = _preferredMimeType();
    final recorder = mime != null
        ? web.MediaRecorder(
            stream,
            web.MediaRecorderOptions(mimeType: mime),
          )
        : web.MediaRecorder(stream);

    _recorder = recorder;

    recorder.ondataavailable = ((web.Event event) {
      final blobEvent = event as web.BlobEvent;
      final data = blobEvent.data;
      if (data.size > 0) {
        _chunks.add(data);
      }
    }).toJS;

    recorder.onstop = ((web.Event _) {
      _finalizeRecording();
    }).toJS;

    recorder.start(250);
  }

  @override
  Future<String?> stopCapture() async {
    final recorder = _recorder;
    final completer = _stopCompleter;
    if (recorder == null || completer == null) return null;

    if (recorder.state != 'inactive') {
      recorder.stop();
    }

    final stream = _stream;
    if (stream != null) {
      final tracks = stream.getTracks().toDart;
      for (final track in tracks) {
        track.stop();
      }
    }
    _stream = null;
    _recorder = null;

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => null,
    );
  }

  void _finalizeRecording() {
    final completer = _stopCompleter;
    if (completer == null || completer.isCompleted) return;

    if (_objectUrl != null) {
      web.URL.revokeObjectURL(_objectUrl!);
      _objectUrl = null;
    }

    if (_chunks.isEmpty) {
      completer.complete(null);
      return;
    }

    final parts = <web.BlobPart>[];
    for (final chunk in _chunks) {
      parts.add(chunk);
    }
    final blob = web.Blob(
      parts.toJS,
      web.BlobPropertyBag(type: _preferredMimeType() ?? 'video/webm'),
    );
    final url = web.URL.createObjectURL(blob);
    _objectUrl = url;
    completer.complete(url);
  }

  String? _preferredMimeType() {
    const candidates = [
      'video/webm;codecs=vp9,opus',
      'video/webm;codecs=vp8,opus',
      'video/webm',
    ];
    for (final c in candidates) {
      if (web.MediaRecorder.isTypeSupported(c)) return c;
    }
    return null;
  }

  @override
  Future<VideoPickResult?> importVideo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.video,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) return null;

    final data = Uint8List.fromList(bytes);
    final blob = web.Blob(
      [data.toJS].toJS,
      web.BlobPropertyBag(
        type: (file.extension ?? '').toLowerCase() == 'mp4'
            ? 'video/mp4'
            : 'video/webm',
      ),
    );
    final url = web.URL.createObjectURL(blob);
    return VideoPickResult(
      pathOrUrl: url,
      isNetworkUrl: true,
      bytes: data,
    );
  }
}
