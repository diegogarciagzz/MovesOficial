//
//  VoiceInputManager.swift
//  MovesDiego
//

import Foundation
import Speech
import AVFoundation

// @MainActor is required for Swift 6: ObservableObject's @Published properties
// must be updated on the main actor. @MainActor classes are implicitly Sendable,
// which also satisfies the @Sendable requirement on the recognitionTask callback.
@MainActor
class VoiceInputManager: ObservableObject {
    @Published var isListening: Bool = false
    @Published var recognizedText: String = ""
    @Published var errorMessage: String = ""

    weak var game: ChessGame?

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer: SFSpeechRecognizer?

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    // Called from @MainActor UI context — no extra dispatch needed.
    func startListening() {
        guard !isListening else {
            stopListening()
            return
        }

        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            errorMessage = "Enable speech in Settings"
            return
        }

        guard AVAudioSession.sharedInstance().recordPermission == .granted else {
            errorMessage = "Enable microphone in Settings"
            return
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "Speech not available"
            return
        }

        do {
            try startRecognition()
        } catch {
            errorMessage = "Could not start"
            stopListening()
        }
    }

    private func startRecognition() throws {
        stopRecognitionSync()

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true)

        let newEngine = AVAudioEngine()
        audioEngine = newEngine

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = newEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        // Captures only [weak request] — no self, no actor-isolation issue.
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        newEngine.prepare()
        try newEngine.start()

        isListening = true
        recognizedText = "Listening..."
        errorMessage = ""

        // The Speech framework calls this closure on RealtimeMessenger.mServiceQueue
        // (a private background serial queue). We must NOT touch any @MainActor-isolated
        // state here. Instead we capture [weak self] and hop back via Task { @MainActor in }.
        //
        // Using DispatchQueue.main.async here would CRASH with _dispatch_assert_queue_fail
        // because Swift 6 inserts a runtime isolation check at the @MainActor boundary —
        // that check fires before DispatchQueue.main.async can redirect to main.
        //
        // Task { @MainActor in } schedules an async hop and passes the check correctly.
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            // --- Running on RealtimeMessenger.mServiceQueue ---
            // Only read Sendable values from the callback arguments here.
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let hasError = error != nil

            Task { @MainActor [weak self] in
                guard let self else { return }
                if let text {
                    self.recognizedText = text
                    if isFinal {
                        self.processVoiceCommand(text)
                        self.stopListening()
                    }
                }
                if hasError {
                    self.stopListening()
                }
            }
        }
    }

    // Called from @MainActor — no dispatch wrapper needed.
    func stopListening() {
        stopRecognitionSync()
        recognizedText = ""
        isListening = false
    }

    private func stopRecognitionSync() {
        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        // Remove tap BEFORE stopping the engine to avoid the audio render thread
        // still invoking the tap callback while the engine is tearing down.
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        audioEngine = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func processVoiceCommand(_ text: String) {
        guard let game else { return }

        let normalized = text.lowercased()
            .replacingOccurrences(of: " to ", with: " ")
            .replacingOccurrences(of: " ", with: "")

        if normalized.count >= 4 {
            let start = normalized.startIndex
            let fromFile = String(normalized[start])
            let fromRank = Int(String(normalized[normalized.index(after: start)])) ?? 0

            let toStart = normalized.index(normalized.startIndex, offsetBy: 2)
            let toFile = String(normalized[toStart])
            let toRank = Int(String(normalized[normalized.index(after: toStart)])) ?? 0

            let success = game.moveFrom(file: fromFile, rank: fromRank, toFile: toFile, rank: toRank)
            errorMessage = success ? "" : "Invalid move"
        }
    }
}
