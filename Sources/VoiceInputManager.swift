//
//  VoiceInputManager.swift
//  MovesDiego
//

import Foundation
import Speech
import AVFoundation

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
    
    func startListening() {
        DispatchQueue.main.async { [weak self] in
            self?._startListening()
        }
    }
    
    private func _startListening() {
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
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }
        
        newEngine.prepare()
        try newEngine.start()
        
        isListening = true
        recognizedText = "Listening..."
        errorMessage = ""
        
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let text = text {
                    self.recognizedText = text
                    
                    if isFinal {
                        self.processVoiceCommand(text)
                        self.stopListening()
                    }
                }
                
                if error != nil {
                    self.stopListening()
                }
            }
        }
    }
    
    func stopListening() {
        DispatchQueue.main.async { [weak self] in
            self?.stopRecognitionSync()
            self?.recognizedText = ""
            self?.isListening = false
        }
    }
    
    private func stopRecognitionSync() {
        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        // Remove tap BEFORE stopping the engine to avoid a race condition
        // between the audio render thread and engine teardown, which causes
        // a crash on RealtimeMessenger.mServiceQueue.
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        audioEngine = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    private func processVoiceCommand(_ text: String) {
        guard let game = game else { return }
        
        let normalized = text.lowercased()
            .replacingOccurrences(of: " to ", with: " ")
            .replacingOccurrences(of: " ", with: "")
        
        // Simple parser for "e2e4" format
        if normalized.count >= 4 {
            let start = normalized.index(normalized.startIndex, offsetBy: 0)
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
