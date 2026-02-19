//
//  VoiceInputManager.swift
//  MovesDiego
//
//  Adapted from friend's AudioRecorder/PlaybackDelegate pattern:
//  - AVAudioRecorder (NOT AVAudioEngine) to capture audio
//  - SFSpeechURLRecognitionRequest to recognize the recorded file
//  - RecognitionDelegate (@unchecked Sendable, NOT @MainActor) for callbacks
//  - No audio taps, no streaming, no background-queue closures that crash
//

import Foundation
import Speech
import AVFoundation

// ── Speech events forwarded from delegate to main actor ──────────────────
private enum SpeechEvent: Sendable {
    case hypothesis(String)
    case finalResult(String)
    case error
}

// ── Recognition Delegate (same pattern as friend's PlaybackDelegate) ─────
// - NSObject subclass (required by @objc delegate protocols)
// - @unchecked Sendable (NOT @MainActor)
// - Holds only a Sendable continuation — no @MainActor references
// - Methods run on the Speech framework's queue; forwards via AsyncStream
private final class RecognitionDelegate: NSObject, SFSpeechRecognitionTaskDelegate, @unchecked Sendable {
    let continuation: AsyncStream<SpeechEvent>.Continuation

    init(continuation: AsyncStream<SpeechEvent>.Continuation) {
        self.continuation = continuation
        super.init()
    }

    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didHypothesizeTranscription transcription: SFTranscription) {
        continuation.yield(.hypothesis(transcription.formattedString))
    }

    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishRecognition recognitionResult: SFSpeechRecognitionResult) {
        continuation.yield(.finalResult(recognitionResult.bestTranscription.formattedString))
    }

    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully successfully: Bool) {
        if !successfully {
            continuation.yield(.error)
        }
        continuation.finish()
    }

    func speechRecognitionTaskWasCancelled(_ task: SFSpeechRecognitionTask) {
        continuation.finish()
    }
}

// ── Voice Input Manager ──────────────────────────────────────────────────
@MainActor
class VoiceInputManager: ObservableObject {
    @Published var isListening: Bool = false
    @Published var recognizedText: String = ""
    @Published var errorMessage: String = ""

    weak var game: ChessGame?

    // Recording (friend's AVAudioRecorder pattern)
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?

    // Recognition
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionDelegate: RecognitionDelegate?
    private var recognitionContinuation: AsyncStream<SpeechEvent>.Continuation?

    private var recordingURL: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("MovesDiego_VoiceCommand.m4a")
    }

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

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

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
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

        guard FileManager.default.fileExists(atPath: recordingURL.path) else {
            errorMessage = "No recording found"
            isListening = false
            recognizedText = ""
            return
        }

        recognizedText = "Processing..."

        // ── File-based recognition (no AVAudioEngine, no streaming) ──────
        let request = SFSpeechURLRecognitionRequest(url: recordingURL)

        let (stream, continuation) = AsyncStream.makeStream(of: SpeechEvent.self)
        recognitionContinuation = continuation

        let delegate = RecognitionDelegate(continuation: continuation)
        recognitionDelegate = delegate

        recognitionTask = speechRecognizer?.recognitionTask(with: request, delegate: delegate)

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
        recognitionTask = nil
        recognitionDelegate = nil
        recognitionContinuation = nil
        isListening = false
        try? FileManager.default.removeItem(at: recordingURL)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func stopEverything() {
        recordingTimer?.invalidate()
        recordingTimer = nil

        if let recorder = audioRecorder {
            recorder.stop()
            audioRecorder = nil
        }

        recognitionContinuation?.finish()
        recognitionContinuation = nil

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionDelegate = nil

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
