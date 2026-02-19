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

    // MARK: - Process Move (multi-format parser)
    //
    // Supported formats:
    //   "e4"                → move any piece to e4 (auto-detect)
    //   "knight c3"         → move knight to c3
    //   "bishop c4"         → move bishop to c4
    //   "rook a1"           → move rook to a1
    //   "queen d5"          → move queen to d5
    //   "pawn e4"           → move pawn to e4
    //   "e2 to e4"          → explicit from→to
    //   "pawn e2 to e4"     → piece + from→to (piece is informational, ignored for 2-square moves)
    //   "castle"            → try kingside first, then queenside
    //   "kingside castle"   → kingside castling
    //   "queenside castle"  → queenside castling
    //   "short castle"      → kingside castling
    //   "long castle"       → queenside castling
    //
    // Speech quirks handled:
    //   "sea/see/si" → c,  "dee" → d,  "ee" → e,  "eff" → f,  "gee" → g
    //   "one/won" → 1,  "two/too" → 2,  "three" → 3,  "four/for" → 4, etc.
    //   "night/nite/horse" → knight,  "rock/tower" → rook

    private func processVoiceCommand(_ text: String) {
        guard let game else { return }

        // ── Step 1: Tokenize + normalize ─────────────────────────────────
        var tokens = text.lowercased()
            .trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }

        // Map spoken numbers to digit strings
        let numberMap: [String: String] = [
            "one": "1", "won": "1",
            "two": "2", "too": "2", "tu": "2",
            "three": "3",
            "four": "4", "for": "4", "fore": "4",
            "five": "5",
            "six": "6",
            "seven": "7",
            "eight": "8", "ate": "8"
        ]
        // Map misheard/spoken file letters to actual a–h letters
        let fileLetterMap: [String: String] = [
            "alpha": "a", "ay": "a", "eh": "a",
            "bee": "b", "be": "b",
            "sea": "c", "see": "c", "si": "c", "cee": "c",
            "dee": "d", "di": "d",
            "ee": "e",
            "eff": "f", "ef": "f",
            "gee": "g", "ji": "g", "ge": "g",
            "aitch": "h", "ach": "h", "haitch": "h"
        ]

        tokens = tokens.map { tok in numberMap[tok] ?? fileLetterMap[tok] ?? tok }

        // Remove filler words
        let fillers: Set<String> = [
            "to", "the", "goes", "move", "moves", "takes",
            "captures", "from", "at", "on", "my", "i", "please", "then", "and"
        ]
        tokens = tokens.filter { !fillers.contains($0) }

        let normalized = tokens.joined(separator: " ")

        // ── Step 2: Castling ──────────────────────────────────────────────
        let castleWords: Set<String>    = ["castle", "castling", "castles", "o-o", "0-0"]
        let kingsideWords: Set<String>  = ["kingside", "king", "short"]
        let queensideWords: Set<String> = ["queenside", "queen", "long"]

        let hasCastle    = tokens.contains(where: { castleWords.contains($0) })
        let hasKingside  = tokens.contains(where: { kingsideWords.contains($0) })
        let hasQueenside = tokens.contains(where: { queensideWords.contains($0) })

        // Explicit queenside
        if normalized == "o-o-o" || normalized == "0-0-0"
            || (hasCastle && hasQueenside && !hasKingside) {
            errorMessage = game.castleQueenside() ? "" : "Queenside castling not available"
            return
        }
        // Explicit kingside
        if normalized == "o-o" || normalized == "0-0"
            || (hasCastle && hasKingside && !hasQueenside)
            || (hasKingside && !hasQueenside && !hasCastle == false) {
            errorMessage = game.castleKingside() ? "" : "Kingside castling not available"
            return
        }
        // Plain "castle" → try kingside first, then queenside
        if hasCastle {
            if game.castleKingside() { errorMessage = ""; return }
            if game.castleQueenside() { errorMessage = ""; return }
            errorMessage = "Castling not available right now"
            return
        }

        // ── Step 3: Extract piece type and squares ────────────────────────
        var pieceType: PieceType? = nil
        var squares: [(file: String, rank: Int)] = []
        var i = 0
        let validFiles: Set<Character> = ["a","b","c","d","e","f","g","h"]

        while i < tokens.count {
            let token = tokens[i]

            // Try piece name first
            if let pt = parsePieceToken(token) {
                if pieceType == nil { pieceType = pt }
                i += 1
                continue
            }

            // Try "e4" — single token with letter+digit
            if token.count == 2,
               let firstChar = token.first, validFiles.contains(firstChar),
               let rank = Int(String(token.last!)), (1...8).contains(rank) {
                squares.append((file: String(firstChar), rank: rank))
                i += 1
                continue
            }

            // Try "e" + "4" — two consecutive tokens
            if token.count == 1, let firstChar = token.first, validFiles.contains(firstChar),
               i + 1 < tokens.count,
               let rank = Int(tokens[i + 1]), (1...8).contains(rank) {
                squares.append((file: String(firstChar), rank: rank))
                i += 2
                continue
            }

            i += 1
        }

        // ── Step 4: Execute ───────────────────────────────────────────────
        switch squares.count {
        case 0:
            errorMessage = "Didn't understand — try \"knight c3\" or \"e2 to e4\""

        case 1:
            // "e4", "knight c3", "bishop f5", "queen d4" …
            let dest = squares[0]
            if game.moveToSquare(toFile: dest.file, toRank: dest.rank, pieceType: pieceType) {
                errorMessage = ""
            } else if let pt = pieceType {
                errorMessage = "No \(pt.rawValue) can move to \(dest.file)\(dest.rank)"
            } else {
                errorMessage = "Ambiguous — specify piece: \"knight e4\""
            }

        case 2:
            // "e2 to e4", "pawn e2 to e4", "knight g1 f3" …
            let success = game.moveFrom(file: squares[0].file, rank: squares[0].rank,
                                        toFile: squares[1].file, rank: squares[1].rank)
            if success {
                errorMessage = ""
            } else {
                errorMessage = "Invalid move: \(squares[0].file)\(squares[0].rank) → \(squares[1].file)\(squares[1].rank)"
            }

        default:
            errorMessage = "Too many squares — try \"e2 to e4\""
        }
    }

    // Maps a spoken word to a chess piece type.
    // Note: "b" is intentionally NOT mapped to bishop to avoid conflict
    // with the file letter "b". Say "bishop" instead.
    private func parsePieceToken(_ token: String) -> PieceType? {
        switch token {
        case "pawn", "p":                             return .pawn
        case "knight", "night", "nite", "n", "horse": return .knight
        case "bishop":                                return .bishop
        case "rook", "r", "rock", "tower":            return .rook
        case "queen", "q":                            return .queen
        case "king", "k":                             return .king
        default:                                      return nil
        }
    }
}
