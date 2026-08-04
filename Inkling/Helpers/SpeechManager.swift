@preconcurrency import AVFoundation
import SwiftUI

@MainActor @Observable
final class SpeechManager: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechManager()

    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?

    private(set) var isSpeaking = false
    var isPaused = false

    override private init() {
        super.init()
        synthesizer.delegate = self
    }

    /// All Chinese voices sorted by quality: AI enhanced → basic. Personal voices excluded.
    static func rankedVoices() -> [AVSpeechSynthesisVoice] {
        let all = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix("zh") && !isPersonalVoice($0)
        }
        let enhanced = all.filter { $0.quality == .premium || $0.quality == .enhanced }
        let basic = all.filter { $0.quality == .default }

        return enhanced.sorted(by: { $0.name < $1.name })
             + basic.sorted(by: { $0.name < $1.name })
    }

    private static func isPersonalVoice(_ voice: AVSpeechSynthesisVoice) -> Bool {
        if #available(iOS 17.0, *) {
            return voice.identifier.lowercased().contains("personal")
        }
        return false
    }

    static func qualityLabel(_ voice: AVSpeechSynthesisVoice) -> String? {
        switch voice.quality {
        case .premium, .enhanced:
            return String(localized: "voice.quality_enhanced")
        case .default:
            return String(localized: "voice.quality_basic")
        @unknown default:
            return nil
        }
    }

    /// Speak the given text using a specific voice
    func speak(_ text: String, voice: AVSpeechSynthesisVoice?, rate: Float) {
        synthesizer.stopSpeaking(at: .word)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice ?? AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = rate
        isSpeaking = true
        isPaused = false
        synthesizer.speak(utterance)
    }

    /// Speak a short sample using a specific voice object
    func preview(voice: AVSpeechSynthesisVoice?, sample: String) {
        synthesizer.stopSpeaking(at: .word)
        let utterance = AVSpeechUtterance(string: sample)
        utterance.voice = voice ?? AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 0.8
        synthesizer.speak(utterance)
    }

    func pause() {
        synthesizer.pauseSpeaking(at: .word)
        isPaused = true
    }

    func resume() {
        synthesizer.continueSpeaking()
        isPaused = false
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        isPaused = false
    }

    /// Wait until speaking finishes
    func waitUntilFinished() async {
        guard isSpeaking else { return }
        await withCheckedContinuation { continuation = $0 }
    }

    // MARK: - AVSpeechSynthesizerDelegate
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
        isPaused = false
        continuation?.resume()
        continuation = nil
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
        isPaused = false
        continuation?.resume()
        continuation = nil
    }
}
