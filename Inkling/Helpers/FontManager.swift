import SwiftUI

/// Font style options for journal content
enum FontStyle: String, CaseIterable {
    case songti = "songti"
    case kaiti = "kaiti"
    case pingfang = "pingfang"

    var displayName: String {
        switch self {
        case .songti: return String(localized: "font.songti")
        case .kaiti: return String(localized: "font.kaiti")
        case .pingfang: return String(localized: "font.pingfang")
        }
    }

    var description: String {
        switch self {
        case .songti: return String(localized: "font.songti_desc")
        case .kaiti: return String(localized: "font.kaiti_desc")
        case .pingfang: return String(localized: "font.pingfang_desc")
        }
    }

    /// Primary font name for journal text
    var fontName: String {
        switch self {
        case .songti: return "Songti SC"
        case .kaiti: return "Kaiti SC"
        case .pingfang: return "PingFang SC"
        }
    }

    /// Preview sample for settings UI
    var sampleText: String {
        "春眠不觉晓，处处闻啼鸟。夜来风雨声，花落知多少。"
    }
}

/// Centralized font settings persisted in UserDefaults
struct FontSettings {
    @AppStorage("fontStyle") static var fontStyle: String = FontStyle.songti.rawValue
    @AppStorage("fontSize") static var fontSize: Double = 18.0

    static var currentStyle: FontStyle {
        FontStyle(rawValue: fontStyle) ?? .songti
    }

    static func journalFont() -> Font {
        .custom(currentStyle.fontName, size: fontSize)
    }

    static func journalFont(size: Double) -> Font {
        .custom(currentStyle.fontName, size: size)
    }
}
