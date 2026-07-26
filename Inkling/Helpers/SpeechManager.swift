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

    /// Available voices, grouped by language (includes personal voices once authorized)
    static func availableVoices() -> [(language: String, voices: [AVSpeechSynthesisVoice])] {
        let all = AVSpeechSynthesisVoice.speechVoices()
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
