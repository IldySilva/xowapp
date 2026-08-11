import Cocoa
import FlutterMacOS
import ScreenCaptureKit
import CoreMedia

@available(macOS 12.3, *)
class PreviewTexture: NSObject, FlutterTexture, SCStreamOutput, SCStreamDelegate {
    var latestPixelBuffer: CVPixelBuffer?
    var textureId: Int64 = -1
    var registry: FlutterTextureRegistry?
    var stream: SCStream?
    
    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        if let buffer = latestPixelBuffer {
            return Unmanaged.passRetained(buffer)
        }
        return nil
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        self.latestPixelBuffer = imageBuffer
        if textureId != -1 {
            registry?.textureFrameAvailable(textureId)
        }
    }
}

@available(macOS 12.3, *)
class ScreenRecorder: NSObject, SCStreamOutput, SCStreamDelegate {
    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var isRecording = false
    private var startTime: CMTime?
    
    private let videoQueue = DispatchQueue(label: "app.xowcase.videoQueue")
    
    func start(filter: SCContentFilter, config: SCStreamConfiguration, outputPath: String, completion: @escaping (Error?) -> Void) {
        do {
            let url = URL(fileURLWithPath: outputPath)
            if FileManager.default.fileExists(atPath: outputPath) {
                try FileManager.default.removeItem(at: url)
            }
            
            assetWriter = try AVAssetWriter(outputURL: url, fileType: .mp4)
            guard let assetWriter = assetWriter else { return }
            
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: config.width,
                AVVideoHeightKey: config.height
            ]
            videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput?.expectsMediaDataInRealTime = true
            
            guard let videoInput = videoInput, assetWriter.canAdd(videoInput) else {
                completion(NSError(domain: "ScreenRecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot add video input"]))
                return
            }
            assetWriter.add(videoInput)
            
            let sourcePixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: config.width,
                kCVPixelBufferHeightKey as String: config.height
            ]
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: sourcePixelBufferAttributes)
            
            assetWriter.startWriting()
            
            stream = SCStream(filter: filter, configuration: config, delegate: self)
            try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoQueue)
            
            stream?.startCapture(completionHandler: { error in
                if let error = error {
                    print("ScreenRecorder: startCapture error: \(error)")
                    completion(error)
                } else {
                    print("ScreenRecorder: startCapture SUCCESS")
                    self.isRecording = true
                    completion(nil)
                }
            })
        } catch {
            print("ScreenRecorder: catch error: \(error)")
            completion(error)
        }
    }
    
    func stop(completion: @escaping () -> Void) {
        print("ScreenRecorder: stop requested")
        videoQueue.async {
            self.isRecording = false
            self.stream?.stopCapture { _ in
                if self.startTime == nil {
                    print("ScreenRecorder: No frames were captured. Canceling writing.")
                    self.assetWriter?.cancelWriting()
                    completion()
                    return
                }
                
                self.videoInput?.markAsFinished()
                self.assetWriter?.finishWriting {
                    if let error = self.assetWriter?.error {
                        print("ScreenRecorder: finishWriting ERROR: \(error)")
                    } else {
                        print("ScreenRecorder: finishWriting SUCCESS")
                    }
                    completion()
                }
            }
        }
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard isRecording, type == .screen else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { 
            print("ScreenRecorder: No pixel buffer in sample")
            return 
        }
        
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        if startTime == nil {
            print("ScreenRecorder: Received first frame at \(presentationTime.value)")
            startTime = presentationTime
            assetWriter?.startSession(atSourceTime: presentationTime)
        }
        
        if videoInput?.isReadyForMoreMediaData == true {
            let success = pixelBufferAdaptor?.append(pixelBuffer, withPresentationTime: presentationTime) ?? false
            if !success {
                print("ScreenRecorder: append pixel buffer FAILED. Writer status: \(String(describing: assetWriter?.status.rawValue))")
            }
        } else {
            print("ScreenRecorder: videoInput NOT ready for more data")
        }
    }
}

class CaptureApiImpl: NSObject, CaptureApi {
    var currentProcess: Process?
    var registry: FlutterTextureRegistry?
    
    var activeTextures: [Int64: Any] = [:]
    
    private func getTaskEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let existingPath = env["PATH"] ?? ""
        env["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:\(existingPath)"
        return env
    }
    
    func getSimulators() -> [CaptureSource] {
        let task = Process()
        task.launchPath = "/usr/bin/xcrun"
        task.arguments = ["simctl", "list", "devices", "-j"]
        task.environment = getTaskEnvironment()
        let pipe = Pipe()
        task.standardOutput = pipe
        
        let errPipe = Pipe()
        task.standardError = errPipe
        
        do {
            if #available(macOS 10.13, *) { try task.run() } else { task.launch() }
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errString = String(data: errData, encoding: .utf8) ?? ""
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let devices = json["devices"] as? [String: [[String: Any]]] {
                var sources: [CaptureSource] = []
                for (_, osDevices) in devices {
                    for device in osDevices {
                        if let state = device["state"] as? String, state == "Booted",
                           let name = device["name"] as? String,
                           let udid = device["udid"] as? String {
                            sources.append(CaptureSource(id: udid, name: "\(name) (Simulator)", type: 2))
                        }
                    }
                }
                
                if sources.isEmpty && !errString.isEmpty {
                   sources.append(CaptureSource(id: "error", name: "Err: \(errString.prefix(40))", type: 2))
                }
                return sources
            } else {
               return [CaptureSource(id: "error", name: "ParseErr: \(errString.prefix(40))", type: 2)]
            }
        } catch {
            return [CaptureSource(id: "error", name: "Catch: \(error.localizedDescription)", type: 2)]
        }
    }
    
    func getAvailableSources(completion: @escaping (Result<[CaptureSource], Error>) -> Void) {
        DispatchQueue.main.async {
            if #available(macOS 12.3, *) {
                let hasAccess = CGPreflightScreenCaptureAccess()
                if !hasAccess {
                    CGRequestScreenCaptureAccess()
                    let error = PigeonError(code: "PERMISSION_DENIED", message: "Screen Recording permission is required. The system prompt should appear. Please allow it in System Settings, then click the Refresh (🔄) button.", details: nil)
                    completion(.failure(error))
                    return
                }
                
                SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) { content, error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    
                    var sources: [CaptureSource] = []
                    
                    if let content = content {
                        for display in content.displays {
                            let name = "Display \(display.displayID)"
                            sources.append(CaptureSource(id: "\(display.displayID)", name: name, type: 0))
                        }
                        
                        let ignoredApps = ["Control Center", "CursorUIViewService", "Spotlight", "Window Server", "loginwindow", "Notification Center", "Dock", "Accessibility", "Open and Save Panel Service", "Cap"]
                        
                        for window in content.windows {
                            if window.windowLayer == 0,
                               let appName = window.owningApplication?.applicationName,
                               !ignoredApps.contains(where: { appName.contains($0) }) {
                                
                                let title = window.title ?? ""
                                // Only add the title if it exists, otherwise just the app name
                                let displayName = title.isEmpty ? appName : "\(appName) - \(title)"
                                sources.append(CaptureSource(id: "\(window.windowID)", name: displayName, type: 1))
                            }
                        }
                    }
                    
                    if sources.isEmpty {
                        let pigeonError = PigeonError(code: "PERMISSION_DENIED", message: "macOS blocked Screen Recording. Remove the app from System Settings, restart the app, and wait for the prompt.", details: nil)
                        completion(.failure(pigeonError))
                        return
                    }
                    
                    sources.append(contentsOf: self.getSimulators())
                    completion(.success(sources))
                }
            } else {
                let error = PigeonError(code: "UNSUPPORTED_OS", message: "macOS 12.3+ is required for ScreenCaptureKit", details: nil)
                completion(.failure(error))
            }
        }
    }
    
    // To hold the SCStream recorder instance
    private var screenRecorder: Any?
    
    func startCapture(sourceId: String, sourceType: Int64, outputPath: String, completion: @escaping (Result<Void, Error>) -> Void) {
        if sourceType == 2 {
            let task = Process()
            task.launchPath = "/usr/bin/xcrun"
            task.arguments = ["simctl", "io", sourceId, "recordVideo", "--codec", "h264", "--force", outputPath]
            task.environment = getTaskEnvironment()
            self.currentProcess = task
            do {
                if #available(macOS 10.13, *) { try task.run() } else { task.launch() }
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        } else {
            guard #available(macOS 12.3, *) else {
                completion(.failure(NSError(domain: "CaptureApi", code: -1, userInfo: [NSLocalizedDescriptionKey: "macOS 12.3+ required for recording windows/screens"])))
                return
            }
            
            SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) { content, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let content = content else { return }
                
                var targetWindow: SCWindow?
                var targetDisplay: SCDisplay?
                
                if sourceType == 1 {
                    targetWindow = content.windows.first(where: { "\($0.windowID)" == sourceId })
                } else if sourceType == 0 {
                    targetDisplay = content.displays.first(where: { "\($0.displayID)" == sourceId })
                }
                
                let filter: SCContentFilter
                let width: Int
                let height: Int
                if let w = targetWindow {
                    filter = SCContentFilter(desktopIndependentWindow: w)
                    let rawW = Int(w.frame.width * 2)
                    let rawH = Int(w.frame.height * 2)
                    width = rawW % 2 == 0 ? rawW : rawW - 1
                    height = rawH % 2 == 0 ? rawH : rawH - 1
                } else if let d = targetDisplay {
                    filter = SCContentFilter(display: d, excludingWindows: [])
                    let rawW = d.width * 2
                    let rawH = d.height * 2
                    width = rawW % 2 == 0 ? rawW : rawW - 1
                    height = rawH % 2 == 0 ? rawH : rawH - 1
                } else {
                    completion(.failure(NSError(domain: "CaptureApi", code: -1, userInfo: [NSLocalizedDescriptionKey: "Source not found"])))
                    return
                }
                
                let config = SCStreamConfiguration()
                config.showsCursor = true
                config.width = width
                config.height = height
                
                let recorder = ScreenRecorder()
                self.screenRecorder = recorder
                recorder.start(filter: filter, config: config, outputPath: outputPath) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
            }
        }
    }
    
    func stopCapture() throws {
        if let task = self.currentProcess {
            if task.isRunning {
                task.interrupt()
                task.waitUntilExit()
            }
            self.currentProcess = nil
        }
        
        if #available(macOS 12.3, *) {
            if let recorder = self.screenRecorder as? ScreenRecorder {
                recorder.stop {
                    self.screenRecorder = nil
                }
            }
        }
    }
    
    func startPreview(sourceId: String, sourceType: Int64, completion: @escaping (Result<Int64, Error>) -> Void) {
        guard #available(macOS 12.3, *) else {
            completion(.failure(NSError(domain: "CaptureApi", code: -1, userInfo: [NSLocalizedDescriptionKey: "macOS 12.3+ required"])))
            return
        }
        guard let registry = self.registry else {
            completion(.failure(NSError(domain: "CaptureApi", code: -1, userInfo: [NSLocalizedDescriptionKey: "Texture Registry missing"])))
            return
        }
        
        let texture = PreviewTexture()
        texture.registry = registry
        let textureId = registry.register(texture)
        texture.textureId = textureId
        activeTextures[textureId] = texture
        
        SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) { content, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let content = content else { return }
            
            var targetWindow: SCWindow?
            var targetDisplay: SCDisplay?
            
            if sourceType == 1 {
                targetWindow = content.windows.first(where: { "\($0.windowID)" == sourceId })
            } else if sourceType == 0 {
                targetDisplay = content.displays.first(where: { "\($0.displayID)" == sourceId })
            } else if sourceType == 2 {
                // If it's a simulator, try to find a window with 'Simulator'
                targetWindow = content.windows.first(where: { $0.owningApplication?.applicationName == "Simulator" })
            }
            
            let filter: SCContentFilter
            if let w = targetWindow {
                filter = SCContentFilter(desktopIndependentWindow: w)
            } else if let d = targetDisplay {
                filter = SCContentFilter(display: d, excludingWindows: [])
            } else {
                completion(.failure(NSError(domain: "CaptureApi", code: -1, userInfo: [NSLocalizedDescriptionKey: "Source not found"])))
                return
            }
            
            let streamConfig = SCStreamConfiguration()
            streamConfig.showsCursor = true
            
            do {
                let stream = SCStream(filter: filter, configuration: streamConfig, delegate: texture)
                texture.stream = stream
                try stream.addStreamOutput(texture, type: .screen, sampleHandlerQueue: DispatchQueue.main)
                stream.startCapture { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(textureId))
                    }
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func stopPreview(textureId: Int64) throws {
        guard #available(macOS 12.3, *) else { return }
        if let texture = activeTextures[textureId] as? PreviewTexture {
            texture.stream?.stopCapture(completionHandler: nil)
            registry?.unregisterTexture(textureId)
            activeTextures.removeValue(forKey: textureId)
        }
    }
}

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    
    // Frameless native look with transparent background for tiny toolbars
    self.styleMask.remove(.titled) // Removes traffic lights completely!
    self.styleMask.insert(.fullSizeContentView)
    self.isMovableByWindowBackground = true
    self.isOpaque = false
    self.backgroundColor = .clear
    self.hasShadow = false // Fixes the black square background!
    
    // Force Flutter view itself to be transparent
    flutterViewController.backgroundColor = .clear
    flutterViewController.view.layer?.isOpaque = false
    flutterViewController.view.layer?.backgroundColor = CGColor.clear

    RegisterGeneratedPlugins(registry: flutterViewController)
    
    let captureApi = CaptureApiImpl()
    let registrar = flutterViewController.registrar(forPlugin: "CaptureApi")
    captureApi.registry = registrar.textures
    CaptureApiSetup.setUp(binaryMessenger: registrar.messenger, api: captureApi)

    let channel = FlutterMethodChannel(name: "app.xowcase/window", binaryMessenger: registrar.messenger)
    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      if call.method == "setSize" {
         if let args = call.arguments as? [String: Double],
            let w = args["width"], let h = args["height"] {
            var frame = self.frame
            let oldW = frame.size.width
            let oldH = frame.size.height
            frame.size = NSSize(width: w, height: h)
            frame.origin.x += (oldW - CGFloat(w)) / 2
            frame.origin.y += (oldH - CGFloat(h)) / 2
            self.setFrame(frame, display: true, animate: true)
            
            if w <= 500 {
                self.level = .floating
                self.styleMask.remove(.resizable)
                self.styleMask.remove(.titled) // Remove traffic lights for pill
                self.isOpaque = false
                self.backgroundColor = .clear
                self.hasShadow = false
            } else {
                self.level = .normal
                self.styleMask.insert(.resizable)
                self.styleMask.insert(.titled) // Restore traffic lights for Editor
                self.titleVisibility = .hidden
                self.titlebarAppearsTransparent = true
                self.isOpaque = true
                self.backgroundColor = .windowBackgroundColor
                self.hasShadow = true
            }
            
            result(nil)
         }
      } else if call.method == "startDragging" {
         if let event = NSApp.currentEvent {
            self.performDrag(with: event)
         }
         result(nil)
      } else {
         result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}

// Autogenerated from Pigeon (v27.3.0), do not edit directly.
// See also: https://pub.dev/packages/pigeon

import Foundation

#if os(iOS)
  import Flutter
#elseif os(macOS)
  import FlutterMacOS
#else
  #error("Unsupported platform.")
#endif

/// Error class for passing custom error details to Dart side.
final class PigeonError: Error {
  let code: String
  let message: String?
  let details: Sendable?

  init(code: String, message: String?, details: Sendable?) {
    self.code = code
    self.message = message
    self.details = details
  }

  var localizedDescription: String {
    return
      "PigeonError(code: \(code), message: \(message ?? "<nil>"), details: \(details ?? "<nil>")"
  }
}

private func wrapResult(_ result: Any?) -> [Any?] {
  return [result]
}

private func wrapError(_ error: Any) -> [Any?] {
  if let pigeonError = error as? PigeonError {
    return [
      pigeonError.code,
      pigeonError.message,
      pigeonError.details,
    ]
  }
  if let flutterError = error as? FlutterError {
    return [
      flutterError.code,
      flutterError.message,
      flutterError.details,
    ]
  }
  return [
    "\(error)",
    "\(Swift.type(of: error))",
    "Stacktrace: \(Thread.callStackSymbols)",
  ]
}

enum MessagesPigeonInternal {
  static func isNullish(_ value: Any?) -> Bool {
    guard let innerValue = value else {
      return true
    }

    if case Optional<Any>.some(Optional<Any>.none) = value {
      return true
    }

    return innerValue is NSNull
  }
  static func doubleEquals(_ lhs: Double, _ rhs: Double) -> Bool {
    return (lhs.isNaN && rhs.isNaN) || lhs == rhs
  }

  static func doubleHash(_ value: Double, _ hasher: inout Hasher) {
    if value.isNaN {
      hasher.combine(0x7FF8000000000000)
    } else {
      // Normalize -0.0 to 0.0
      hasher.combine(value == 0 ? 0 : value)
    }
  }

  static func deepEquals(_ lhs: Any?, _ rhs: Any?) -> Bool {
    let cleanLhs = nilOrValue(lhs) as Any?
    let cleanRhs = nilOrValue(rhs) as Any?
    switch (cleanLhs, cleanRhs) {
    case (nil, nil):
      return true

    case (nil, _), (_, nil):
      return false

    case (let lhs as AnyObject, let rhs as AnyObject) where lhs === rhs:
      return true

    case is (Void, Void):
      return true

    case (let lhsArray, let rhsArray) as ([Any?], [Any?]):
      guard lhsArray.count == rhsArray.count else { return false }
      for (index, element) in lhsArray.enumerated() {
        if !deepEquals(element, rhsArray[index]) {
          return false
        }
      }
      return true

    case (let lhsArray, let rhsArray) as ([Double], [Double]):
      guard lhsArray.count == rhsArray.count else { return false }
      for (index, element) in lhsArray.enumerated() {
        if !doubleEquals(element, rhsArray[index]) {
          return false
        }
      }
      return true

    case (let lhsDictionary, let rhsDictionary) as ([AnyHashable: Any?], [AnyHashable: Any?]):
      guard lhsDictionary.count == rhsDictionary.count else { return false }
      for (lhsKey, lhsValue) in lhsDictionary {
        var found = false
        for (rhsKey, rhsValue) in rhsDictionary {
          if deepEquals(lhsKey, rhsKey) {
            if deepEquals(lhsValue, rhsValue) {
              found = true
              break
            } else {
              return false
            }
          }
        }
        if !found { return false }
      }
      return true

    case (let lhs as Double, let rhs as Double):
      return doubleEquals(lhs, rhs)

    case (let lhsHashable, let rhsHashable) as (AnyHashable, AnyHashable):
      return lhsHashable == rhsHashable

    default:
      return false
    }
  }

  static func deepHash(value: Any?, hasher: inout Hasher) {
    let cleanValue = nilOrValue(value) as Any?
    if let cleanValue = cleanValue {
      if let doubleValue = cleanValue as? Double {
        doubleHash(doubleValue, &hasher)
      } else if let valueList = cleanValue as? [Any?] {
        for item in valueList {
          deepHash(value: item, hasher: &hasher)
        }
      } else if let valueList = cleanValue as? [Double] {
        for item in valueList {
          doubleHash(item, &hasher)
        }
      } else if let valueDict = cleanValue as? [AnyHashable: Any?] {
        var result = 0
        for (key, value) in valueDict {
          var entryKeyHasher = Hasher()
          deepHash(value: key, hasher: &entryKeyHasher)
          var entryValueHasher = Hasher()
          deepHash(value: value, hasher: &entryValueHasher)
          result = result &+ ((entryKeyHasher.finalize() &* 31) ^ entryValueHasher.finalize())
        }
        hasher.combine(result)
      } else if let hashableValue = cleanValue as? AnyHashable {
        hasher.combine(hashableValue)
      } else {
        hasher.combine(String(describing: cleanValue))
      }
    } else {
      hasher.combine(0)
    }
  }

}

private func nilOrValue<T>(_ value: Any?) -> T? {
  if value is NSNull { return nil }
  return value as! T?
}


/// Generated class from Pigeon that represents data sent in messages.
struct CaptureSource: Hashable, CustomStringConvertible {
  var id: String
  var name: String
  var type: Int64


  // swift-format-ignore: AlwaysUseLowerCamelCase
  static func fromList(_ pigeonVar_list: [Any?]) -> CaptureSource? {
    let id = pigeonVar_list[0] as! String
    let name = pigeonVar_list[1] as! String
    let type = pigeonVar_list[2] as! Int64

    return CaptureSource(
      id: id,
      name: name,
      type: type
    )
  }
  func toList() -> [Any?] {
    return [
      id,
      name,
      type,
    ]
  }
  static func == (lhs: CaptureSource, rhs: CaptureSource) -> Bool {
    if Swift.type(of: lhs) != Swift.type(of: rhs) {
      return false
    }
    return MessagesPigeonInternal.deepEquals(lhs.id, rhs.id) && MessagesPigeonInternal.deepEquals(lhs.name, rhs.name) && MessagesPigeonInternal.deepEquals(lhs.type, rhs.type)
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine("CaptureSource")
    MessagesPigeonInternal.deepHash(value: id, hasher: &hasher)
    MessagesPigeonInternal.deepHash(value: name, hasher: &hasher)
    MessagesPigeonInternal.deepHash(value: type, hasher: &hasher)
  }

  public var description: String {
    return "CaptureSource(id: \(String(describing: id)), name: \(String(describing: name)), type: \(String(describing: type)))"
  }
}

private class MessagesPigeonCodecReader: FlutterStandardReader {
  override func readValue(ofType type: UInt8) -> Any? {
    switch type {
    case 129:
      return CaptureSource.fromList(self.readValue() as! [Any?])
    default:
      return super.readValue(ofType: type)
    }
  }
}

private class MessagesPigeonCodecWriter: FlutterStandardWriter {
  override func writeValue(_ value: Any) {
    if let value = value as? CaptureSource {
      super.writeByte(129)
      super.writeValue(value.toList())
    } else {
      super.writeValue(value)
    }
  }
}

private class MessagesPigeonCodecReaderWriter: FlutterStandardReaderWriter {
  override func reader(with data: Data) -> FlutterStandardReader {
    return MessagesPigeonCodecReader(data: data)
  }

  override func writer(with data: NSMutableData) -> FlutterStandardWriter {
    return MessagesPigeonCodecWriter(data: data)
  }
}

class MessagesPigeonCodec: FlutterStandardMessageCodec, @unchecked Sendable {
  static let shared = MessagesPigeonCodec(readerWriter: MessagesPigeonCodecReaderWriter())
}


/// Generated protocol from Pigeon that represents a handler of messages from Flutter.
protocol CaptureApi {
  func getAvailableSources(completion: @escaping (Result<[CaptureSource], Error>) -> Void)
  func startCapture(sourceId: String, sourceType: Int64, outputPath: String, completion: @escaping (Result<Void, Error>) -> Void)
  func stopCapture() throws
  func startPreview(sourceId: String, sourceType: Int64, completion: @escaping (Result<Int64, Error>) -> Void)
  func stopPreview(textureId: Int64) throws
}

/// Generated setup class from Pigeon to handle messages through the `binaryMessenger`.
class CaptureApiSetup {
  static var codec: FlutterStandardMessageCodec { MessagesPigeonCodec.shared }
  /// Sets up an instance of `CaptureApi` to handle messages through the `binaryMessenger`.
  static func setUp(binaryMessenger: FlutterBinaryMessenger, api: CaptureApi?, messageChannelSuffix: String = "") {
    let channelSuffix = messageChannelSuffix.count > 0 ? ".\(messageChannelSuffix)" : ""
    let getAvailableSourcesChannel = FlutterBasicMessageChannel(name: "dev.flutter.pigeon.xowcase.CaptureApi.getAvailableSources\(channelSuffix)", binaryMessenger: binaryMessenger, codec: codec)
    if let api = api {
      getAvailableSourcesChannel.setMessageHandler { _, reply in
        api.getAvailableSources { result in
          switch result {
          case .success(let res):
            reply(wrapResult(res))
          case .failure(let error):
            reply(wrapError(error))
          }
        }
      }
    } else {
      getAvailableSourcesChannel.setMessageHandler(nil)
    }
    let startCaptureChannel = FlutterBasicMessageChannel(name: "dev.flutter.pigeon.xowcase.CaptureApi.startCapture\(channelSuffix)", binaryMessenger: binaryMessenger, codec: codec)
    if let api = api {
      startCaptureChannel.setMessageHandler { message, reply in
        let args = message as! [Any?]
        let sourceIdArg = args[0] as! String
        let sourceTypeArg = args[1] as! Int64
        let outputPathArg = args[2] as! String
        api.startCapture(sourceId: sourceIdArg, sourceType: sourceTypeArg, outputPath: outputPathArg) { result in
          switch result {
          case .success:
            reply(wrapResult(nil))
          case .failure(let error):
            reply(wrapError(error))
          }
        }
      }
    } else {
      startCaptureChannel.setMessageHandler(nil)
    }
    let stopCaptureChannel = FlutterBasicMessageChannel(name: "dev.flutter.pigeon.xowcase.CaptureApi.stopCapture\(channelSuffix)", binaryMessenger: binaryMessenger, codec: codec)
    if let api = api {
      stopCaptureChannel.setMessageHandler { _, reply in
        do {
          try api.stopCapture()
          reply(wrapResult(nil))
        } catch {
          reply(wrapError(error))
        }
      }
    } else {
      stopCaptureChannel.setMessageHandler(nil)
    }
    let startPreviewChannel = FlutterBasicMessageChannel(name: "dev.flutter.pigeon.xowcase.CaptureApi.startPreview\(channelSuffix)", binaryMessenger: binaryMessenger, codec: codec)
    if let api = api {
      startPreviewChannel.setMessageHandler { message, reply in
        let args = message as! [Any?]
        let sourceIdArg = args[0] as! String
        let sourceTypeArg = args[1] as! Int64
        api.startPreview(sourceId: sourceIdArg, sourceType: sourceTypeArg) { result in
          switch result {
          case .success(let res):
            reply(wrapResult(res))
          case .failure(let error):
            reply(wrapError(error))
          }
        }
      }
    } else {
      startPreviewChannel.setMessageHandler(nil)
    }
    let stopPreviewChannel = FlutterBasicMessageChannel(name: "dev.flutter.pigeon.xowcase.CaptureApi.stopPreview\(channelSuffix)", binaryMessenger: binaryMessenger, codec: codec)
    if let api = api {
      stopPreviewChannel.setMessageHandler { message, reply in
        let args = message as! [Any?]
        let textureIdArg = args[0] as! Int64
        do {
          try api.stopPreview(textureId: textureIdArg)
          reply(wrapResult(nil))
        } catch {
          reply(wrapError(error))
        }
      }
    } else {
      stopPreviewChannel.setMessageHandler(nil)
    }
  }
}
