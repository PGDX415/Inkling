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

    /// Request authorization to use Personal Voice (iOS 17+)
    static func requestPersonalVoiceAuth() async -> Bool {
        await withCheckedContinuation { continuation in
            AVSpeechSynthesizer.requestPersonalVoiceAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Personal voices the user has created (iOS 17+)
    /// Authorization must be granted first for personal voices to appear in the list
    static func personalVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { voice in
            // Personal voices have identifiers that differ from bundled voices
            // Detect them by checking if the identifier is NOT a known Apple bundled voice pattern
            let id = voice.identifier.lowercased()
            let isBundled = id.contains("com.apple.ttsbundle") || id.contains("com.apple.voice")
            // Personal voice identifiers typically contain "personal" or look like generated UUIDs
            let isPersonal = id.contains("personal") || (!isBundled && voice.quality != .default)
            return isPersonal
        }
    }

    /// Available voices, grouped by language (excluding personal voices)
    static func availableVoices() -> [(language: String, voices: [AVSpeechSynthesisVoice])] {
        let personalIds = Set(Self.personalVoices().map { $0.identifier })
        let all = AVSpeechSynthesisVoice.speechVoices().filter { !personalIds.contains($0.identifier) }
        let grouped = Dictionary(grouping: all) { voice in
            Locale.current.localizedString(forIdentifier: voice.language) ?? voice.language
        }
        return grouped
            .map { (language: $0.key, voices: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.language < $1.language }
    }

    /// Speak the given text
    func speak(_ text: String, voiceIdentifier: String, rate: Float) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier)
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        isSpeaking = true
        isPaused = false
        synthesizer.speak(utterance)
    }

    /// Speak a short sample for voice preview
    func preview(voiceIdentifier: String, sample: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: sample)
        utterance.voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier)
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
