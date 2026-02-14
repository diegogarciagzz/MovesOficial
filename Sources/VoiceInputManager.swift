//
//  VoiceInputManager.swift
//  MovesDiego
//
//  Created by Mariana G on 11/02/26.
//

import Foundation
import Speech
import AVFoundation
import Combine

@MainActor
class VoiceInputManager: NSObject, ObservableObject {
    @Published var isListening: Bool = false
    @Published var recognizedText: String = ""
    @Published var errorMessage: String = ""

    weak var game: ChessGame?

    nonisolated(unsafe) private var audioEngine = AVAudioEngine()
    nonisolated(unsafe) private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?

    nonisolated override init() {
        super.init()
        DispatchQueue.main.async {
            let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            Task { @MainActor in
                self.recognizer = recognizer
                self.requestPermissions()
            }
        }
    }

    nonisolated private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                switch status {
                case .authorized:
                    self.errorMessage = ""
                    self.requestMicrophonePermission()
                case .denied:
                    self.errorMessage = "Speech permission denied"
                case .restricted, .notDetermined:
                    self.errorMessage = "Speech not available"
                @unknown default:
                    self.errorMessage = "Unknown error"
                }
            }
        }
    }

    nonisolated private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            Task { @MainActor in
                if !granted {
                    self.errorMessage = "Microphone permission denied"
                }
            }
        }
    }

    func startListening() {
        if isListening {
            stopListening()
            return
        }

        guard let recognizer = recognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognizer not available"
            return
        }

        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            errorMessage = "Speech recognition not authorized"
            return
        }

        let audioSession = AVAudioSession.sharedInstance()
        guard audioSession.recordPermission == .granted else {
            errorMessage = "Microphone permission required"
            return
        }

        errorMessage = ""
        recognizedText = "Listening..."

        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio error: \(error.localizedDescription)"
            return
        }

        request = SFSpeechAudioBufferRecognitionRequest()

        guard let request = request else {
            errorMessage = "Could not create request"
            return
        }

        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Validate the audio format — a zero sample rate means no mic input is available
        guard recordingFormat.sampleRate > 0 else {
            errorMessage = "No audio input available"
            return
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                if let result = result {
                    self.recognizedText = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.processCommand(result.bestTranscription.formattedString)
                        self.stopListening()
                    }
                }

                if let error = error {
                    let nsError = error as NSError
                    // 203 = no speech detected timeout, 1700 = recognition cancelled
                    if nsError.code != 203 && nsError.code != 1700 {
                        self.errorMessage = "Error: \(nsError.localizedDescription)"
                    }
                    self.stopListening()
                }
            }
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
        } catch {
            errorMessage = "Could not start: \(error.localizedDescription)"
            cleanupResources()
        }
    }

    func stopListening() {
        cleanupResources()
    }

    /// Unconditionally tears down audio engine, recognition task and request.
    private func cleanupResources() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)

        request?.endAudio()
        recognitionTask?.cancel()

        request = nil
        recognitionTask = nil
        isListening = false

        Task.detached {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func processCommand(_ text: String) {
        guard let game = game else { return }

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
            errorMessage = "Say: \"e2 e4\""
            return
        }

        let from = squares[0]
        let to = squares[1]

        let success = game.moveFrom(file: from.file, rank: from.rank,
                                    toFile: to.file, rank: to.rank)
        if !success {
            errorMessage = "Illegal move"
        }
    }

    private func extractSquares(from text: String) -> [(file: String, rank: Int)] {
        var result: [(String, Int)] = []
        let tokens = text.split(separator: " ")

        for i in 0..<tokens.count {
            let token = String(tokens[i])
            if token.count == 2, let f = token.first, "abcdefgh".contains(f), let r = Int(String(token.last!)), (1...8).contains(r) {
                result.append((String(f), r))
                continue
            }
            if i + 1 < tokens.count {
                let next = String(tokens[i+1])
                if token.count == 1, "abcdefgh".contains(token), let r = Int(next), (1...8).contains(r) {
                    result.append((String(token), r))
                }
            }
        }
        return result
    }
}
