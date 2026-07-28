import Foundation

/// Mood types for journal entries
enum MoodType: String, CaseIterable {
    case happy
    case calm
    case sad
    case angry
    case excited
    case tired
    case anxious
    case thoughtful

    var emoji: String {
        switch self {
        case .happy: return "😊"
        case .calm: return "😌"
        case .sad: return "😢"
        case .angry: return "😡"
        case .excited: return "🤩"
        case .tired: return "😴"
        case .anxious: return "😰"
        case .thoughtful: return "🤔"
        }
    }

    var localizationKey: String {
        switch self {
        case .happy: return "mood.happy"
        case .calm: return "mood.calm"
        case .sad: return "mood.sad"
        case .angry: return "mood.angry"
        case .excited: return "mood.excited"
        case .tired: return "mood.tired"
        case .anxious: return "mood.anxious"
        case .thoughtful: return "mood.thoughtful"
        }
    }
}
