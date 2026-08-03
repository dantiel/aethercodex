import CoreGraphics
import Foundation

let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly)
let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as! [[String: Any]]

let result: [[String: Any]] = windows.compactMap { win in
    guard let bounds = win[kCGWindowBounds as String] as? [String: CGFloat] else { return nil }
    return [
        "id": win[kCGWindowNumber as String] as? Int ?? 0,
        "pid": win[kCGWindowOwnerPID as String] as? Int ?? 0,
        "app": win[kCGWindowOwnerName as String] as? String ?? "",
        "title": win[kCGWindowName as String] as? String ?? "",
        "alpha": win[kCGWindowAlpha as String] as? Double ?? 0,
        "layer": win[kCGWindowLayer as String] as? Int ?? 0,
        "x": bounds["X"] ?? 0,
        "y": bounds["Y"] ?? 0,
        "width": bounds["Width"] ?? 0,
        "height": bounds["Height"] ?? 0,
        "onscreen": win[kCGWindowIsOnscreen as String] as? Bool ?? false,
    ]
}

let json = try JSONSerialization.data(withJSONObject: result, options: [])
print(String(data: json, encoding: .utf8)!)
