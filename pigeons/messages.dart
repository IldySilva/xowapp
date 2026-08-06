import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/messages.g.dart',
  swiftOut: 'macos/Runner/Messages.g.swift',
))

class CaptureSource {
  String id;
  String name;
  int type; // 0 = display, 1 = window, 2 = simulator

  CaptureSource({
    required this.id,
    required this.name,
    required this.type,
  });
}

@HostApi()
abstract class CaptureApi {
  @async
  List<CaptureSource> getAvailableSources();
  
  @async
  void startCapture(String sourceId, int sourceType, String outputPath);
  
  void stopCapture();
  
  @async
  int startPreview(String sourceId, int sourceType);
  
  void stopPreview(int textureId);
}
