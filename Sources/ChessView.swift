//
//  ChessView.swift
//  MovesDiego
//
//  Adaptive layout: landscape (board left + sidebar right)
//                   portrait  (board top  + compact info below)
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
    @State private var showOnboarding        = false

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
            let isLandscape = w > h
            let topH: CGFloat = 56

            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(red: 0.08, green: 0.09, blue: 0.14),
                             Color(red: 0.14, green: 0.17, blue: 0.24)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar(showReset: showResetButton)
                        .frame(height: topH)
                        .padding(.horizontal, 14)

                    if isLandscape {
                        landscapeContent(w: w, h: h, topH: topH)
                    } else {
                        portraitContent(w: w, h: h, topH: topH)
                    }
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
                primaryButton: .default(Text("New Game")) { showDifficultySelection = true },
                secondaryButton: .cancel(Text("Stay")) { showResetButton = true }
            )
        }
        .sheet(isPresented: $showPromotionSheet) { PromotionView(game: game) }
        .sheet(isPresented: $showDifficultySelection, onDismiss: {
            game.resetGame(difficulty: selectedDifficulty)
            // Show onboarding on very first game
            if !UserDefaults.standard.bool(forKey: "hasSeenOnboarding") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    showOnboarding = true
                }
            }
        }) {
            DifficultySelectionView(selectedDifficulty: $selectedDifficulty)
        }
        .overlay {
            if showOnboarding {
                OnboardingView(isPresented: $showOnboarding)
                    .transition(.opacity.animation(.easeInOut(duration: 0.35)))
            }
        }
    }

    // ── LANDSCAPE LAYOUT ─────────────────────────────────────────────────────

    @ViewBuilder
    func landscapeContent(w: CGFloat, h: CGFloat, topH: CGFloat) -> some View {
        let hPad: CGFloat = 14
        let gap: CGFloat  = 12
        // Sidebar: never more than 28% of screen or 230 pts
        let sideW: CGFloat = min(230, w * 0.28)
        // Board fills remaining space, capped by available height
        let availH: CGFloat = h - topH - 16
        let availW: CGFloat = w - hPad * 2 - gap - sideW
        let boardSize: CGFloat = max(200, min(availH, availW))
        let sq = boardSize / 8

        HStack(alignment: .center, spacing: gap) {
            // Board (vertically centered)
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                boardGrid(sq: sq, size: boardSize)
                    .shadow(color: .black.opacity(0.55), radius: 16)
                Spacer(minLength: 0)
            }
            .frame(width: boardSize)

            // Sidebar
            sidebarView(width: sideW)
                .frame(width: sideW)
        }
        .padding(.horizontal, hPad)
        .padding(.bottom, 8)
        .frame(maxHeight: .infinity)
    }

    // ── PORTRAIT LAYOUT ──────────────────────────────────────────────────────

    @ViewBuilder
    func portraitContent(w: CGFloat, h: CGFloat, topH: CGFloat) -> some View {
        let hPad: CGFloat = 12
        // Board: full width minus padding, and no more than 55% of screen height
        let boardSize: CGFloat = max(200, min(w - hPad * 2, h * 0.55))
        let sq = boardSize / 8

        VStack(spacing: 10) {
            boardGrid(sq: sq, size: boardSize)
                .shadow(color: .black.opacity(0.55), radius: 16)
                .frame(maxWidth: .infinity)

            portraitInfoPanel()
                .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, hPad)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    func portraitInfoPanel() -> some View {
        VStack(spacing: 8) {
            capturedView
            recentMovesView
        }
    }

    @ViewBuilder
    var recentMovesView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent Moves")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.45))
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 5)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(movePairs.suffix(8), id: \.moveNumber) { pair in
                        HStack(spacing: 3) {
                            Text("\(pair.moveNumber).")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.4))
                            Text(pair.white ?? "")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                            if let bm = pair.black {
                                Text(bm)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.65))
                            }
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.07))
                        .cornerRadius(7)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .background(Color.black.opacity(0.28))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    // ── TOP BAR ──────────────────────────────────────────────────────────────

    @ViewBuilder
    func topBar(showReset: Bool) -> some View {
        HStack(spacing: 8) {

            // Back button
            Button { dismiss() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
                    Text("Menu").font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.white.opacity(0.12))
                .cornerRadius(10)
            }

            // Voice control button
            Button {
                if speechAuthorized && microphoneAuthorized {
                    voiceManager.startListening()
                } else {
                    voiceManager.errorMessage = "Enable Speech & Mic in Settings"
                }
            } label: {
                HStack(spacing: 7) {
                    ZStack {
                        Circle()
                            .fill(voiceManager.isListening
                                  ? Color.red.opacity(0.3)
                                  : Color(red: 0.52, green: 0.73, blue: 0.88).opacity(0.25))
                            .frame(width: 30, height: 30)
                        Image(systemName: voiceManager.isListening ? "mic.fill" : "mic")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(voiceManager.isListening
                                             ? .red
                                             : Color(red: 0.52, green: 0.73, blue: 0.88))
                            .scaleEffect(voiceManager.isListening ? 1.15 : 1.0)
                            .animation(
                                voiceManager.isListening
                                ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true)
                                : .default,
                                value: voiceManager.isListening
                            )
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(voiceManager.isListening ? "Listening…" : "Voice")
                            .font(.system(size: 12, weight: .semibold))
                        if voiceManager.isListening && !voiceManager.recognizedText.isEmpty
                           && voiceManager.recognizedText != "Listening..."
                           && voiceManager.recognizedText != "Processing..." {
                            Text(voiceManager.recognizedText)
                                .font(.system(size: 10))
                                .opacity(0.7)
                                .lineLimit(1)
                        } else {
                            Text(voiceManager.isListening ? "Tap to stop" : "Tap to speak")
                                .font(.system(size: 10))
                                .opacity(0.55)
                        }
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(
                    voiceManager.isListening
                    ? LinearGradient(colors: [.red.opacity(0.4), .red.opacity(0.25)],
                                     startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(
                        colors: [Color(red: 0.30, green: 0.42, blue: 0.58).opacity(0.5),
                                 Color(red: 0.52, green: 0.73, blue: 0.88).opacity(0.3)],
                        startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            voiceManager.isListening
                            ? Color.red.opacity(0.5)
                            : Color(red: 0.52, green: 0.73, blue: 0.88).opacity(0.35),
                            lineWidth: 1
                        )
                )
            }
            .disabled(!speechAuthorized || !microphoneAuthorized)
            .accessibilityLabel(voiceManager.isListening ? "Stop listening" : "Start voice control")

            // Error message
            if !voiceManager.errorMessage.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 10))
                    Text(voiceManager.errorMessage).font(.system(size: 10)).lineLimit(1)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(Color.red.opacity(0.5))
                .cornerRadius(7)
            } else if !speechAuthorized || !microphoneAuthorized {
                Text("Enable Speech & Mic in Settings")
                    .font(.system(size: 10)).foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(Color.white.opacity(0.08)).cornerRadius(7)
            }

            Spacer()

            // New game button (always shown once game is started)
            if showReset {
                Button {
                    showResetButton = false
                    showDifficultySelection = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .semibold))
                        Text("New Game").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color(red: 0.30, green: 0.42, blue: 0.58).opacity(0.6))
                    .cornerRadius(9)
                }
            }

            // Current player indicator
            HStack(spacing: 5) {
                Circle()
                    .fill(game.currentPlayer == .white ? Color.white : Color(white: 0.18))
                    .frame(width: 9, height: 9)
                    .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
                Text(game.currentPlayer == .white ? "Your turn" : "AI…")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))
            }
            .padding(.horizontal, 9).padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .cornerRadius(8)

            // Check indicator
            if game.isInCheck {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 11))
                    Text("CHECK")
                        .font(.system(size: 11, weight: .heavy))
                }
                .foregroundColor(.red)
                .padding(.horizontal, 9).padding(.vertical, 6)
                .background(Color.red.opacity(0.18))
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
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.black.opacity(0.4), lineWidth: 1)
        )
    }

    @ViewBuilder
    func squareView(row: Int, col: Int, sq: CGFloat) -> some View {
        let isLight = (row + col) % 2 == 0
        let lightColor = Color(red: 0.93, green: 0.91, blue: 0.83)
        let darkColor  = Color(red: 0.47, green: 0.58, blue: 0.34)
        let isSelected = game.selectedPiece.map { $0.position == (row, col) } ?? false

        ZStack {
            // Base square
            Rectangle()
                .fill(isSelected
                      ? (isLight ? Color(red: 1.0, green: 0.85, blue: 0.35)
                                 : Color(red: 0.75, green: 0.65, blue: 0.2))
                      : (isLight ? lightColor : darkColor))
                .frame(width: sq, height: sq)

            // Last move highlight
            if isLastMoveSquare(row: row, col: col) && !isSelected {
                Rectangle()
                    .fill(Color.yellow.opacity(0.42))
                    .frame(width: sq, height: sq)
            }

            // Piece image
            if let piece = game.board[row][col] {
                Image("\(piece.type.rawValue)_\(piece.color.rawValue)")
                    .resizable()
                    .scaledToFit()
                    .frame(width: sq * 0.84, height: sq * 0.84)
                    .onTapGesture {
                        if piece.color == game.currentPlayer {
                            withAnimation(.easeInOut(duration: 0.12)) {
                                game.selectPiece(at: (row, col))
                            }
                        } else if game.selectedPiece != nil &&
                                  game.possibleMoves.contains(where: { $0 == (row, col) }) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                _ = game.movePiece(to: (row, col))
                                if game.promotionPending != nil { showPromotionSheet = true }
                            }
                        }
                    }
            }

            // Possible move indicator
            if game.possibleMoves.contains(where: { $0 == (row, col) }) {
                let isCapture = game.board[row][col] != nil
                Circle()
                    .fill(Color(red: 0.1, green: 0.55, blue: 1.0)
                        .opacity(isCapture ? 0.0 : 0.45))
                    .frame(width: isCapture ? sq * 0.92 : sq * 0.32,
                           height: isCapture ? sq * 0.92 : sq * 0.32)
                    .overlay(
                        isCapture
                        ? Circle()
                            .stroke(Color(red: 0.1, green: 0.55, blue: 1.0).opacity(0.7),
                                    lineWidth: sq * 0.08)
                        : nil
                    )
                    .allowsHitTesting(false)

                // Full-square tap to move
                Color.clear
                    .frame(width: sq, height: sq)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if game.selectedPiece != nil {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                _ = game.movePiece(to: (row, col))
                                if game.promotionPending != nil { showPromotionSheet = true }
                            }
                        }
                    }
            }

            // Coordinate labels
            if col == 0 {
                Text("\(row + 1)")
                    .font(.system(size: max(7, sq * 0.18), weight: .semibold))
                    .foregroundColor((isLight ? darkColor : lightColor).opacity(0.75))
                    .frame(width: sq, height: sq, alignment: .topLeading)
                    .padding(2)
                    .allowsHitTesting(false)
            }
            if row == 0 {
                Text(colFile(col))
                    .font(.system(size: max(7, sq * 0.18), weight: .semibold))
                    .foregroundColor((isLight ? darkColor : lightColor).opacity(0.75))
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
            moveHistoryView
                .frame(maxHeight: .infinity)
            capturedView
        }
        .padding(.vertical, 10)
    }

    @ViewBuilder
    var moveHistoryView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Move History")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(movePairs.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider().background(Color.white.opacity(0.15))

            // Table header
            HStack(spacing: 0) {
                Text("#")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(width: 24)
                Text("White")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Black")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.04))

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
        .background(Color.black.opacity(0.28))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    @ViewBuilder
    func moveRow(pair: (moveNumber: Int, white: String?, black: String?)) -> some View {
        HStack(spacing: 0) {
            Text("\(pair.moveNumber)")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 24)

            HStack(spacing: 3) {
                if let wm = pair.white, let ico = pieceIcon(from: wm, color: .white) {
                    Image(ico).resizable().frame(width: 14, height: 14)
                }
                Text(pair.white ?? "")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 3) {
                if let bm = pair.black, let ico = pieceIcon(from: bm, color: .black) {
                    Image(ico).resizable().frame(width: 14, height: 14)
                }
                Text(pair.black ?? "")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(pair.moveNumber % 2 == 0 ? Color.white.opacity(0.035) : Color.clear)
    }

    @ViewBuilder
    var capturedView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Captured")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                let bal = materialBalance
                if bal != 0 {
                    Text(bal > 0 ? "+\(bal)" : "\(bal)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(bal > 0 ? .green : .red)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Capsule()
                            .fill(bal > 0 ? Color.green.opacity(0.18) : Color.red.opacity(0.18)))
                }
            }
            .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 5)

            Divider().background(Color.white.opacity(0.08)).padding(.horizontal, 12)

            capturedRow(label: "You", pieces: game.capturedByWhite,
                        suffix: "black", dotColor: .white)
            capturedRow(label: "AI",  pieces: game.capturedByBlack,
                        suffix: "white", dotColor: Color(white: 0.3))
        }
        .padding(.bottom, 8)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    @ViewBuilder
    func capturedRow(label: String, pieces: [PieceType], suffix: String, dotColor: Color) -> some View {
        HStack(spacing: 6) {
            HStack(spacing: 3) {
                Circle().fill(dotColor).frame(width: 7, height: 7)
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: dotColor == .white ? 0 : 1))
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 34, alignment: .leading)

            if pieces.isEmpty {
                Text("—").font(.system(size: 11)).foregroundColor(.white.opacity(0.22))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 1) {
                        ForEach(Array(pieces.enumerated()), id: \.offset) { _, type in
                            Image("\(type.rawValue)_\(suffix)")
                                .resizable().frame(width: 19, height: 19)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 4)
    }
}
