//
//  VoiceInputManager.swift
//  MovesDiego
//

import Foundation
import Speech
import AVFoundation

// @MainActor is required for Swift 6: ObservableObject's @Published properties
// must be updated on the main actor. @MainActor classes are implicitly Sendable.
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

    // Sendable bridge between RealtimeMessenger.mServiceQueue and the main actor.
    // Storing it here lets stopListening() finish the stream immediately
    // without waiting for the recognition task callback.
    private var recognitionContinuation: AsyncStream<(String?, Bool, Bool)>.Continuation?

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

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
        // .playAndRecord is more compatible than .record in Swift Playgrounds
        // and with other active audio (SpeechManager synthesizer, sounds).
        try audioSession.setCategory(.playAndRecord, mode: .measurement,
                                     options: [.duckOthers, .defaultToSpeaker])
        try audioSession.setActive(true)

        let newEngine = AVAudioEngine()
        audioEngine = newEngine

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = newEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        // Captures [weak request] only — no self, no @MainActor state.
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        newEngine.prepare()
        try newEngine.start()

        isListening = true
        recognizedText = "Listening..."
        errorMessage = ""

        // ── Sendable bridge ──────────────────────────────────────────────────
        // The Speech framework calls the recognition closure on
        // RealtimeMessenger.mServiceQueue. Capturing [weak self] there —
        // even inside Task { @MainActor in } — can cause _dispatch_assert_queue_fail
        // because Swift 6 may instrument the @Sendable closure boundary with a
        // @MainActor isolation check.
        //
        // Solution: capture ONLY `continuation`, which is Sendable.
        // No self, no @MainActor state is ever touched on the background queue.
        // ─────────────────────────────────────────────────────────────────────
        let (stream, continuation) = AsyncStream.makeStream(of: (String?, Bool, Bool).self)
        recognitionContinuation = continuation

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { result, error in
            // ── Running on RealtimeMessenger.mServiceQueue ──
            // Only Sendable values. No self. No @MainActor access. No crash.
            continuation.yield((
                result?.bestTranscription.formattedString,
                result?.isFinal ?? false,
                error != nil
            ))
            if result?.isFinal == true || error != nil {
                continuation.finish()
            }
        }

        // Drain the stream on the main actor.
        Task { @MainActor [weak self] in
            for await (text, isFinal, hasError) in stream {
                guard let self, self.isListening else { break }
                if hasError {
                    self.stopListening()
                    break
                }
                if let text {
                    self.recognizedText = text
                    if isFinal {
                        self.processVoiceCommand(text)
                        self.stopListening()
                        break
                    }
                }
            }
        }
    }

    func stopListening() {
        guard isListening else { return }
        // Finish the stream immediately so the for-await loop exits
        // without waiting for the recognition task callback.
        recognitionContinuation?.finish()
        recognitionContinuation = nil
        stopRecognitionSync()
        recognizedText = ""
        isListening = false
    }

    private func stopRecognitionSync() {
        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        // Remove tap BEFORE stopping engine to prevent a race between
        // the audio render thread and engine teardown.
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

            let success = game.moveFrom(file: fromFile, rank: fromRank,
                                        toFile: toFile, rank: toRank)
            errorMessage = success ? "" : "Invalid move"
        }
    }
}
