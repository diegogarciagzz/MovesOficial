//
//  VoiceInputManager.swift
//  MovesDiego
//
//  Adapted from friend's AudioRecorder/PlaybackDelegate pattern.
//  Uses AVAudioRecorder (not AVAudioEngine) and pure GCD callbacks
//  (not AsyncStream/Task) to avoid Swift concurrency runtime traps.
//

import Foundation
import AVFoundation
import Speech

// ── Speech Service ───────────────────────────────────────────────────────
// ALL Speech framework objects live here, separate from @MainActor.
// Same pattern as friend's PlaybackDelegate: @unchecked Sendable class
// with simple callbacks dispatched to main queue via DispatchQueue.main.
// No async/await, no Task, no AsyncStream — zero Swift concurrency.
// ─────────────────────────────────────────────────────────────────────────
private final class SpeechService: @unchecked Sendable {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var task: SFSpeechRecognitionTask?

    var isAvailable: Bool {
        recognizer?.isAvailable ?? false
    }

    func recognize(url: URL,
                   onResult: @escaping (String, Bool) -> Void,
                   onError: @escaping () -> Void) {
        cancel()
        let request = SFSpeechURLRecognitionRequest(url: url)
        task = recognizer?.recognitionTask(with: request) { result, error in
            // Runs on RealtimeMessenger.mServiceQueue — no @MainActor here
            if let result {
                let text = result.bestTranscription.formattedString
                let isFinal = result.isFinal
                DispatchQueue.main.async {
                    onResult(text, isFinal)
                }
            } else if error != nil {
                DispatchQueue.main.async {
                    onError()
                }
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}

// ── Voice Input Manager ──────────────────────────────────────────────────
@MainActor
class VoiceInputManager: ObservableObject {
    @Published var isListening: Bool = false
    @Published var recognizedText: String = ""
    @Published var errorMessage: String = ""

    weak var game: ChessGame?

    // Recording — friend's AVAudioRecorder pattern
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?

    // Speech recognition — isolated from @MainActor
    private let speechService = SpeechService()

    private var recordingURL: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("MovesDiego_VoiceCommand.m4a")
    }

    init() {}

    // MARK: - Public

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

    // MARK: - Recording (friend's exact pattern)

    private func startRecording() {
        stopEverything()

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            errorMessage = "Audio session error"
            return
        }

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

            // Auto-stop after 5 seconds
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.stopRecordingAndRecognize()
                }
            }
        } catch {
            errorMessage = "Could not start recording"
        }
    }

    // MARK: - Stop & Recognize

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
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        // Pure GCD callback — no Task, no AsyncStream
        speechService.recognize(url: url, onResult: { [weak self] text, isFinal in
            self?.recognizedText = text
            if isFinal {
                self?.processVoiceCommand(text)
                self?.isListening = false
                try? FileManager.default.removeItem(at: url)
            }
        }, onError: { [weak self] in
            self?.errorMessage = "Could not recognize speech"
            self?.isListening = false
            try? FileManager.default.removeItem(at: url)
        })
    }

    // MARK: - Cleanup

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

    // MARK: - Process Move

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
