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

    /// Try multiple possible PostScript names to find the correct font
    private var candidateNames: [String] {
        switch self {
        case .songti:
            return ["STSongti-SC-Regular", "Songti SC", "STSongti-SC", "SongtiSC-Regular"]
        case .kaiti:
            return ["STKaitiSC-Regular", "Kaiti SC", "STKaiti-SC-Regular", "KaitiSC-Regular"]
        case .pingfang:
            return ["PingFangSC-Regular", "PingFang SC", "PingFangSC", "PingFang-HK-Regular"]
        }
    }

    /// Get the first available font name, fallback to system serif
    private var resolvedFontName: String {
        for name in candidateNames {
            if let _ = UIFont(name: name, size: 12) {
                return name
            }
        }
        // Ultimate fallback
        switch self {
        case .songti: return "Times New Roman"
        case .kaiti: return "Georgia"
        case .pingfang: return "Helvetica"
        }
    }

    /// Create a Font with the given size, auto-resolving the correct PostScript name
    func makeFont(size: Double) -> Font {
        .custom(resolvedFontName, size: size)
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
        currentStyle.makeFont(size: fontSize)
    }

    static func journalFont(size: Double) -> Font {
        currentStyle.makeFont(size: size)
    }
}
