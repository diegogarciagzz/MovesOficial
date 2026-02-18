//
//  VoiceInputManager.swift
//  MovesDiego
//

import Foundation
import Speech
import AVFoundation

// Events forwarded from the delegate (background queue) to the main actor.
// All cases are Sendable because they only contain String values.
private enum SpeechEvent: Sendable {
    case hypothesis(String)
    case finalResult(String)
    case error
}

// ── Recognition Delegate ────────────────────────────────────────────────
// Same pattern as the friend's PlaybackDelegate:
//   - NSObject subclass (required by @objc delegate protocols)
//   - @unchecked Sendable (NOT @MainActor — lives on whatever queue the
//     Speech framework uses, i.e. RealtimeMessenger.mServiceQueue)
//   - Holds only a Sendable continuation — no @MainActor state
//   - Forwards events through the AsyncStream; the main actor drains it
//
// Using recognitionTask(with:delegate:) instead of the closure version
// completely eliminates the @Sendable closure that caused the crash.
// ─────────────────────────────────────────────────────────────────────────
private final class RecognitionDelegate: NSObject, SFSpeechRecognitionTaskDelegate, @unchecked Sendable {
    let continuation: AsyncStream<SpeechEvent>.Continuation

    init(continuation: AsyncStream<SpeechEvent>.Continuation) {
        self.continuation = continuation
        super.init()
    }

    // Called repeatedly with partial transcriptions
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didHypothesizeTranscription transcription: SFTranscription) {
        continuation.yield(.hypothesis(transcription.formattedString))
    }

    // Called once with the final recognized result
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishRecognition recognitionResult: SFSpeechRecognitionResult) {
        continuation.yield(.finalResult(recognitionResult.bestTranscription.formattedString))
    }

    // Called when the task ends (successfully or not)
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully successfully: Bool) {
        if !successfully {
            continuation.yield(.error)
        }
        continuation.finish()
    }

    // Called if the task was cancelled (e.g. from stopListening)
    func speechRecognitionTaskWasCancelled(_ task: SFSpeechRecognitionTask) {
        continuation.finish()
    }
}

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

    // Keep strong references so they stay alive while recognition is active.
    private var recognitionDelegate: RecognitionDelegate?
    private var recognitionContinuation: AsyncStream<SpeechEvent>.Continuation?

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

        // ── Audio Session ──────────────────────────────────────────────────
        // Use mode: .default (like the friend's code) instead of .measurement.
        // .measurement can trigger internal dispatch_assert_queue assertions
        // in Swift Playgrounds on iOS 18.
        // ────────────────────────────────────────────────────────────────────
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default,
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

        // ── Delegate bridge (friend's PlaybackDelegate pattern) ────────────
        // 1. Create an AsyncStream with a Sendable continuation
        // 2. Give the continuation to a RecognitionDelegate (@unchecked Sendable)
        // 3. Use recognitionTask(with:delegate:) — NO closure to the framework
        // 4. Drain the stream on @MainActor
        //
        // The delegate's methods run on RealtimeMessenger.mServiceQueue.
        // Because the delegate is NOT @MainActor, there is no isolation check
        // and no _dispatch_assert_queue_fail crash.
        // ────────────────────────────────────────────────────────────────────
        let (stream, continuation) = AsyncStream.makeStream(of: SpeechEvent.self)
        recognitionContinuation = continuation

        let delegate = RecognitionDelegate(continuation: continuation)
        recognitionDelegate = delegate

        recognitionTask = speechRecognizer?.recognitionTask(with: request, delegate: delegate)

        // Drain the stream on the main actor.
        Task { @MainActor [weak self] in
            eventLoop: for await event in stream {
                guard let self, self.isListening else { break eventLoop }
                switch event {
                case .hypothesis(let text):
                    self.recognizedText = text
                case .finalResult(let text):
                    self.recognizedText = text
                    self.processVoiceCommand(text)
                    self.stopListening()
                    break eventLoop
                case .error:
                    self.stopListening()
                    break eventLoop
                }
            }
        }
    }

    func stopListening() {
        guard isListening else { return }
        // Finish the stream immediately so the for-await loop exits
        // without waiting for the delegate callback.
        recognitionContinuation?.finish()
        recognitionContinuation = nil
        stopRecognitionSync()
        recognizedText = ""
        isListening = false
    }

    private func stopRecognitionSync() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionDelegate = nil

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
