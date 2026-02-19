import AVFoundation
import Speech
import Combine

@MainActor
final class ChessVoiceInput: ObservableObject {
    static let shared = ChessVoiceInput()
    
    @Published var isListening: Bool = false
    @Published var recognizedText: String = ""
    @Published var errorMessage: String = ""
    @Published var state: RecordingState = .idle
    
    weak var game: ChessGame?
    
    // MARK: - AudioRecorder Properties (copiados del código estable)
    private var audioRecorder: AVAudioRecorder?
    private var updateTimer: Timer?
    private var recordingURL: URL {
        let dir = FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("chess_recording.m4a")
    }
    
    enum RecordingState: String {
        case idle, recording
    }
    
    private init() {
        checkPermissions()
    }
    
    // MARK: - Permissions (mejoradas)
    private func checkPermissions() {
        Task {
            let micGranted = await AVAudioApplication.requestRecordPermission()
            let speechStatus = SFSpeechRecognizer.authorizationStatus()
            
            await MainActor.run {
                self.errorMessage = if !micGranted {
                    "Habilita micrófono en Ajustes"
                } else if speechStatus != .authorized {
                    "Habilita dictado en Ajustes"
                } else {
                    ""
                }
            }
        }
    }
    
    // MARK: - Recording (usando AVAudioRecorder estable)
    func startListening() {
        guard state != .recording else { return }
        
        stopEverything()
        
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.record(forDuration: 5.0) // Timeout de 5s para comandos cortos
            state = .recording
            isListening = true
            recognizedText = "Escuchando..."
            
            startUpdateTimer()
            startSpeechRecognition() // Inicia reconocimiento en paralelo
        } catch {
            errorMessage = "Error al iniciar: \(error.localizedDescription)"
            print("[ChessVoice] Error: \(error)")
        }
    }
    
    func stopListening() {
        stopEverything()
        recognizedText = ""
        isListening = false
    }
    
    private func stopEverything() {
        audioRecorder?.stop()
        audioRecorder = nil
        stopUpdateTimer()
        try? AVAudioSession.sharedInstance().setActive(false)
        state = .idle
    }
    
    // MARK: - Speech Recognition (usando archivo temporal)
    private func startSpeechRecognition() {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-MX")), // Cambié a español MX por tu ubicación
              recognizer.isAvailable else {
            errorMessage = "Reconocimiento no disponible"
            return
        }
        
        let request = SFSpeechURLRecognitionRequest(url: recordingURL)
        request.shouldReportPartialResults = false
        
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    self.recognizedText = text
                    self.processChessCommand(text)
                }
                
                if error != nil || result?.isFinal == true {
                    self.stopListening()
                }
            }
        }
    }
    
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // MARK: - Chess Command Processing (tu lógica original mejorada)
    private func processChessCommand(_ text: String) {
        guard let game = game else { return }
        
        let normalized = text.lowercased()
            .replacingOccurrences(of: " a ", with: " ")
            .replacingOccurrences(of: " de ", with: " ")
            .replacingOccurrences(of: " ", with: "")
        
        print("[ChessVoice] Procesando: \(normalized)") // Debug
        
        if normalized.count >= 4 {
            let start = normalized.startIndex
            let fromFile = String(normalized[start])
            let fromRank = Int(String(normalized[normalized.index(after: start)])) ?? 0
            
            let toStart = normalized.index(normalized.startIndex, offsetBy: 2)
            let toFile = String(normalized[toStart])
            let toRank = Int(String(normalized[normalized.index(after: toStart)])) ?? 0
            
            let success = game.moveFrom(file: fromFile, rank: fromRank, toFile: toFile, rank: toRank)
            errorMessage = success ? "" : "Movimiento inválido"
            
            if success {
                SpeechManager.shared.speak("Movimiento realizado")
            }
        }
    }
    
    // MARK: - Timer (copiado del código estable)
    private func startUpdateTimer() {
        stopUpdateTimer()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateUI() }
        }
    }
    
    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func updateUI() {
        // Actualiza UI si es necesario
        if state == .idle {
            stopUpdateTimer()
        }
    }
}
