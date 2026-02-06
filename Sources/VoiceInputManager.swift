import Speech
import AVFoundation
import SwiftUI

class VoiceInputManager: NSObject, ObservableObject {
    @Published var recognizedMove: String = ""
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    func requestPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                if status == .authorized {
                    print("Speech recognition authorized")
                } else {
                    print("Speech recognition NOT authorized")
                }
            }
        }
    }
    
    func startListening() {
        guard let recognizer = recognizer, recognizer.isAvailable else {
            print("Speech recognizer not available")
            return
        }
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        let inputNode = audioEngine.inputNode
        
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result = result {
                let transcript = result.bestTranscription.formattedString.lowercased()
                self?.recognizedMove = self?.parseMove(transcript) ?? ""
            }
            if error != nil {
                self?.stopListening()
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine failed to start: \(error)")
        }
    }
    
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
    }
    
    private func parseMove(_ input: String) -> String {
        // Simple algebraic notation parser
        let moves = ["e4", "e5", "d4", "d5", "knight f3", "bishop c4"]
        for move in moves {
            if input.contains(move.replacingOccurrences(of: " ", with: "")) {
                return move
            }
        }
        return ""
    }
}
