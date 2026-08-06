import Foundation
import ScreenCaptureKit
import Cocoa

class CaptureApiImpl: CaptureApi {
    
    func getAvailableSources(completion: @escaping (Result<[CaptureSource], Error>) -> Void) {
        if #available(macOS 12.3, *) {
            SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) { content, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                var sources: [CaptureSource] = []
                
                if let content = content {
                    // Displays (RF04)
                    for display in content.displays {
                        let name = "Display \(display.displayID)"
                        sources.append(CaptureSource(id: "\(display.displayID)", name: name, type: 0))
                    }
                    
                    // Windows (RF03)
                    for window in content.windows {
                        if let appName = window.owningApplication?.applicationName {
                            let title = window.title ?? "Window"
                            sources.append(CaptureSource(id: "\(window.windowID)", name: "\(appName) - \(title)", type: 1))
                        }
                    }
                }
                
                // TODO: Parse simctl list devices for simulators (RF01)
                sources.append(CaptureSource(id: "sim-stub-123", name: "iPhone 15 Pro (Simulator)", type: 2))
                
                completion(.success(sources))
            }
        } else {
            let error = NSError(domain: "CaptureApi", code: -1, userInfo: [NSLocalizedDescriptionKey: "macOS 12.3+ is required for ScreenCaptureKit"])
            completion(.failure(error))
        }
    }
    
    func startCapture(sourceId: String, sourceType: Int64, outputPath: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // TODO: Implement SCStream / simctl launch
        completion(.success(()))
    }
    
    func stopCapture() throws {
        // TODO: Stop SCStream / kill simctl
    }
}
