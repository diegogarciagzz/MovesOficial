//  VoiceInputManager.swift
//  MovesDiego
//
//  Created by Diego García
//

import Speech
import AVFoundation
import SwiftUI

@MainActor
final class VoiceInputManager: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var recognizedText = ""
    @Published var lastCommand = ""
    @Published var errorMessage = ""

    private let speechRecognizer: SFSpeechRecognizer? = {
        let locale = Locale(identifier: "en-US")
        return SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(locale: Locale.current)
    }()

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // ✅ FIX CRÍTICO: Controla si el tap está instalado para no crashear al removerlo
    private var hasTapInstalled = false

    weak var game: ChessGame?

    override init() {
        super.init()
    }

    // MARK: - Permisos Seguros
    
    // Función auxiliar simple para permisos (no usada en el flujo principal async)
    nonisolated func requestPermission(completion: @escaping @Sendable (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                completion(status == .authorized)
            }
        }
    }

    // MARK: - Start Listening (Versión Anti-Crash)

    func startListening() {
        if isListening {
            stopListening()
            return
        }

        // ✅ FIX: Usamos Task + async/await para evitar el crash de hilos (dispatch_assert_fail)
        Task {
            // 1. Permiso de Voz
            let speechAuthorized = await requestSpeechPermission()
            guard speechAuthorized else {
                self.errorMessage = "Permiso de voz denegado."
                return
            }

            // 2. Permiso de Micrófono (separado para seguridad)
            let micAuthorized = await requestMicPermission()
            guard micAuthorized else {
                self.errorMessage = "Permiso de micrófono denegado."
                return
            }

            // 3. Todo OK -> Iniciar
            self.beginListeningSession()
        }
    }

    // Wrappers que "pausan" la ejecución sin bloquear hilos incorrectos
    private func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func requestMicPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - Sesión de Audio

    private func beginListeningSession() {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Reconocimiento no disponible."
            return
        }

        // Limpieza segura
        recognitionTask?.cancel()
        recognitionTask = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // ✅ FIX: Solo remover tap si realmente existe
        if hasTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasTapInstalled = false
        }

        // Configurar AudioSession
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Error de micrófono: \(error.localizedDescription)"
            return
        }

        // Request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true

        // Tarea de Reconocimiento
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                Task { @MainActor in
                    self.recognizedText = result.bestTranscription.formattedString
                    
                    if result.isFinal {
                        self.processVoiceCommand(result.bestTranscription.formattedString)
                        self.stopListening()
                    }
                }
            }

            if error != nil {
                Task { @MainActor in
                    self.stopListening()
                }
            }
        }

        // Configurar Input Node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Validación anti-crash de formato
        if recordingFormat.sampleRate == 0 {
            errorMessage = "Error de hardware (SampleRate 0)."
            stopListening()
            return
        }

        // Instalar Tap
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        hasTapInstalled = true // ✅ Marcamos que lo instalamos

        // Arrancar
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
            errorMessage = ""
        } catch {
            errorMessage = "Error motor: \(error.localizedDescription)"
            stopListening()
        }
    }

    func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // ✅ FIX: Limpieza segura del tap
        if hasTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasTapInstalled = false
        }

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        isListening = false
        recognizedText = ""
    }

    // MARK: - Lógica Ajedrez (Tu código original intacto)
    private func processVoiceCommand(_ command: String) {
        let input = command.lowercased()
        print("🎤 Command: \(input)")
        
        if let move = parseMove(from: input) {
            executeMove(move)
        } else {
            // errorMessage = "No entendido: \(command)"
        }
    }

    private func parseMove(from input: String) -> ChessMove? {
        let input = input.lowercased().replacingOccurrences(of: ",", with: "")
        
        var pieceType: PieceType?
        var destination: String?
        
        if input.contains("pawn") { pieceType = .pawn }
        else if input.contains("knight") || input.contains("night") { pieceType = .knight }
        else if input.contains("bishop") { pieceType = .bishop }
        else if input.contains("rook") || input.contains("castle") { pieceType = .rook }
        else if input.contains("queen") { pieceType = .queen }
        else if input.contains("king") { pieceType = .king }
        
        let words = input.split(separator: " ")
        for word in words {
            let w = String(word)
            if w.count == 2, "abcdefgh".contains(w.first!), "12345678".contains(w.last!) {
                destination = w
                break
            }
        }
        
        if destination == nil {
            let numbers = ["one":"1", "two":"2", "three":"3", "four":"4", "five":"5", "six":"6", "seven":"7", "eight":"8"]
            for (word, digit) in numbers {
                if input.contains(word), let file = input.first(where: { "abcdefgh".contains($0) }) {
                    destination = "\(file)\(digit)"
                    break
                }
            }
        }
        
        guard let dest = destination else { return nil }
        return ChessMove(pieceType: pieceType, destination: dest, type: .normal)
    }
    
    private func executeMove(_ move: ChessMove) {
        guard let game = game else { return }
        guard let dest = algebraicToPosition(move.destination) else { return }
        
        var pieces: [(Int, Int)] = []
        
        for row in 0..<8 {
            for col in 0..<8 {
                if let piece = game.board[row][col], piece.color == game.currentPlayer {
                    if let specifiedPiece = move.pieceType {
                        if piece.type != specifiedPiece { continue }
                    }
                    let moves = game.calculateLegalMoves(for: piece)
                    if moves.contains(where: { $0 == dest }) {
                        pieces.append((row, col))
                    }
                }
            }
        }
        
        guard pieces.count == 1 else {
            errorMessage = "Movimiento ambiguo o inválido"
            return
        }
        
        game.selectPiece(at: pieces[0])
        _ = game.movePiece(to: dest)
    }
    
    private func algebraicToPosition(_ algebraic: String) -> (Int, Int)? {
        guard algebraic.count == 2,
              let file = algebraic.first,
              let rank = algebraic.last,
              let col = "abcdefgh".firstIndex(of: file),
              let row = Int(String(rank)),
              (1...8).contains(row) else {
            return nil
        }
        let colIndex = "abcdefgh".distance(from: "abcdefgh".startIndex, to: col)
        return (row - 1, colIndex)
    }
}

// Estructura necesaria
struct ChessMove {
    let pieceType: PieceType?
    let destination: String
    let type: MoveType
    
    enum MoveType {
        case normal
        case castleKingside
        case castleQueenside
    }
    
    init(pieceType: PieceType? = nil, destination: String, type: MoveType = .normal) {
        self.pieceType = pieceType
        self.destination = destination
        self.type = type
    }
}
