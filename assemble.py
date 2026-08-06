import os

# Read pigeon generated file
with open('macos/Runner/Messages.g.swift', 'r') as f:
    pigeon_code = f.read()

# Define the custom Swift code
swift_code = """import Cocoa
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

class CaptureApiImpl: NSObject, CaptureApi {
    var currentProcess: Process?
    var registry: FlutterTextureRegistry?
    
    var activeTextures: [Int64: Any] = [:]
    
    func getSimulators() -> [CaptureSource] {
        let task = Process()
        task.launchPath = "/usr/bin/xcrun"
        task.arguments = ["simctl", "list", "devices", "-j"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            if #available(macOS 10.13, *) { try task.run() } else { task.launch() }
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let devices = json["devices"] as? [String: [[String: Any]]] {
                var sources: [CaptureSource] = []
                for (_, osDevices) in devices {
                    for device in osDevices {
                        if let state = device["state"] as? String, state == "Booted",
                           let name = device["name"] as? String,
                           let udid = device["udid"] as? String {
                            sources.append(CaptureSource(id: udid, name: "\\(name) (Simulator)", type: 2))
                        }
                    }
                }
                return sources
            }
        } catch {}
        return []
    }
    
    func getAvailableSources(completion: @escaping (Result<[CaptureSource], Error>) -> Void) {
        if #available(macOS 12.3, *) {
            SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) { content, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                var sources: [CaptureSource] = []
                if let content = content {
                    for display in content.displays {
                        sources.append(CaptureSource(id: "\\(display.displayID)", name: "Display \\(display.displayID)", type: 0))
                    }
                    for window in content.windows {
                        if let appName = window.owningApplication?.applicationName {
                            sources.append(CaptureSource(id: "\\(window.windowID)", name: "\\(appName) - \\(window.title ?? "Window")", type: 1))
                        }
                    }
                }
                sources.append(contentsOf: self.getSimulators())
                completion(.success(sources))
            }
        } else {
            completion(.failure(NSError(domain: "CaptureApi", code: -1, userInfo: [NSLocalizedDescriptionKey: "macOS 12.3+ required"])))
        }
    }
    
    func startCapture(sourceId: String, sourceType: Int64, outputPath: String, completion: @escaping (Result<Void, Error>) -> Void) {
        if sourceType == 2 {
            let task = Process()
            task.launchPath = "/usr/bin/xcrun"
            task.arguments = ["simctl", "io", sourceId, "recordVideo", "--force", outputPath]
            self.currentProcess = task
            do {
                if #available(macOS 10.13, *) { try task.run() } else { task.launch() }
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        } else {
            completion(.failure(NSError(domain: "CaptureApi", code: -1, userInfo: [NSLocalizedDescriptionKey: "Only simctl supported for recording so far"])))
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
                targetWindow = content.windows.first(where: { "\\($0.windowID)" == sourceId })
            } else if sourceType == 0 {
                targetDisplay = content.displays.first(where: { "\\($0.displayID)" == sourceId })
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

    RegisterGeneratedPlugins(registry: flutterViewController)
    
    let captureApi = CaptureApiImpl()
    let registrar = flutterViewController.registrar(forPlugin: "CaptureApi")
    captureApi.registry = registrar.textures
    CaptureApiSetup.setUp(binaryMessenger: registrar.messenger, api: captureApi)

    super.awakeFromNib()
  }
}
"""

with open('macos/Runner/MainFlutterWindow.swift', 'w') as f:
    f.write(swift_code + '\n' + pigeon_code)
print("Updated MainFlutterWindow.swift successfully")
