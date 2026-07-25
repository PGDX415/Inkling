import SwiftUI

enum DisplayMode: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var localizedName: String {
        switch self {
        case .system: return String(localized: "display.system")
        case .light: return String(localized: "display.light")
        case .dark: return String(localized: "display.dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
