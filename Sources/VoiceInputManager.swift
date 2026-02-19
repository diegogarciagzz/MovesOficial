//
//  VoiceInputManager.swift
//  MovesDiego
//
//  Adapted from friend's AudioRecorder/PlaybackDelegate pattern:
//  - AVAudioRecorder (NOT AVAudioEngine) to capture audio
//  - SFSpeechURLRecognitionRequest to recognize the recorded file
//  - SpeechService is @unchecked Sendable, NOT @MainActor — this is
//    critical because the Speech framework calls back on
//    RealtimeMessenger.mServiceQueue and Swift 6 runtime traps if any
//    @MainActor-isolated state is touched from that queue.
//

import Foundation
import AVFoundation
// @preconcurrency suppresses Swift 6 Sendable/isolation diagnostics AND
// the compiler-emitted runtime checks for Speech framework types.
@preconcurrency import Speech

// ── Speech events (Sendable values only) ─────────────────────────────────
private enum SpeechEvent: Sendable {
    case hypothesis(String)
    case finalResult(String)
    case error
}

// ── Speech Service ───────────────────────────────────────────────────────
// ALL SFSpeechRecognizer / SFSpeechRecognitionTask objects live here.
// This class is NOT @MainActor — its methods and properties can be freely
// accessed from RealtimeMessenger.mServiceQueue without triggering Swift 6
// actor-isolation runtime traps (EXC_BREAKPOINT).
//
// Same pattern as friend's PlaybackDelegate: @unchecked Sendable, NSObject,
// NOT @MainActor. Communicates results through a Sendable AsyncStream.
// ─────────────────────────────────────────────────────────────────────────
private final class SpeechService: @unchecked Sendable {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var task: SFSpeechRecognitionTask?

    var isAvailable: Bool {
        recognizer?.isAvailable ?? false
    }

    /// Recognizes speech from a recorded audio file.
    /// Returns an AsyncStream that yields SpeechEvents from the background queue.
    func recognize(url: URL) -> AsyncStream<SpeechEvent> {
        cancel()

        let (stream, continuation) = AsyncStream.makeStream(of: SpeechEvent.self)
        let request = SFSpeechURLRecognitionRequest(url: url)

        // The closure runs on RealtimeMessenger.mServiceQueue.
        // It captures ONLY `continuation` (Sendable) — no @MainActor state.
        task = recognizer?.recognitionTask(with: request) { result, error in
            if let result {
                if result.isFinal {
                    continuation.yield(.finalResult(result.bestTranscription.formattedString))
                    continuation.finish()
                } else {
                    continuation.yield(.hypothesis(result.bestTranscription.formattedString))
                }
            }
            if error != nil {
                continuation.yield(.error)
                continuation.finish()
            }
        }

        return stream
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}

// ── Voice Input Manager ──────────────────────────────────────────────────
// @MainActor for the UI state (@Published). Does NOT hold any Speech
// framework objects — those are all in SpeechService above.
@MainActor
class VoiceInputManager: ObservableObject {
    @Published var isListening: Bool = false
    @Published var recognizedText: String = ""
    @Published var errorMessage: String = ""

    weak var game: ChessGame?

    // Recording (friend's AVAudioRecorder pattern)
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?

    // Speech recognition — completely isolated from @MainActor
    private let speechService = SpeechService()

    private var recordingURL: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("MovesDiego_VoiceCommand.m4a")
    }

    init() {}

    // MARK: - Public Interface

    /// Toggle: first tap starts recording, second tap stops & recognizes.
    func startListening() {
        if isListening {
            stopRecordingAndRecognize()
            return
        }

        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            errorMessage = "Enable speech in Settings"
            return
        }

        guard AVAudioApplication.shared.recordPermission == .granted else {
            errorMessage = "Enable microphone in Settings"
            return
        }

        guard speechService.isAvailable else {
            errorMessage = "Speech not available"
            return
        }

        startRecording()
    }

    func stopListening() {
        stopEverything()
        recognizedText = ""
        isListening = false
    }

    // MARK: - Recording (friend's exact AVAudioRecorder pattern)

    private func startRecording() {
        stopEverything()

        // Configure session — friend's exact config
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            errorMessage = "Audio session error"
            return
        }

        // Record settings — friend's exact settings
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.record()
            isListening = true
            recognizedText = "Listening..."
            errorMessage = ""

            // Auto-stop after 5 seconds (tap again to stop sooner)
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.stopRecordingAndRecognize()
                }
            }
        } catch {
            errorMessage = "Could not start recording"
        }
    }

    // MARK: - Stop Recording & Recognize File

    private func stopRecordingAndRecognize() {
        recordingTimer?.invalidate()
        recordingTimer = nil

        guard audioRecorder != nil else { return }
        audioRecorder?.stop()
        audioRecorder = nil

        let url = recordingURL

        guard FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = "No recording found"
            isListening = false
            recognizedText = ""
            return
        }

        recognizedText = "Processing..."

        // Deactivate audio session before recognition (no longer recording)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        // ── File-based recognition via SpeechService (NOT @MainActor) ────
        let stream = speechService.recognize(url: url)

        // Drain the stream on the main actor
        Task { @MainActor [weak self] in
            eventLoop: for await event in stream {
                guard let self else { break eventLoop }
                switch event {
                case .hypothesis(let text):
                    self.recognizedText = text
                case .finalResult(let text):
                    self.recognizedText = text
                    self.processVoiceCommand(text)
                    self.cleanupAfterRecognition()
                    break eventLoop
                case .error:
                    self.errorMessage = "Could not recognize speech"
                    self.cleanupAfterRecognition()
                    break eventLoop
                }
            }
        }
    }

    // MARK: - Cleanup

    private func cleanupAfterRecognition() {
        isListening = false
        try? FileManager.default.removeItem(at: recordingURL)
    }

    private func stopEverything() {
        recordingTimer?.invalidate()
        recordingTimer = nil

        if let recorder = audioRecorder {
            recorder.stop()
            audioRecorder = nil
        }

        speechService.cancel()

        try? FileManager.default.removeItem(at: recordingURL)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Process Voice Command

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
