import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:web/web.dart' as web;

import 'web_video_export.dart';

Future<Uint8List> exportComposedWebVideo({
  required String videoUrl,
  required WebExportLayout layout,
  void Function(double progress)? onProgress,
}) async {
  final video = web.HTMLVideoElement()
    ..src = videoUrl
    ..muted = true
    ..autoplay = false
    ..controls = false
    ..crossOrigin = 'anonymous'
    ..preload = 'auto';
  video.setAttribute('playsinline', 'true');

  final canvas = web.HTMLCanvasElement()
    ..width = layout.canvasW
    ..height = layout.canvasH;
  final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;

  web.HTMLImageElement? frameImage;
  if (!layout.frameless && layout.framePngBytes != null) {
    frameImage = await _loadImageFromBytes(layout.framePngBytes!);
  }

  await _waitForVideoReady(video);

  final duration = video.duration;
  if (duration.isNaN || duration <= 0) {
    throw StateError('Could not read video duration for export');
  }

  final mime = _preferredRecorderMime();
  final stream = canvas.captureStream(30);
  try {
    final audioTracks = video.captureStream().getAudioTracks().toDart;
    for (final track in audioTracks) {
      stream.addTrack(track);
    }
  } catch (_) {
    // Audio optional — some browsers block captureStream on muted elements.
  }

  final recorder = mime != null
      ? web.MediaRecorder(stream, web.MediaRecorderOptions(mimeType: mime))
      : web.MediaRecorder(stream);

  final chunks = <web.Blob>[];
  final done = Completer<void>();

  recorder.ondataavailable = ((web.Event event) {
    final blobEvent = event as web.BlobEvent;
    if (blobEvent.data.size > 0) {
      chunks.add(blobEvent.data);
    }
  }).toJS;

  recorder.onstop = ((web.Event _) {
    if (!done.isCompleted) done.complete();
  }).toJS;

  recorder.onerror = ((web.Event _) {
    if (!done.isCompleted) {
      done.completeError(StateError('MediaRecorder failed during export'));
    }
  }).toJS;

  recorder.start(200);

  video.currentTime = 0;
  await video.play().toDart;

  // Seek+draw loop at ~30fps using rAF, stop when ended.
  final drawDone = Completer<void>();
  late final JSFunction tickJs;
  void tick(num _) {
    if (video.ended) {
      if (!drawDone.isCompleted) drawDone.complete();
      return;
    }

    _drawFrame(
      ctx: ctx,
      video: video,
      frameImage: frameImage,
      layout: layout,
    );

    final progress = (video.currentTime / duration).clamp(0.0, 1.0);
    onProgress?.call(progress);
    web.window.requestAnimationFrame(tickJs);
  }

  tickJs = tick.toJS;
  web.window.requestAnimationFrame(tickJs);

  // Also listen for ended as a backup.
  video.onended = ((web.Event _) {
    if (!drawDone.isCompleted) drawDone.complete();
  }).toJS;

  await drawDone.future.timeout(
    Duration(milliseconds: (duration * 1000).ceil() + 15000),
    onTimeout: () {},
  );

  // Final frame
  _drawFrame(
    ctx: ctx,
    video: video,
    frameImage: frameImage,
    layout: layout,
  );
  onProgress?.call(1.0);

  video.pause();
  if (recorder.state != 'inactive') {
    recorder.stop();
  }
  await done.future.timeout(const Duration(seconds: 10));

  for (final track in stream.getTracks().toDart) {
    track.stop();
  }

  if (chunks.isEmpty) {
    throw StateError('Export produced no video data');
  }

  final blob = web.Blob(
    chunks.toJS,
    web.BlobPropertyBag(type: mime ?? 'video/webm'),
  );
  final buffer = await blob.arrayBuffer().toDart;
  return buffer.toDart.asUint8List();
}

void _drawFrame({
  required web.CanvasRenderingContext2D ctx,
  required web.HTMLVideoElement video,
  required web.HTMLImageElement? frameImage,
  required WebExportLayout layout,
}) {
  final canvasW = layout.canvasW.toDouble();
  final canvasH = layout.canvasH.toDouble();

  ctx.clearRect(0, 0, canvasW, canvasH);
  _fillBackground(ctx, layout, canvasW, canvasH);

  if (layout.frameless) {
    _drawFrameless(ctx, video, layout, canvasW, canvasH);
  } else {
    _drawWithDeviceFrame(ctx, video, frameImage, layout, canvasW, canvasH);
  }
}

void _fillBackground(
  web.CanvasRenderingContext2D ctx,
  WebExportLayout layout,
  double canvasW,
  double canvasH,
) {
  final gradient = layout.backgroundGradient;
  if (gradient != null && gradient.length >= 2) {
    final g = ctx.createLinearGradient(0, 0, canvasW, canvasH);
    for (var i = 0; i < gradient.length; i++) {
      final t = i / (gradient.length - 1);
      g.addColorStop(t, _cssColor(gradient[i]));
    }
    ctx.fillStyle = g as JSAny;
  } else {
    ctx.fillStyle = _cssColor(layout.backgroundColor).toJS;
  }
  ctx.fillRect(0, 0, canvasW, canvasH);
}

void _drawFrameless(
  web.CanvasRenderingContext2D ctx,
  web.HTMLVideoElement video,
  WebExportLayout layout,
  double canvasW,
  double canvasH,
) {
  final videoW = video.videoWidth == 0 ? 1920.0 : video.videoWidth.toDouble();
  final videoH = video.videoHeight == 0 ? 1080.0 : video.videoHeight.toDouble();

  var scale = 1.0;
  if (videoW > canvasW * (1.0 - layout.padding) ||
      videoH > canvasH * (1.0 - layout.padding)) {
    final scaleW = (canvasW * (1.0 - layout.padding)) / videoW;
    final scaleH = (canvasH * (1.0 - layout.padding)) / videoH;
    scale = math.min(scaleW, scaleH);
  }

  final scaledW = videoW * scale;
  final scaledH = videoH * scale;
  final visibleW = scaledW * (1 - layout.cropLeft - layout.cropRight);
  final visibleH = scaledH * (1 - layout.cropTop - layout.cropBottom);
  final cropOffsetX = scaledW * layout.cropLeft;
  final cropOffsetY = scaledH * layout.cropTop;
  final visibleStartX = (canvasW - visibleW) / 2;
  final visibleStartY = (canvasH - visibleH) / 2;
  final radius = layout.borderRadius * scale;

  if (layout.shadowOpacity > 0) {
    ctx.save();
    ctx.shadowColor = 'rgba(0,0,0,${layout.shadowOpacity})';
    ctx.shadowBlur = layout.shadowBlur * scale * 0.5;
    ctx.shadowOffsetY = 15 * scale;
    ctx.fillStyle = '#000'.toJS;
    _roundRectPath(
      ctx,
      visibleStartX,
      visibleStartY,
      visibleW,
      visibleH,
      radius,
    );
    ctx.fill();
    ctx.restore();
  }

  ctx.save();
  _roundRectPath(
    ctx,
    visibleStartX,
    visibleStartY,
    visibleW,
    visibleH,
    radius,
  );
  ctx.clip();
  _drawVideoCover(
    ctx,
    video,
    visibleStartX - cropOffsetX,
    visibleStartY - cropOffsetY,
    scaledW,
    scaledH,
  );
  ctx.restore();
}

void _drawWithDeviceFrame(
  web.CanvasRenderingContext2D ctx,
  web.HTMLVideoElement video,
  web.HTMLImageElement? frameImage,
  WebExportLayout layout,
  double canvasW,
  double canvasH,
) {
  final bounds = layout.frameBounds;
  if (bounds == null) return;

  final frameW = (bounds['frame_w'] as num).toDouble();
  final frameH = (bounds['frame_h'] as num).toDouble();
  final holeX = (bounds['x'] as num).toDouble();
  final holeY = (bounds['y'] as num).toDouble();
  final holeW = (bounds['w'] as num).toDouble();
  final holeH = (bounds['h'] as num).toDouble();

  var frameScale = 1.0;
  if (frameW > canvasW * (1.0 - layout.padding) ||
      frameH > canvasH * (1.0 - layout.padding)) {
    final scaleW = (canvasW * (1.0 - layout.padding)) / frameW;
    final scaleH = (canvasH * (1.0 - layout.padding)) / frameH;
    frameScale = math.min(scaleW, scaleH);
  }

  final scaledFrameW = frameW * frameScale;
  final scaledFrameH = frameH * frameScale;
  final scaledHoleX = holeX * frameScale;
  final scaledHoleY = holeY * frameScale;
  final scaledHoleW = holeW * frameScale;
  final scaledHoleH = holeH * frameScale;

  final visibleW = scaledFrameW * (1 - layout.cropLeft - layout.cropRight);
  final visibleH = scaledFrameH * (1 - layout.cropTop - layout.cropBottom);
  final visibleStartX = (canvasW - visibleW) / 2;
  final visibleStartY = (canvasH - visibleH) / 2;
  final globalFrameX = visibleStartX - (scaledFrameW * layout.cropLeft);
  final globalFrameY = visibleStartY - (scaledFrameH * layout.cropTop);
  final radius = 120 * frameScale;

  // Clip to visible crop region of the canvas.
  ctx.save();
  ctx.beginPath();
  ctx.rect(visibleStartX, visibleStartY, visibleW, visibleH);
  ctx.clip();

  // Video in device hole
  ctx.save();
  _roundRectPath(
    ctx,
    globalFrameX + scaledHoleX,
    globalFrameY + scaledHoleY,
    scaledHoleW,
    scaledHoleH,
    radius,
  );
  ctx.clip();
  _drawVideoCover(
    ctx,
    video,
    globalFrameX + scaledHoleX,
    globalFrameY + scaledHoleY,
    scaledHoleW,
    scaledHoleH,
  );
  ctx.restore();

  // Device frame overlay
  if (frameImage != null) {
    ctx.drawImage(
      frameImage,
      globalFrameX,
      globalFrameY,
      scaledFrameW,
      scaledFrameH,
    );
  }
  ctx.restore();
}

void _drawVideoCover(
  web.CanvasRenderingContext2D ctx,
  web.HTMLVideoElement video,
  double destX,
  double destY,
  double destW,
  double destH,
) {
  final vw = video.videoWidth.toDouble();
  final vh = video.videoHeight.toDouble();
  if (vw <= 0 || vh <= 0 || destW <= 0 || destH <= 0) return;

  final scale = math.max(destW / vw, destH / vh);
  final sw = destW / scale;
  final sh = destH / scale;
  final sx = (vw - sw) / 2;
  final sy = (vh - sh) / 2;
  ctx.drawImage(video, sx, sy, sw, sh, destX, destY, destW, destH);
}

void _roundRectPath(
  web.CanvasRenderingContext2D ctx,
  double x,
  double y,
  double w,
  double h,
  double r,
) {
  final radius = math.min(r, math.min(w, h) / 2);
  ctx.beginPath();
  ctx.moveTo(x + radius, y);
  ctx.arcTo(x + w, y, x + w, y + h, radius);
  ctx.arcTo(x + w, y + h, x, y + h, radius);
  ctx.arcTo(x, y + h, x, y, radius);
  ctx.arcTo(x, y, x + w, y, radius);
  ctx.closePath();
}

String _cssColor(Color c) {
  final r = (c.r * 255.0).round();
  final g = (c.g * 255.0).round();
  final b = (c.b * 255.0).round();
  final a = c.a;
  return 'rgba($r,$g,$b,$a)';
}

String? _preferredRecorderMime() {
  const candidates = [
    'video/webm;codecs=vp9,opus',
    'video/webm;codecs=vp8,opus',
    'video/webm;codecs=vp9',
    'video/webm',
  ];
  for (final c in candidates) {
    if (web.MediaRecorder.isTypeSupported(c)) return c;
  }
  return null;
}

Future<void> _waitForVideoReady(web.HTMLVideoElement video) async {
  if (video.readyState >= 2 && video.videoWidth > 0) return;

  final completer = Completer<void>();
  void onLoaded(web.Event _) {
    if (!completer.isCompleted) completer.complete();
  }

  void onError(web.Event _) {
    if (!completer.isCompleted) {
      completer.completeError(StateError('Failed to load video for export'));
    }
  }

  video.onloadeddata = onLoaded.toJS;
  video.onerror = onError.toJS;

  video.load();
  await completer.future.timeout(const Duration(seconds: 30));
}

Future<web.HTMLImageElement> _loadImageFromBytes(Uint8List bytes) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'image/png'),
  );
  final url = web.URL.createObjectURL(blob);
  final img = web.HTMLImageElement()..src = url;
  final completer = Completer<void>();
  img.decode().toDart.then((_) {
    if (!completer.isCompleted) completer.complete();
  }).catchError((Object e) {
    if (!completer.isCompleted) completer.completeError(e);
  });
  await completer.future.timeout(const Duration(seconds: 20));
  return img;
}

extension on JSArray<web.MediaStreamTrack> {
  List<web.MediaStreamTrack> get toDart {
    final length = this.length;
    return [for (var i = 0; i < length; i++) this[i]];
  }
}
