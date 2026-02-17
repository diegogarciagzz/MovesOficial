//
//  VoiceInputManager.swift
//  MovesDiego
//
//  Created by Mariana G on 11/02/26.
//

import Foundation
import Speech
import AVFoundation

@MainActor
final class VoiceInputManager: ObservableObject, @unchecked Sendable {
    @Published var isListening = false
    @Published var recognizedText = ""
    @Published var errorMessage = ""

    weak var game: ChessGame?

    private var speechRecognizer: SFSpeechRecognizer?
    nonisolated(unsafe) private var audioEngine = AVAudioEngine()
    nonisolated(unsafe) private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    // MARK: - Public

    func startListening() {
        if isListening {
            stopListening()
            return
        }

        errorMessage = ""

        let status = SFSpeechRecognizer.authorizationStatus()
        switch status {
        case .authorized:
            checkMicrophoneAndProceed()
        case .notDetermined:
            recognizedText = "Requesting permission..."
            SFSpeechRecognizer.requestAuthorization { [weak self] newStatus in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if newStatus == .authorized {
                        self.checkMicrophoneAndProceed()
                    } else {
                        self.errorMessage = "Speech recognition denied"
                        self.recognizedText = ""
                    }
                }
            }
        case .denied:
            errorMessage = "Speech denied. Enable in Settings > Privacy."
        case .restricted:
            errorMessage = "Speech recognition restricted."
        @unknown default:
            errorMessage = "Speech recognition unavailable."
        }
    }

    func stopListening() {
        cleanup()
    }

    // MARK: - Permission chain

    private func checkMicrophoneAndProceed() {
        let micStatus = AVAudioSession.sharedInstance().recordPermission

        switch micStatus {
        case .granted:
            beginRecording()
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if granted {
                        self.beginRecording()
                    } else {
                        self.errorMessage = "Microphone access denied"
                        self.recognizedText = ""
                    }
                }
            }
        case .denied:
            errorMessage = "Microphone denied. Enable in Settings > Privacy."
        @unknown default:
            errorMessage = "Microphone unavailable."
        }
    }

    // MARK: - Recording

    private func beginRecording() {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognizer unavailable"
            return
        }

        // Configure audio session
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement,
                                    options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio setup failed"
            return
        }

        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let result {
                    self.recognizedText = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.processCommand(result.bestTranscription.formattedString)
                        self.stopListening()
                        return
                    }
                }

                if let error {
                    let nsError = error as NSError
                    // 203 = no speech detected timeout, 1700 = recognition cancelled
                    if nsError.code != 203 && nsError.code != 1700 {
                        self.errorMessage = "Error: \(nsError.localizedDescription)"
                    }
                    self.stopListening()
                }
            }
        }

        // Install audio tap
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        guard format.sampleRate > 0, format.channelCount > 0 else {
            errorMessage = "No audio input available"
            cleanup()
            return
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
            recognizedText = "Listening..."
        } catch {
            errorMessage = "Could not start audio"
            cleanup()
        }
    }

    // MARK: - Cleanup

    private func cleanup() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil
        isListening = false

        Task.detached {
            try? AVAudioSession.sharedInstance().setActive(false,
                options: .notifyOthersOnDeactivation)
        }
    }

    // MARK: - Voice command processing

    private func processCommand(_ text: String) {
        guard let game else { return }

        let lower = text.lowercased()
            .replacingOccurrences(of: " one", with: " 1")
            .replacingOccurrences(of: " two", with: " 2")
            .replacingOccurrences(of: " three", with: " 3")
            .replacingOccurrences(of: " four", with: " 4")
            .replacingOccurrences(of: " five", with: " 5")
            .replacingOccurrences(of: " six", with: " 6")
            .replacingOccurrences(of: " seven", with: " 7")
            .replacingOccurrences(of: " eight", with: " 8")
            .replacingOccurrences(of: " to ", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        let squares = extractSquares(from: lower)

        guard squares.count >= 2 else {
            errorMessage = "Say a move like: \"e2 e4\""
            return
        }

        let from = squares[0]
        let to = squares[1]

        let success = game.moveFrom(file: from.file, rank: from.rank,
                                    toFile: to.file, rank: to.rank)
        if !success {
            errorMessage = "Illegal move. Try again."
        }
    }

    private func extractSquares(from text: String) -> [(file: String, rank: Int)] {
        var result: [(String, Int)] = []
        let tokens = text.split(separator: " ")

        for i in 0..<tokens.count {
            let token = String(tokens[i])
            if token.count == 2,
               let f = token.first,
               "abcdefgh".contains(f),
               let r = Int(String(token.last!)),
               (1...8).contains(r) {
                result.append((String(f), r))
                continue
            }
            if i + 1 < tokens.count {
                let next = String(tokens[i + 1])
                if token.count == 1,
                   "abcdefgh".contains(token),
                   let r = Int(next),
                   (1...8).contains(r) {
                    result.append((token, r))
                }
            }
        }
        return result
    }
}
