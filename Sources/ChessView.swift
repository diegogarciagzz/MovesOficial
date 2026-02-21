//
//  ChessView.swift
//  MovesDiego
//
//  Redesigned for landscape-only layout:
//  [Top bar: back | voice | status | reset]
//  [Board (full height)] | [Sidebar: move history + captured pieces]
//

import SwiftUI
import AVFoundation

public struct ChessView: View {
    @Environment(\.dismiss) var dismiss

    @StateObject private var game: ChessGame
    @State private var showGameOverAlert   = false
    @State private var showPromotionSheet  = false
    @State private var showResetButton     = false
    @State private var showDifficultySelection = true
    @State private var selectedDifficulty: DifficultyLevel = .easy
    @StateObject private var speaker      = SpeechManager()
    @StateObject private var voiceManager = VoiceInputManager()
    @State private var speechAuthorized      = false
    @State private var microphoneAuthorized  = false

    public init() {
        _game = StateObject(wrappedValue: ChessGame(difficulty: .easy))
    }

    // ── Computed helpers ─────────────────────────────────────────────────────

    var gameOverMessage: String {
        if game.isCheckmate {
            return game.currentPlayer == .white ? "Checkmate. You lose 😭" : "Checkmate! You win 🎉"
        } else if game.isStalemate { return "Stalemate!" }
        return ""
    }

    var materialBalance: Int {
        game.capturedByWhite.reduce(0) { $0 + game.pieceValue($1) }
        - game.capturedByBlack.reduce(0) { $0 + game.pieceValue($1) }
    }

    var movePairs: [(moveNumber: Int, white: String?, black: String?)] {
        stride(from: 0, to: game.moveHistory.count, by: 2).map { i in
            (i / 2 + 1,
             game.moveHistory[i],
             i + 1 < game.moveHistory.count ? game.moveHistory[i + 1] : nil)
        }
    }

    func pieceIcon(from notation: String, color: PieceColor) -> String? {
        guard let first = notation.first else { return nil }
        let t: String
        switch first {
        case "N": t = "knight"
        case "B": t = "bishop"
        case "R": t = "rook"
        case "Q": t = "queen"
        case "K": t = "king"
        default:  t = "pawn"
        }
        return "\(t)_\(color.rawValue)"
    }

    func colFile(_ col: Int) -> String { ["a","b","c","d","e","f","g","h"][col] }
    func pieceName(_ p: ChessPiece?) -> String {
        guard let p else { return "empty" }
        return "\(p.color == .white ? "white" : "black") \(p.type.rawValue)"
    }
    func isLastMoveSquare(row: Int, col: Int) -> Bool {
        if let f = game.lastMovePositions.from, f == (row, col) { return true }
        if let t = game.lastMovePositions.to,   t == (row, col) { return true }
        return false
    }

    // ── Body ─────────────────────────────────────────────────────────────────

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let topH: CGFloat = 58

            // Board fills available height; never wider than 46 % of screen
            let boardSize = max(200, min(h - topH - 20, w * 0.46))
            let sq        = boardSize / 8
            // Sidebar gets everything that's left
            let sideW     = max(180, w - boardSize - 48)

            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(red: 0.12, green: 0.12, blue: 0.17),
                             Color(red: 0.20, green: 0.20, blue: 0.26)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // ── TOP BAR ───────────────────────────────────────────
                    topBar(showReset: showResetButton)
                        .frame(height: topH)
                        .padding(.horizontal, 16)

                    // ── MAIN CONTENT ──────────────────────────────────────
                    HStack(alignment: .center, spacing: 0) {

                        // Left: chess board (centered vertically)
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            boardGrid(sq: sq, size: boardSize)
                                .shadow(color: .black.opacity(0.5), radius: 14)
                            Spacer(minLength: 0)
                        }
                        .frame(width: boardSize)

                        Spacer(minLength: 16)

                        // Right: sidebar
                        sidebarView(width: sideW)
                            .frame(width: sideW)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                    .frame(maxHeight: .infinity)
                }
            }
        }
        .onAppear {
            voiceManager.game = game
            let p = PermissionsManager.shared.checkPermissions()
            speechAuthorized     = p.speech
            microphoneAuthorized = p.mic
        }
        .onDisappear { voiceManager.stopListening() }
        .onChange(of: game.lastMoveDescription) { desc in
            if !desc.isEmpty { speaker.speak(desc) }
        }
        .onChange(of: game.isCheckmate) { v in if v { showGameOverAlert = true } }
        .onChange(of: game.isStalemate) { v in if v { showGameOverAlert = true } }
        .onChange(of: game.promotionPending) { _ in
            showPromotionSheet = game.promotionPending?.color == .white
        }
        .onChange(of: showGameOverAlert) { showing in
            guard showing else { return }
            let msg = game.isCheckmate
                ? (game.currentPlayer == .white ? "Checkmate. Black wins." : "Checkmate. White wins.")
                : "Stalemate. It's a draw."
            speaker.speak(msg)
        }
        .alert(isPresented: $showGameOverAlert) {
            Alert(
                title: Text("Game Over"),
                message: Text(gameOverMessage),
                primaryButton: .default(Text("Reset")) { showDifficultySelection = true },
                secondaryButton: .cancel { showResetButton = true }
            )
        }
        .sheet(isPresented: $showPromotionSheet) { PromotionView(game: game) }
        .sheet(isPresented: $showDifficultySelection, onDismiss: {
            game.resetGame(difficulty: selectedDifficulty)
        }) {
            DifficultySelectionView(selectedDifficulty: $selectedDifficulty)
        }
    }

    // ── TOP BAR ──────────────────────────────────────────────────────────────

    @ViewBuilder
    func topBar(showReset: Bool) -> some View {
        HStack(spacing: 10) {

            // Back button
            Button { dismiss() } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.left").font(.system(size: 14, weight: .semibold))
                    Text("Menu").font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color.white.opacity(0.14))
                .cornerRadius(10)
            }

            // Voice button
            Button {
                if speechAuthorized && microphoneAuthorized {
                    voiceManager.startListening()
                } else {
                    voiceManager.errorMessage = "Enable Speech & Mic in Settings"
                }
            } label: {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(voiceManager.isListening ? Color.red.opacity(0.25) : Color.blue.opacity(0.22))
                            .frame(width: 32, height: 32)
                        Image(systemName: voiceManager.isListening ? "mic.fill" : "mic")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(voiceManager.isListening ? .red : .white)
                            .scaleEffect(voiceManager.isListening ? 1.12 : 1.0)
                            .animation(
                                voiceManager.isListening
                                ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                                : .default,
                                value: voiceManager.isListening
                            )
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(voiceManager.isListening ? "Listening…" : "Voice Control")
                            .font(.system(size: 13, weight: .semibold))
                        Group {
                            if voiceManager.isListening && !voiceManager.recognizedText.isEmpty
                               && voiceManager.recognizedText != "Listening..."
                               && voiceManager.recognizedText != "Processing..." {
                                Text(voiceManager.recognizedText).lineLimit(1)
                            } else {
                                Text(voiceManager.isListening
                                     ? "Tap to stop"
                                     : "\"e4\" · \"knight c3\" · \"e2 to e4\" · \"castle\"")
                            }
                        }
                        .font(.system(size: 10))
                        .opacity(0.65)
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(
                    voiceManager.isListening
                    ? LinearGradient(colors: [.red.opacity(0.45), .red.opacity(0.3)],
                                     startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [.blue.opacity(0.38), .blue.opacity(0.22)],
                                     startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(18)
                .shadow(color: voiceManager.isListening ? .red.opacity(0.35) : .blue.opacity(0.25), radius: 6)
            }
            .disabled(!speechAuthorized || !microphoneAuthorized)
            .accessibilityLabel(voiceManager.isListening ? "Stop listening" : "Start voice control")

            // Error / permissions indicator
            if !voiceManager.errorMessage.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11))
                    Text(voiceManager.errorMessage).font(.system(size: 11)).lineLimit(1)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.red.opacity(0.55))
                .cornerRadius(8)
            } else if !speechAuthorized || !microphoneAuthorized {
                Text("Enable Speech & Mic in Settings")
                    .font(.system(size: 10)).foregroundColor(.white.opacity(0.55))
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(Color.white.opacity(0.1)).cornerRadius(7)
            }

            Spacer()

            // Reset button (shown after game ends)
            if showReset {
                Button {
                    showResetButton = false
                    showDifficultySelection = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.clockwise").font(.system(size: 12, weight: .semibold))
                        Text("New Game").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Color.blue.opacity(0.45))
                    .cornerRadius(10)
                }
            }

            // Current player indicator
            HStack(spacing: 5) {
                Circle()
                    .fill(game.currentPlayer == .white ? Color.white : Color.black)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1))
                Text(game.currentPlayer == .white ? "Your turn" : "AI thinking…")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .cornerRadius(8)

            // Check indicator
            if game.isInCheck {
                Text("CHECK!")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(.red)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(8)
            }
        }
    }

    // ── CHESS BOARD ───────────────────────────────────────────────────────────

    @ViewBuilder
    func boardGrid(sq: CGFloat, size: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach((0..<8).reversed(), id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { col in
                        squareView(row: row, col: col, sq: sq)
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    @ViewBuilder
    func squareView(row: Int, col: Int, sq: CGFloat) -> some View {
        let isLight = (row + col) % 2 == 0
        let lightColor = Color(red: 0.93, green: 0.91, blue: 0.83)
        let darkColor  = Color(red: 0.47, green: 0.58, blue: 0.34)

        ZStack {
            // Base square color (wooden green-white chess style)
            Rectangle()
                .fill(isLight ? lightColor : darkColor)
                .frame(width: sq, height: sq)

            // Last move highlight
            if isLastMoveSquare(row: row, col: col) {
                Rectangle()
                    .fill(Color.yellow.opacity(0.45))
                    .frame(width: sq, height: sq)
            }

            // Piece
            if let piece = game.board[row][col] {
                Image("\(piece.type.rawValue)_\(piece.color.rawValue)")
                    .resizable()
                    .scaledToFit()
                    .frame(width: sq * 0.82, height: sq * 0.82)
                    .onTapGesture {
                        if piece.color == game.currentPlayer {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                game.selectPiece(at: (row, col))
                            }
                        }
                    }
            }

            // Possible move dot
            if game.possibleMoves.contains(where: { $0 == (row, col) }) {
                Circle()
                    .fill(Color.blue.opacity(game.board[row][col] == nil ? 0.40 : 0.65))
                    .frame(width: game.board[row][col] == nil ? sq * 0.3 : sq * 0.88,
                           height: game.board[row][col] == nil ? sq * 0.3 : sq * 0.88)
                    .allowsHitTesting(false)
                    .overlay(
                        game.board[row][col] != nil
                        ? Circle().stroke(Color.blue.opacity(0.8), lineWidth: 2)
                        : nil
                    )
                    .onTapGesture {  // tap the square itself to move when piece is there
                        if game.selectedPiece != nil {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if game.movePiece(to: (row, col)) {
                                    if game.promotionPending != nil { showPromotionSheet = true }
                                } else {
                                    showGameOverAlert = true
                                }
                            }
                        }
                    }
            }

            // Transparent tap area for moving to empty possible-move squares
            if game.possibleMoves.contains(where: { $0 == (row, col) }) {
                Color.clear
                    .frame(width: sq, height: sq)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if game.selectedPiece != nil {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if game.movePiece(to: (row, col)) {
                                    if game.promotionPending != nil { showPromotionSheet = true }
                                } else {
                                    showGameOverAlert = true
                                }
                            }
                        }
                    }
            }

            // Coordinate labels (rank on left col, file on bottom row)
            if col == 0 {
                Text("\(row + 1)")
                    .font(.system(size: max(8, sq * 0.18), weight: .semibold))
                    .foregroundColor(isLight ? darkColor : lightColor)
                    .frame(width: sq, height: sq, alignment: .topLeading)
                    .padding(2)
                    .allowsHitTesting(false)
            }
            if row == 0 {
                Text(colFile(col))
                    .font(.system(size: max(8, sq * 0.18), weight: .semibold))
                    .foregroundColor(isLight ? darkColor : lightColor)
                    .frame(width: sq, height: sq, alignment: .bottomTrailing)
                    .padding(2)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityLabel("Square \(colFile(col))\(row + 1), \(pieceName(game.board[row][col]))")
    }

    // ── SIDEBAR ───────────────────────────────────────────────────────────────

    @ViewBuilder
    func sidebarView(width: CGFloat) -> some View {
        VStack(spacing: 8) {

            // Move history (fills remaining vertical space)
            VStack(alignment: .leading, spacing: 0) {

                HStack {
                    Text("Move History")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(movePairs.count) moves")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 6)

                Divider().background(Color.white.opacity(0.2))

                // Table header
                HStack(spacing: 0) {
                    Text("#").font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.5)).frame(width: 28)
                    Text("White").font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.5)).frame(maxWidth: .infinity, alignment: .leading)
                    Text("Black").font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.5)).frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.04))

                // Scrollable rows (auto-scrolls to latest)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(movePairs, id: \.moveNumber) { pair in
                                moveRow(pair: pair)
                                    .id(pair.moveNumber)
                            }
                        }
                    }
                    .onChange(of: game.moveHistory.count) { _ in
                        if let last = movePairs.last {
                            withAnimation { proxy.scrollTo(last.moveNumber, anchor: .bottom) }
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .background(Color.black.opacity(0.28))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))

            // Captured pieces (fixed at bottom)
            capturedView
        }
        .padding(.vertical, 10)
    }

    @ViewBuilder
    func moveRow(pair: (moveNumber: Int, white: String?, black: String?)) -> some View {
        HStack(spacing: 0) {
            Text("\(pair.moveNumber)")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 28)

            // White move
            HStack(spacing: 4) {
                if let wm = pair.white, let ico = pieceIcon(from: wm, color: .white) {
                    Image(ico).resizable().frame(width: 16, height: 16)
                }
                Text(pair.white ?? "")
                    .font(.system(size: 13))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Black move
            HStack(spacing: 4) {
                if let bm = pair.black, let ico = pieceIcon(from: bm, color: .black) {
                    Image(ico).resizable().frame(width: 16, height: 16)
                }
                Text(pair.black ?? "")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(pair.moveNumber % 2 == 0 ? Color.white.opacity(0.04) : Color.clear)
    }

    @ViewBuilder
    var capturedView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Captured Pieces")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.75))
                Spacer()
                let bal = materialBalance
                if bal != 0 {
                    Text(bal > 0 ? "+\(bal)" : "\(bal)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(bal > 0 ? .green : .red)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(bal > 0 ? Color.green.opacity(0.2) : Color.red.opacity(0.2)))
                }
            }
            .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 6)

            Divider().background(Color.white.opacity(0.1)).padding(.horizontal, 14)

            // You
            capturedRow(label: "You", pieces: game.capturedByWhite, suffix: "black", dotColor: .white)
            // AI
            capturedRow(label: "AI",  pieces: game.capturedByBlack, suffix: "white", dotColor: Color(white: 0.35))
        }
        .padding(.bottom, 8)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    @ViewBuilder
    func capturedRow(label: String, pieces: [PieceType], suffix: String, dotColor: Color) -> some View {
        HStack(spacing: 6) {
            HStack(spacing: 4) {
                Circle().fill(dotColor).frame(width: 8, height: 8)
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: dotColor == .white ? 0 : 1))
                Text(label).font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
            }
            .frame(width: 36, alignment: .leading)

            if pieces.isEmpty {
                Text("—").font(.system(size: 12)).foregroundColor(.white.opacity(0.25))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(Array(pieces.enumerated()), id: \.offset) { _, type in
                            Image("\(type.rawValue)_\(suffix)")
                                .resizable().frame(width: 20, height: 20)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 4)
    }
}
