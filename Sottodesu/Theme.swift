import SwiftUI

extension Color {
    /// 0xRRGGBB
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

/// Muted, paper-and-ink colours for the charts. The interface itself stays black and white;
/// colour is only used to tell categories apart, and vermilion is reserved for "needs attention".
extension Category {
    var color: Color {
        switch self {
        case .images: return Color(hex: 0x5B7DB1)
        case .videos: return Color(hex: 0x8E6BAF)
        case .audio: return Color(hex: 0xD98AA2)
        case .documents: return Color(hex: 0x6B6F76)
        case .books: return Color(hex: 0xA9784E)
        case .archives: return Color(hex: 0xA8A294)
        case .installers: return Color(hex: 0xD9A63F)
        case .models3D: return Color(hex: 0x4F9A8F)
        case .anki: return Color(hex: 0x7DA55C)
        case .config: return Color(hex: 0x4F7A9E)
        case .code: return Color(hex: 0x3E8E6A)
        case .fonts: return Color(hex: 0xC77B5A)
        case .design: return Color(hex: 0xB9658F)
        case .projects: return Color(hex: 0x2F3B52)
        case .other: return Color(hex: 0xB8B8B8)
        }
    }
}

enum Theme {
    /// Colour for a category folder name or a scan group name.
    static func color(forGroup name: String) -> Color {
        if name == ScanGroup.unsorted { return .accentColor }
        if name == ScanGroup.loose { return Category.projects.color }
        return Category(rawValue: name)?.color ?? Color(hex: 0xB8B8B8)
    }
}

/// "4.2 GB", the way Finder writes sizes.
func formatBytes(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}
