import AVFoundation
import Foundation

final class SpeechManager: ObservableObject, @unchecked Sendable {
    static let shared = SpeechManager()
    
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.45
        synthesizer.speak(utterance)
    }
}
