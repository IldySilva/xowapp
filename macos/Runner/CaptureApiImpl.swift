import Foundation
import ScreenCaptureKit
import Cocoa

class CaptureApiImpl: CaptureApi {
    
    func getAvailableSources(completion: @escaping (Result<[CaptureSource], Error>) -> Void) {
        DispatchQueue.main.async {
            if #available(macOS 12.3, *) {
                let hasAccess = CGPreflightScreenCaptureAccess()
                if !hasAccess {
                    CGRequestScreenCaptureAccess()
                    let error = NSError(domain: "CaptureApi", code: -1, userInfo: [NSLocalizedDescriptionKey: "Screen Recording permission is required. The system prompt should appear. Please allow it in System Settings, then click the Refresh (🔄) button."])
                    completion(.failure(error))
                    return
                }
                
                SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: false) { content, error in
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
                        
                        for window in content.windows {
                            if let appName = window.owningApplication?.applicationName {
                                let title = window.title ?? "Window"
                                sources.append(CaptureSource(id: "\(window.windowID)", name: "\(appName) - \(title)", type: 1))
                            }
                        }
                    }
                    
                    if sources.isEmpty {
                        let error = NSError(domain: "CaptureApi", code: -1, userInfo: [NSLocalizedDescriptionKey: "macOS blocked Screen Recording. Remove the app from System Settings, restart the app, and wait for the prompt."])
                        completion(.failure(error))
                        return
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
    }
    
    func startCapture(sourceId: String, sourceType: Int64, outputPath: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // TODO: Implement SCStream / simctl launch
        completion(.success(()))
    }
    
    func stopCapture() throws {
        // TODO: Stop SCStream / kill simctl
    }
}
