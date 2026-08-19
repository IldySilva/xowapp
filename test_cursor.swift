import Foundation
import ApplicationServices

let windowListInfo = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as! [[String: Any]]
for window in windowListInfo {
    if let name = window[kCGWindowOwnerName as String] as? String, name == "Simulator" {
        let layer = window[kCGWindowLayer as String] as? Int ?? -1
        let title = window[kCGWindowName as String] as? String ?? ""
        if let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
           let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) {
            print("Simulator window: title='\(title)', layer=\(layer), bounds=\(bounds)")
        }
    }
}
