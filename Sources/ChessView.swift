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

            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(red: 0.08, green: 0.09, blue: 0.14),
                             Color(red: 0.14, green: 0.17, blue: 0.24)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if isLandscape {
                    landscapeLayout(w: w, h: h)
                } else {
                    portraitLayout(w: w, h: h)
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

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - LANDSCAPE LAYOUT
    // ═══════════════════════════════════════════════════════════════════════

    @ViewBuilder
    func landscapeLayout(w: CGFloat, h: CGFloat) -> some View {
        let pad: CGFloat   = 10
        let gap: CGFloat   = 10
        let topH: CGFloat  = 48
        let voiceH: CGFloat = 54

        // Board: square, driven strictly by available height
        let availH  = h - topH - voiceH - pad * 2 - 4
        let sideW: CGFloat = min(210, w * 0.26)
        let availW  = w - pad * 2 - gap - sideW
        let boardSize = max(160, min(availH, availW))
        let sq = boardSize / 8

        VStack(spacing: 0) {
            // ── Top strip: back, status, reset ───────────────────
            landscapeTopBar
                .frame(height: topH)
                .padding(.horizontal, pad)

            // ── Voice button: full width, prominent ──────────────
            voiceButton
                .frame(height: voiceH)
                .padding(.horizontal, pad)

            // ── Board + Sidebar ──────────────────────────────────
            HStack(alignment: .center, spacing: gap) {
                boardGrid(sq: sq, size: boardSize)
                    .shadow(color: .black.opacity(0.55), radius: 12)

                sidebarView(width: sideW)
                    .frame(width: sideW)
            }
            .padding(.horizontal, pad)
            .padding(.vertical, pad)
            .frame(maxHeight: .infinity)
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - PORTRAIT LAYOUT
    // ═══════════════════════════════════════════════════════════════════════

    @ViewBuilder
    func portraitLayout(w: CGFloat, h: CGFloat) -> some View {
        let pad: CGFloat   = 10
        let topH: CGFloat  = 48
        let voiceH: CGFloat = 56

        // Board: full width, capped so info panel still fits
        let boardSize = max(160, min(w - pad * 2, h - topH - voiceH - 140))
        let sq = boardSize / 8

        VStack(spacing: 0) {
            portraitTopBar
                .frame(height: topH)
                .padding(.horizontal, pad)

            voiceButton
                .frame(height: voiceH)
                .padding(.horizontal, pad)

            boardGrid(sq: sq, size: boardSize)
                .shadow(color: .black.opacity(0.55), radius: 12)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, pad)
                .padding(.top, 4)

            portraitInfoPanel()
                .padding(.horizontal, pad)
                .padding(.top, 6)
                .frame(maxHeight: .infinity)

            Spacer(minLength: 4)
        }
    }

    @ViewBuilder
    func portraitInfoPanel() -> some View {
        VStack(spacing: 6) {
            capturedView
            recentMovesView
        }
    }

    @ViewBuilder
    var recentMovesView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent Moves")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
                .padding(.horizontal, 10)
                .padding(.top, 7)
                .padding(.bottom, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(movePairs.suffix(8), id: \.moveNumber) { pair in
                        HStack(spacing: 3) {
                            Text("\(pair.moveNumber).")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.4))
                            Text(pair.white ?? "")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                            if let bm = pair.black {
                                Text(bm)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(6)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 7)
            }
        }
        .background(Color.black.opacity(0.25))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - VOICE BUTTON (shared, prominent)
    // ═══════════════════════════════════════════════════════════════════════

    @ViewBuilder
    var voiceButton: some View {
        Button {
            if speechAuthorized && microphoneAuthorized {
                voiceManager.startListening()
            } else {
                voiceManager.errorMessage = "Enable Speech & Mic in Settings"
            }
        } label: {
            HStack(spacing: 12) {
                // Mic circle
                ZStack {
                    Circle()
                        .fill(voiceManager.isListening
                              ? Color.red.opacity(0.35)
                              : Color(red: 0.52, green: 0.73, blue: 0.88).opacity(0.3))
                        .frame(width: 38, height: 38)

                    if voiceManager.isListening {
                        Circle()
                            .stroke(Color.red.opacity(0.6), lineWidth: 2)
                            .frame(width: 38, height: 38)
                            .scaleEffect(voiceManager.isListening ? 1.4 : 1.0)
                            .opacity(voiceManager.isListening ? 0 : 1)
                            .animation(
                                .easeOut(duration: 1.0).repeatForever(autoreverses: false),
                                value: voiceManager.isListening
                            )
                    }

                    Image(systemName: voiceManager.isListening ? "mic.fill" : "mic")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(voiceManager.isListening
                                         ? .red
                                         : Color(red: 0.52, green: 0.73, blue: 0.88))
                        .scaleEffect(voiceManager.isListening ? 1.15 : 1.0)
                        .animation(
                            voiceManager.isListening
                            ? .easeInOut(duration: 0.65).repeatForever(autoreverses: true)
                            : .default,
                            value: voiceManager.isListening
                        )
                }

                // Labels
                VStack(alignment: .leading, spacing: 2) {
                    Text(voiceManager.isListening ? "Listening…" : "Voice Control")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    if voiceManager.isListening && !voiceManager.recognizedText.isEmpty
                       && voiceManager.recognizedText != "Listening..."
                       && voiceManager.recognizedText != "Processing..." {
                        Text(voiceManager.recognizedText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    } else if !voiceManager.errorMessage.isEmpty {
                        Text(voiceManager.errorMessage)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.red.opacity(0.9))
                            .lineLimit(1)
                    } else {
                        Text(voiceManager.isListening
                             ? "Tap to stop"
                             : "Tap to speak — \"e4\", \"knight c3\", \"castle\"")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                Spacer()

                // Right-side icon
                Image(systemName: voiceManager.isListening ? "stop.circle.fill" : "chevron.right")
                    .font(.system(size: voiceManager.isListening ? 22 : 14, weight: .semibold))
                    .foregroundColor(voiceManager.isListening
                                     ? .red.opacity(0.8)
                                     : .white.opacity(0.25))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        voiceManager.isListening
                        ? LinearGradient(colors: [Color.red.opacity(0.22), Color.red.opacity(0.12)],
                                         startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(
                            colors: [Color(red: 0.18, green: 0.24, blue: 0.38),
                                     Color(red: 0.14, green: 0.20, blue: 0.32)],
                            startPoint: .leading, endPoint: .trailing)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        voiceManager.isListening
                        ? Color.red.opacity(0.5)
                        : Color(red: 0.52, green: 0.73, blue: 0.88).opacity(0.3),
                        lineWidth: 1.5
                    )
            )
        }
        .disabled(!speechAuthorized || !microphoneAuthorized)
        .accessibilityLabel(voiceManager.isListening ? "Stop listening" : "Start voice control")
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - TOP BARS (compact, no voice button here)
    // ═══════════════════════════════════════════════════════════════════════

    @ViewBuilder
    var landscapeTopBar: some View {
        HStack(spacing: 8) {
            // Back
            Button { dismiss() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                    Text("Menu").font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(Color.white.opacity(0.1))
                .cornerRadius(9)
            }

            Spacer()

            // Turn indicator
            turnIndicator

            // Check
            if game.isInCheck { checkBadge }

            // New game
            if showResetButton { newGameButton }
        }
    }

    @ViewBuilder
    var portraitTopBar: some View {
        HStack(spacing: 8) {
            Button { dismiss() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                    Text("Menu").font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(Color.white.opacity(0.1))
                .cornerRadius(9)
            }

            Spacer()

            turnIndicator

            if game.isInCheck { checkBadge }

            if showResetButton { newGameButton }
        }
    }

    // Shared small pieces:

    @ViewBuilder
    var turnIndicator: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(game.currentPlayer == .white ? Color.white : Color(white: 0.15))
                .frame(width: 9, height: 9)
                .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
            Text(game.currentPlayer == .white ? "Your turn" : "AI…")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 9).padding(.vertical, 6)
        .background(Color.white.opacity(0.07))
        .cornerRadius(8)
    }

    @ViewBuilder
    var checkBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "exclamationmark.circle.fill").font(.system(size: 10))
            Text("CHECK").font(.system(size: 10, weight: .heavy))
        }
        .foregroundColor(.red)
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(Color.red.opacity(0.16))
        .cornerRadius(7)
    }

    @ViewBuilder
    var newGameButton: some View {
        Button {
            showResetButton = false
            showDifficultySelection = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .semibold))
                Text("New").font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 9).padding(.vertical, 6)
            .background(Color(red: 0.30, green: 0.42, blue: 0.58).opacity(0.55))
            .cornerRadius(8)
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - CHESS BOARD
    // ═══════════════════════════════════════════════════════════════════════

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
        .frame(width: sq * 8, height: sq * 8)  // always exactly 8 × sq
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.black.opacity(0.5), lineWidth: 1.5)
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

            // Last move highlight
            if isLastMoveSquare(row: row, col: col) && !isSelected {
                Rectangle().fill(Color.yellow.opacity(0.40))
            }

            // Piece image
            if let piece = game.board[row][col] {
                Image("\(piece.type.rawValue)_\(piece.color.rawValue)")
                    .resizable()
                    .scaledToFit()
                    .frame(width: sq * 0.82, height: sq * 0.82)
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
                    .frame(width: isCapture ? sq * 0.90 : sq * 0.30,
                           height: isCapture ? sq * 0.90 : sq * 0.30)
                    .overlay(
                        isCapture
                        ? Circle()
                            .stroke(Color(red: 0.1, green: 0.55, blue: 1.0).opacity(0.7),
                                    lineWidth: sq * 0.08)
                        : nil
                    )
                    .allowsHitTesting(false)

                Color.clear
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
                    .font(.system(size: max(7, sq * 0.17), weight: .semibold))
                    .foregroundColor((isLight ? darkColor : lightColor).opacity(0.7))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(1.5)
                    .allowsHitTesting(false)
            }
            if row == 0 {
                Text(colFile(col))
                    .font(.system(size: max(7, sq * 0.17), weight: .semibold))
                    .foregroundColor((isLight ? darkColor : lightColor).opacity(0.7))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(1.5)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: sq, height: sq)
        .accessibilityLabel("Square \(colFile(col))\(row + 1), \(pieceName(game.board[row][col]))")
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - SIDEBAR (landscape only)
    // ═══════════════════════════════════════════════════════════════════════

    @ViewBuilder
    func sidebarView(width: CGFloat) -> some View {
        VStack(spacing: 6) {
            moveHistoryView
                .frame(maxHeight: .infinity)
            capturedView
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    var moveHistoryView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Moves")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(movePairs.count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(5)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 5)

            Divider().background(Color.white.opacity(0.12))

            HStack(spacing: 0) {
                Text("#")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.35))
                    .frame(width: 22)
                Text("W")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.35))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("B")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.35))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.03))

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
        .background(Color.black.opacity(0.25))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    @ViewBuilder
    func moveRow(pair: (moveNumber: Int, white: String?, black: String?)) -> some View {
        HStack(spacing: 0) {
            Text("\(pair.moveNumber)")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.35))
                .frame(width: 22)

            HStack(spacing: 2) {
                if let wm = pair.white, let ico = pieceIcon(from: wm, color: .white) {
                    Image(ico).resizable().frame(width: 13, height: 13)
                }
                Text(pair.white ?? "")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 2) {
                if let bm = pair.black, let ico = pieceIcon(from: bm, color: .black) {
                    Image(ico).resizable().frame(width: 13, height: 13)
                }
                Text(pair.black ?? "")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(pair.moveNumber % 2 == 0 ? Color.white.opacity(0.03) : Color.clear)
    }

    @ViewBuilder
    var capturedView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Captured")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.55))
                Spacer()
                let bal = materialBalance
                if bal != 0 {
                    Text(bal > 0 ? "+\(bal)" : "\(bal)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(bal > 0 ? .green : .red)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Capsule()
                            .fill(bal > 0 ? Color.green.opacity(0.16) : Color.red.opacity(0.16)))
                }
            }
            .padding(.horizontal, 10).padding(.top, 7).padding(.bottom, 4)

            Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 10)

            capturedRow(label: "You", pieces: game.capturedByWhite,
                        suffix: "black", dotColor: .white)
            capturedRow(label: "AI",  pieces: game.capturedByBlack,
                        suffix: "white", dotColor: Color(white: 0.3))
        }
        .padding(.bottom, 6)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    @ViewBuilder
    func capturedRow(label: String, pieces: [PieceType], suffix: String, dotColor: Color) -> some View {
        HStack(spacing: 5) {
            HStack(spacing: 3) {
                Circle().fill(dotColor).frame(width: 6, height: 6)
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: dotColor == .white ? 0 : 1))
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 30, alignment: .leading)

            if pieces.isEmpty {
                Text("—").font(.system(size: 10)).foregroundColor(.white.opacity(0.2))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 1) {
                        ForEach(Array(pieces.enumerated()), id: \.offset) { _, type in
                            Image("\(type.rawValue)_\(suffix)")
                                .resizable().frame(width: 17, height: 17)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 3)
    }
}
