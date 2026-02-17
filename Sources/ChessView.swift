//
//  ChessView.swift
//  Chess
//
//  Created by Diego García
//

import SwiftUI
import AVFoundation

public struct ChessView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var game: ChessGame
    @State private var showGameOverAlert = false
    @State private var showPromotionSheet = false
    @State private var showResetButton = false
    @State private var showDifficultySelection = true
    @State private var selectedDifficulty: DifficultyLevel = .easy
    @StateObject private var speaker = SpeechManager()
    @StateObject private var voiceManager = VoiceInputManager()

    // Board theme
    private let lightSq = Color(red: 0.93, green: 0.93, blue: 0.82)
    private let darkSq = Color(red: 0.46, green: 0.59, blue: 0.34)
    private let highlight = Color(red: 0.97, green: 0.97, blue: 0.10).opacity(0.55)
    private let bg = Color(red: 0.10, green: 0.10, blue: 0.14)
    private let cardBg = Color.white.opacity(0.05)
    private let fileLabels = ["a", "b", "c", "d", "e", "f", "g", "h"]

    public init() {
        _game = StateObject(wrappedValue: ChessGame(difficulty: .easy))
    }

    // MARK: - Computed

    var gameOverMessage: String {
        if game.isCheckmate {
            return game.currentPlayer == .white ?
                "Checkmate — You lose" : "Checkmate — You win!"
        } else if game.isStalemate {
            return "Stalemate — Draw"
        }
        return ""
    }

    var materialBalance: Int {
        var w = 0, b = 0
        for p in game.capturedByWhite { w += game.pieceValue(p) }
        for p in game.capturedByBlack { b += game.pieceValue(p) }
        return w - b
    }

    var movePairs: [(moveNumber: Int, white: String?, black: String?)] {
        var pairs: [(Int, String?, String?)] = []
        for i in stride(from: 0, to: game.moveHistory.count, by: 2) {
            let num = (i / 2) + 1
            let w = game.moveHistory[i]
            let b = i + 1 < game.moveHistory.count ? game.moveHistory[i + 1] : nil
            pairs.append((num, w, b))
        }
        return pairs
    }

    // MARK: - Helpers

    func pieceIcon(from notation: String, color: PieceColor) -> String? {
        guard let c = notation.first else { return nil }
        let t: String
        switch c {
        case "N": t = "knight"
        case "B": t = "bishop"
        case "R": t = "rook"
        case "Q": t = "queen"
        case "K": t = "king"
        default: t = "pawn"
        }
        return "\(t)_\(color.rawValue)"
    }

    func pieceName(_ piece: ChessPiece?) -> String {
        guard let p = piece else { return "empty" }
        return "\(p.color == .white ? "white" : "black") \(p.type.rawValue)"
    }

    func isLastMove(_ row: Int, _ col: Int) -> Bool {
        if let from = game.lastMovePositions.from, from == (row, col) { return true }
        if let to = game.lastMovePositions.to, to == (row, col) { return true }
        return false
    }

    func isSelected(_ row: Int, _ col: Int) -> Bool {
        guard let sel = game.selectedPiece else { return false }
        return sel.position == (row, col)
    }

    func isPossible(_ row: Int, _ col: Int) -> Bool {
        game.possibleMoves.contains(where: { $0 == (row, col) })
    }

    // MARK: - Body

    public var body: some View {
        GeometryReader { geo in
            let sw = geo.size.width
            let sh = geo.size.height
            let sidebarW = min(sw * 0.26, 340)
            let coordW: CGFloat = 20
            let boardSize = min(sw - sidebarW - 64 - coordW, sh - 180)
            let sq = boardSize / 8

            ZStack {
                bg.ignoresSafeArea()

                HStack(alignment: .top, spacing: 16) {
                    // ── LEFT PANEL ──
                    VStack(spacing: 10) {
                        topBar()
                        voiceButton(width: boardSize + coordW)
                        errorBanner(width: boardSize + coordW)
                        boardWithCoordinates(boardSize: boardSize, sq: sq, coordW: coordW)
                        capturedPieces(width: boardSize + coordW)

                        if showResetButton {
                            Button {
                                showResetButton = false
                                showDifficultySelection = true
                            } label: {
                                Text("New Game")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 48)
                                    .background(darkSq)
                                    .cornerRadius(10)
                            }
                        }
                    }

                    // ── RIGHT SIDEBAR ──
                    moveHistorySidebar(width: sidebarW)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .onAppear {
            voiceManager.game = game
        }
        .onChange(of: game.lastMoveDescription) { description in
            if !description.isEmpty {
                speaker.speak(description)
            }
        }
        .onChange(of: game.isCheckmate) { isCheckmate in
            if isCheckmate { showGameOverAlert = true }
        }
        .onChange(of: game.isStalemate) { isStalemate in
            if isStalemate { showGameOverAlert = true }
        }
        .onChange(of: game.promotionPending) { _ in
            if let promo = game.promotionPending, promo.color == .white {
                showPromotionSheet = true
            } else {
                showPromotionSheet = false
            }
        }
        .alert(isPresented: $showGameOverAlert) {
            Alert(
                title: Text("Game Over"),
                message: Text(gameOverMessage),
                primaryButton: .default(Text("New Game")) {
                    showDifficultySelection = true
                },
                secondaryButton: .cancel {
                    showResetButton = true
                }
            )
        }
        .onChange(of: showGameOverAlert) { isShowing in
            if isShowing {
                let msg: String
                if game.isCheckmate {
                    msg = game.currentPlayer == .white ?
                        "Checkmate. Black wins. Better luck next time" :
                        "Checkmate. White wins. Congratulations"
                } else {
                    msg = "Stalemate. It's a draw"
                }
                speaker.speak(msg)
            }
        }
        .sheet(isPresented: $showPromotionSheet) {
            PromotionView(game: game)
        }
        .sheet(isPresented: $showDifficultySelection, onDismiss: {
            game.resetGame(difficulty: selectedDifficulty)
        }) {
            DifficultySelectionView(selectedDifficulty: $selectedDifficulty)
        }
    }

    // MARK: - Top Bar

    @ViewBuilder
    private func topBar() -> some View {
        HStack {
            Button { dismiss() } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                    Text("Menu")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                .cornerRadius(8)
            }

            Spacer()

            // Turn indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(game.currentPlayer == .white ? Color.white : Color.gray)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))

                Text(game.currentPlayer == .white ? "Your Turn" : "AI Turn")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))

                if game.isInCheck {
                    Text("CHECK")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.red)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.red.opacity(0.15))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(cardBg)
            .cornerRadius(8)
        }
    }

    // MARK: - Voice Button

    @ViewBuilder
    private func voiceButton(width: CGFloat) -> some View {
        Button { voiceManager.startListening() } label: {
            HStack(spacing: 12) {
                Image(systemName: voiceManager.isListening ? "waveform" : "mic.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle().fill(voiceManager.isListening ?
                            Color.red : darkSq)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(voiceManager.isListening ? "Listening..." : "Voice Command")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    Text(voiceManager.recognizedText.isEmpty ?
                         "Say: \"e2 e4\"" : voiceManager.recognizedText)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.45))
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: width)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                voiceManager.isListening ?
                                    Color.red.opacity(0.5) : Color.white.opacity(0.06),
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(voiceManager.isListening ? 1.02 : 1.0)
            .animation(
                voiceManager.isListening ?
                    .easeInOut(duration: 0.7).repeatForever(autoreverses: true) :
                    .default,
                value: voiceManager.isListening
            )
        }
        .accessibilityLabel(voiceManager.isListening ? "Stop listening" : "Start voice control")
    }

    // MARK: - Error Banner

    @ViewBuilder
    private func errorBanner(width: CGFloat) -> some View {
        if !voiceManager.errorMessage.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                Text(voiceManager.errorMessage)
                    .font(.system(size: 13))
            }
            .foregroundColor(.orange)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: width, alignment: .leading)
            .background(Color.orange.opacity(0.08))
            .cornerRadius(8)
        }
    }

    // MARK: - Board with Coordinates

    @ViewBuilder
    private func boardWithCoordinates(boardSize: CGFloat, sq: CGFloat, coordW: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Rank labels (1-8 from bottom to top)
            VStack(spacing: 0) {
                ForEach((0..<8).reversed(), id: \.self) { row in
                    Text("\(row + 1)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.35))
                        .frame(width: coordW, height: sq)
                }
                Spacer().frame(height: 18)
            }

            VStack(spacing: 0) {
                // Board
                VStack(spacing: 0) {
                    ForEach((0..<8).reversed(), id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<8, id: \.self) { col in
                                squareView(row: row, col: col, sq: sq)
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .shadow(color: .black.opacity(0.5), radius: 8, y: 4)

                // File labels (a-h)
                HStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { col in
                        Text(fileLabels[col])
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.35))
                            .frame(width: sq, height: 18)
                    }
                }
            }
        }
    }

    // MARK: - Single Square

    @ViewBuilder
    private func squareView(row: Int, col: Int, sq: CGFloat) -> some View {
        let baseColor = (row + col) % 2 == 0 ? lightSq : darkSq

        ZStack {
            // Base color
            Rectangle()
                .fill(baseColor)
                .frame(width: sq, height: sq)

            // Selected piece highlight
            if isSelected(row, col) {
                Rectangle()
                    .fill(highlight)
                    .frame(width: sq, height: sq)
            }
            // Last move highlight
            else if isLastMove(row, col) {
                Rectangle()
                    .fill(highlight.opacity(0.55))
                    .frame(width: sq, height: sq)
            }

            // Piece
            if let piece = game.board[row][col] {
                Image("\(piece.type.rawValue)_\(piece.color.rawValue)")
                    .resizable()
                    .frame(width: sq * 0.82, height: sq * 0.82)
                    .onTapGesture {
                        if piece.color == game.currentPlayer {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                game.selectPiece(at: (row, col))
                            }
                        }
                    }
            }

            // Possible move indicators + tap target
            if isPossible(row, col) {
                ZStack {
                    if game.board[row][col] != nil {
                        // Capture: ring around the piece
                        Circle()
                            .strokeBorder(Color.black.opacity(0.25), lineWidth: sq * 0.07)
                            .frame(width: sq, height: sq)
                    } else {
                        // Empty: small dot
                        Circle()
                            .fill(Color.black.opacity(0.2))
                            .frame(width: sq * 0.32, height: sq * 0.32)
                    }
                }
                .frame(width: sq, height: sq)
                .contentShape(Rectangle())
                .onTapGesture {
                    if game.selectedPiece != nil {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if !game.movePiece(to: (row, col)) {
                                showGameOverAlert = true
                            } else if game.promotionPending != nil {
                                showPromotionSheet = true
                            }
                        }
                    }
                }
            }
        }
        .accessibilityLabel("Square \(fileLabels[col])\(row + 1), \(pieceName(game.board[row][col]))")
    }

    // MARK: - Captured Pieces

    @ViewBuilder
    private func capturedPieces(width: CGFloat) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Text("You")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 30, alignment: .leading)

                if game.capturedByWhite.isEmpty {
                    Text("--")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.15))
                } else {
                    ForEach(game.capturedByWhite, id: \.self) { type in
                        Image("\(type.rawValue)_black")
                            .resizable()
                            .frame(width: 22, height: 22)
                    }
                }

                Spacer()

                if materialBalance > 0 {
                    Text("+\(materialBalance)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                }
            }

            HStack(spacing: 6) {
                Text("AI")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 30, alignment: .leading)

                if game.capturedByBlack.isEmpty {
                    Text("--")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.15))
                } else {
                    ForEach(game.capturedByBlack, id: \.self) { type in
                        Image("\(type.rawValue)_white")
                            .resizable()
                            .frame(width: 22, height: 22)
                    }
                }

                Spacer()

                if materialBalance < 0 {
                    Text("+\(abs(materialBalance))")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: width)
        .background(cardBg)
        .cornerRadius(10)
    }

    // MARK: - Move History Sidebar

    @ViewBuilder
    private func moveHistorySidebar(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Moves")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(game.moveHistory.count)")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(5)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Divider().background(Color.white.opacity(0.08))

            // Column headers
            HStack(spacing: 0) {
                Text("#")
                    .frame(width: 32)
                Text("White")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Black")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white.opacity(0.3))
            .textCase(.uppercase)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            // Scrollable moves
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(movePairs, id: \.moveNumber) { pair in
                            HStack(spacing: 0) {
                                Text("\(pair.moveNumber)")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.25))
                                    .frame(width: 32)

                                HStack(spacing: 4) {
                                    if let w = pair.white,
                                       let icon = pieceIcon(from: w, color: .white) {
                                        Image(icon)
                                            .resizable()
                                            .frame(width: 16, height: 16)
                                    }
                                    Text(pair.white ?? "")
                                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.85))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                HStack(spacing: 4) {
                                    if let b = pair.black,
                                       let icon = pieceIcon(from: b, color: .black) {
                                        Image(icon)
                                            .resizable()
                                            .frame(width: 16, height: 16)
                                    }
                                    Text(pair.black ?? "")
                                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.85))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(pair.moveNumber % 2 == 0 ?
                                Color.white.opacity(0.03) : Color.clear)
                            .id(pair.moveNumber)
                        }
                    }
                }
                .onChange(of: game.moveHistory.count) { _ in
                    if let last = movePairs.last {
                        withAnimation {
                            proxy.scrollTo(last.moveNumber, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .background(cardBg)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}
