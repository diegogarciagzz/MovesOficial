//
//  VoiceInputManager.swift
//  MovesDiego
//
//  Created by Mariana G on 11/02/26.
//  REESCRITO DESDE CERO para evitar crashes
//

import Foundation
import Speech
import AVFoundation

@MainActor
@Observable
class VoiceInputManager {
    // MARK: - Published Properties
    var isListening: Bool = false
    var recognizedText: String = ""
    var errorMessage: String = ""
    var isAuthorized: Bool = false
    
    // MARK: - Game Reference
    weak var game: ChessGame?
    
    // MARK: - Private Properties
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer: SFSpeechRecognizer?
    
    // MARK: - Initialization
    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        print("✅ VoiceInputManager initialized")
    }
    
    // MARK: - Permission Management
    func requestPermissions() async {
        print("🎤 Requesting Speech Recognition permission...")
        
        // Request Speech Recognition Permission
        let authStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        print("📋 Speech permission status: \(authStatus.rawValue)")
        
        switch authStatus {
        case .authorized:
            isAuthorized = true
            errorMessage = ""
            print("✅ Speech Recognition authorized")
            
            // Request Microphone Permission
            await requestMicrophonePermission()
            
        case .denied:
            errorMessage = "Speech permission denied"
            isAuthorized = false
            print("❌ Speech Recognition denied")
            
        case .restricted:
            errorMessage = "Speech not available"
            isAuthorized = false
            print("❌ Speech Recognition restricted")
            
        case .notDetermined:
            errorMessage = "Speech permission pending"
            isAuthorized = false
            print("⏳ Speech Recognition not determined")
            
        @unknown default:
            errorMessage = "Unknown permission status"
            isAuthorized = false
            print("❓ Speech Recognition unknown status")
        }
    }
    
    private func requestMicrophonePermission() async {
        print("🎤 Requesting Microphone permission...")
        
        let granted = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        
        if granted {
            print("✅ Microphone permission granted")
            errorMessage = ""
        } else {
            print("❌ Microphone permission denied")
            errorMessage = "Microphone permission denied"
        }
    }
    
    // MARK: - Voice Recognition
    func startListening() {
        print("🎙️ Start listening requested")
        
        // Toggle off if already listening
        if isListening {
            print("⏹️ Already listening, stopping...")
            stopListening()
            return
        }
        
        // Check authorization
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            print("❌ Not authorized for speech recognition")
            errorMessage = "Please allow speech recognition in Settings"
            
            // Request permissions
            Task {
                await requestPermissions()
            }
            return
        }
        
        // Check microphone permission
        guard AVAudioSession.sharedInstance().recordPermission == .granted else {
            print("❌ Microphone permission not granted")
            errorMessage = "Please allow microphone access in Settings"
            return
        }
        
        // Check recognizer availability
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("❌ Speech recognizer not available")
            errorMessage = "Speech recognition not available"
            return
        }
        
        print("✅ All checks passed, starting recognition...")
        
        // Start recognition
        Task {
            do {
                try await startRecognition()
            } catch {
                print("❌ Recognition error: \(error)")
                errorMessage = "Could not start voice recognition"
                stopListening()
            }
        }
    }
    
    private func startRecognition() async throws {
        print("🚀 Starting recognition engine...")
        
        // Stop any existing recognition
        await stopRecognitionEngine()
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        print("✅ Audio session configured")
        
        // Create audio engine
        let newEngine = AVAudioEngine()
        audioEngine = newEngine
        
        let inputNode = newEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        guard recordingFormat.sampleRate > 0 else {
            throw NSError(domain: "VoiceInput", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid audio format"])
        }
        
        print("✅ Audio engine created with sample rate: \(recordingFormat.sampleRate)")
        
        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request
        
        print("✅ Recognition request created")
        
        // Install tap on audio input
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        print("✅ Audio tap installed")
        
        // Start audio engine
        newEngine.prepare()
        try newEngine.start()
        
        print("✅ Audio engine started")
        
        // Update UI state
        isListening = true
        recognizedText = "Listening..."
        errorMessage = ""
        
        // Start recognition task
        guard let recognizer = speechRecognizer else { return }
        
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let result = result {
                    let transcription = result.bestTranscription.formattedString
                    self.recognizedText = transcription
                    print("🗣️ Recognized: \(transcription)")
                    
                    if result.isFinal {
                        print("✅ Final result received")
                        self.processVoiceCommand(transcription)
                        self.stopListening()
                    }
                }
                
                if let error = error {
                    let nsError = error as NSError
                    print("⚠️ Recognition error code: \(nsError.code)")
                    
                    // Ignore timeout and cancellation errors
                    if nsError.code != 203 && nsError.code != 1700 {
                        print("❌ Recognition error: \(error.localizedDescription)")
                    }
                    
                    self.stopListening()
                }
            }
        }
        
        print("✅ Recognition task started")
    }
    
    func stopListening() {
        print("⏹️ Stopping voice recognition...")
        
        Task {
            await stopRecognitionEngine()
        }
        
        recognizedText = ""
        isListening = false
    }
    
    private func stopRecognitionEngine() async {
        print("🛑 Stopping recognition engine...")
        
        // Stop recognition task
        recognitionTask?.cancel()
        recognitionTask = nil
        print("  ✓ Recognition task cancelled")
        
        // End recognition request
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        print("  ✓ Recognition request ended")
        
        // Stop audio engine
        if let engine = audioEngine {
            if engine.isRunning {
                engine.stop()
                print("  ✓ Audio engine stopped")
            }
            
            engine.inputNode.removeTap(onBus: 0)
            print("  ✓ Audio tap removed")
        }
        
        audioEngine = nil
        print("  ✓ Audio engine cleared")
        
        // Deactivate audio session
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        print("  ✓ Audio session deactivated")
        
        print("✅ Recognition engine fully stopped")
    }
    
    // MARK: - Command Processing
    private func processVoiceCommand(_ text: String) {
        print("🎯 Processing command: \(text)")
        
        guard let game = game else {
            print("❌ No game reference")
            errorMessage = "Game not available"
            return
        }
        
        // Normalize input
        let normalized = normalizeText(text)
        print("📝 Normalized: \(normalized)")
        
        // Extract chess squares
        let squares = extractSquares(from: normalized)
        print("📍 Extracted squares: \(squares)")
        
        guard squares.count >= 2 else {
            print("❌ Not enough squares found")
            errorMessage = "Say move like: e2 to e4"
            return
        }
        
        let from = squares[0]
        let to = squares[1]
        
        print("♟️ Attempting move: \(from.file)\(from.rank) → \(to.file)\(to.rank)")
        
        // Execute move
        let success = game.moveFrom(file: from.file, rank: from.rank, toFile: to.file, rank: to.rank)
        
        if success {
            print("✅ Move successful!")
            errorMessage = ""
        } else {
            print("❌ Invalid move")
            errorMessage = "Invalid move: \(from.file)\(from.rank) to \(to.file)\(to.rank)"
        }
    }
    
    // MARK: - Text Processing
    private func normalizeText(_ text: String) -> String {
        return text.lowercased()
            .replacingOccurrences(of: " one", with: " 1")
            .replacingOccurrences(of: " two", with: " 2")
            .replacingOccurrences(of: " three", with: " 3")
            .replacingOccurrences(of: " four", with: " 4")
            .replacingOccurrences(of: " five", with: " 5")
            .replacingOccurrences(of: " six", with: " 6")
            .replacingOccurrences(of: " seven", with: " 7")
            .replacingOccurrences(of: " eight", with: " 8")
            .replacingOccurrences(of: " to ", with: " ")
            .replacingOccurrences(of: " too ", with: " ")
            .replacingOccurrences(of: "knight ", with: "n")
            .replacingOccurrences(of: "bishop ", with: "b")
            .replacingOccurrences(of: "rook ", with: "r")
            .replacingOccurrences(of: "queen ", with: "q")
            .replacingOccurrences(of: "king ", with: "k")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }
    
    private func extractSquares(from text: String) -> [(file: String, rank: Int)] {
        var result: [(String, Int)] = []
        let tokens = text.split(separator: " ")
        
        for i in 0..<tokens.count {
            let token = String(tokens[i])
            
            // Format: "e2" (letter + number)
            if token.count == 2,
               let file = token.first,
               "abcdefgh".contains(file),
               let rank = Int(String(token.last!)),
               (1...8).contains(rank) {
                result.append((String(file), rank))
                continue
            }
            
            // Format: "e 2" (letter space number)
            if i + 1 < tokens.count {
                let next = String(tokens[i + 1])
                if token.count == 1,
                   "abcdefgh".contains(token),
                   let rank = Int(next),
                   (1...8).contains(rank) {
                    result.append((String(token), rank))
                }
            }
        }
        
        return result
    }
}
