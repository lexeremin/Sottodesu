// Prints the window number of a process's main window (used by take-screenshots.sh).
import CoreGraphics
import Foundation

let pid = Int32(CommandLine.arguments.dropFirst().first ?? "") ?? -1
let windows = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]) ?? []

for window in windows {
    guard (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
          (window[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
          let number = (window[kCGWindowNumber as String] as? NSNumber)?.intValue,
          let bounds = window[kCGWindowBounds as String] as? [String: Any],
          let width = (bounds["Width"] as? NSNumber)?.doubleValue, width > 300 else { continue }
    print(number)
    exit(0)
}
exit(1)
