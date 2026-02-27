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

    // ── New feature state ──────────────────────────────────────────────────
    @State private var boardTheme: BoardTheme = BoardTheme.saved
    @State private var showThemePicker = false
    @State private var hintMove: (from: (Int, Int), to: (Int, Int))? = nil
    @State private var hintUsesLeft = 3

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
    func isHintSquare(row: Int, col: Int) -> Bool {
        guard let h = hintMove else { return false }
        return (h.from == (row, col)) || (h.to == (row, col))
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
                .onAppear { enforceLandscape() }

                if isLandscape {
                    landscapeLayout(w: w, h: h)
                } else {
                    portraitLayout(w: w, h: h)
                }

                // Theme picker overlay
                if showThemePicker {
                    themePickerOverlay
                }
            }
        }
        .onAppear {
            voiceManager.game = game
            let p = PermissionsManager.shared.checkPermissions()
            speechAuthorized     = p.speech
            microphoneAuthorized = p.mic
        }
        .onDisappear {
            voiceManager.stopListening()
        }
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
        .onChange(of: game.moveHistory.count) { _ in
            // Clear hint when a move is made
            hintMove = nil
        }
        // (game-over alert replaced by custom overlay below)
        .sheet(isPresented: $showPromotionSheet) { PromotionView(game: game) }
        .fullScreenCover(isPresented: $showDifficultySelection, onDismiss: {
            game.resetGame(difficulty: selectedDifficulty)
            hintUsesLeft = 3
            hintMove = nil
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
        .overlay {
            if showGameOverAlert {
                GameOverView(
                    isCheckmate: game.isCheckmate,
                    isStalemate: game.isStalemate,
                    playerWins: game.isCheckmate && game.currentPlayer == .black,
                    onPlayAgain: {
                        showGameOverAlert = false
                        showDifficultySelection = true
                    },
                    onMenu: {
                        showGameOverAlert = false
                        dismiss()
                    }
                )
                .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - LANDSCAPE LAYOUT
    // ═══════════════════════════════════════════════════════════════════════

    @ViewBuilder
    func landscapeLayout(w: CGFloat, h: CGFloat) -> some View {
        let pad: CGFloat        = 10
        let gap: CGFloat        = 10
        let topH: CGFloat       = 56
        let voicePanelW: CGFloat = 148
        let sideW: CGFloat = min(200, w * 0.24)

        // Board: square, driven by available height with voice panel on left
        let availH    = h - topH - pad * 2
        let availW    = w - pad * 2 - gap * 2 - sideW - voicePanelW
        let boardSize = max(160, min(availH, availW))
        let sq = boardSize / 8

        VStack(spacing: 0) {
            // ── Top strip: back, status, actions ───────────────
            landscapeTopBar
                .frame(height: topH)
                .padding(.horizontal, pad)

            // ── Voice panel + Board + Sidebar ───────────────────
            HStack(alignment: .top, spacing: gap) {
                voiceSidePanel(boardSize: boardSize)

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

    // ── Voice side panel (landscape only) ───────────────────────────────────

    @ViewBuilder
    func voiceSidePanel(boardSize: CGFloat) -> some View {
        let accent = Color(red: 0.52, green: 0.73, blue: 0.88)

        VStack(spacing: 0) {

            // Header label
            Text("VOICE")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.3))
                .kerning(2.5)
                .padding(.top, 14)
                .padding(.bottom, 12)

            // ── Mic button ────────────────────────────────
            Button {
                if speechAuthorized && microphoneAuthorized {
                    voiceManager.startListening()
                } else {
                    voiceManager.errorMessage = "Enable Speech & Mic in Settings"
                }
            } label: {
                ZStack {
                    if voiceManager.isListening {
                        Circle()
                            .stroke(Color.red.opacity(0.35), lineWidth: 2)
                            .frame(width: 66, height: 66)
                            .scaleEffect(voiceManager.isListening ? 1.35 : 1.0)
                            .opacity(voiceManager.isListening ? 0 : 1)
                            .animation(
                                .easeOut(duration: 1.1).repeatForever(autoreverses: false),
                                value: voiceManager.isListening
                            )
                    }
                    Circle()
                        .fill(voiceManager.isListening
                              ? Color.red.opacity(0.22)
                              : accent.opacity(0.14))
                        .frame(width: 52, height: 52)

                    Image(systemName: voiceManager.isListening ? "mic.fill" : "mic")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(voiceManager.isListening ? .red : accent)
                        .scaleEffect(voiceManager.isListening ? 1.12 : 1.0)
                        .animation(
                            voiceManager.isListening
                                ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                                : .default,
                            value: voiceManager.isListening
                        )
                }
            }
            .disabled(!speechAuthorized || !microphoneAuthorized)

            // Status text
            Text(voiceManager.isListening ? "Listening…" : "Tap to speak")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(voiceManager.isListening ? .red.opacity(0.8) : .white.opacity(0.28))
                .padding(.top, 8)
                .padding(.bottom, 12)

            Divider().background(Color.white.opacity(0.08))

            // ── Live transcript ───────────────────────────
            VStack(alignment: .leading, spacing: 5) {
                Text("TRANSCRIPT")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.2))
                    .kerning(1.5)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        let t = voiceManager.recognizedText
                        let isPlaceholder = t.isEmpty || t == "Listening..."

                        if isPlaceholder {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Try saying:")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.18))
                                ForEach(["\"e4\"", "\"knight c3\"",
                                         "\"castle\"", "\"e2 to e4\""], id: \.self) { ex in
                                    Text(ex)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.15))
                                }
                            }
                            .padding(.horizontal, 12)
                        } else {
                            Text(t)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(voiceManager.isListening ? accent : .white.opacity(0.8))
                                .padding(.horizontal, 12)
                                .animation(.easeInOut(duration: 0.1), value: t)
                        }

                        if !voiceManager.errorMessage.isEmpty {
                            Text(voiceManager.errorMessage)
                                .font(.system(size: 11))
                                .foregroundColor(.red.opacity(0.85))
                                .padding(.horizontal, 12)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 8)
                }
            }
            .frame(maxHeight: .infinity)

            Divider().background(Color.white.opacity(0.08))

            // ── Bottom action ─────────────────────────────
            if voiceManager.isListening {
                Button { voiceManager.startListening() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "stop.circle.fill").font(.system(size: 13))
                        Text("Stop").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.red.opacity(0.85))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.red.opacity(0.12))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.red.opacity(0.25), lineWidth: 1))
                }
                .padding(.vertical, 10)
            } else {
                Text("Auto-stops\nafter 5s")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.14))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 10)
            }
        }
        .frame(width: 148, height: boardSize)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.28))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    voiceManager.isListening
                        ? Color.red.opacity(0.45)
                        : Color.white.opacity(0.08),
                    lineWidth: 1.5
                )
        )
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - PORTRAIT LAYOUT
    // ═══════════════════════════════════════════════════════════════════════

    @ViewBuilder
    func portraitLayout(w: CGFloat, h: CGFloat) -> some View {
        let pad: CGFloat   = 10
        let topH: CGFloat  = 56
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
    // MARK: - TOP BARS (compact, with hint/theme)
    // ═══════════════════════════════════════════════════════════════════════

    @ViewBuilder
    var landscapeTopBar: some View {
        HStack(spacing: 8) {
            // Back
            Button { dismiss() } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
                    Text("Menu").font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1))
            }

            Spacer()

            // Turn indicator
            turnIndicator

            // Check
            if game.isInCheck { checkBadge }

            // ── Action buttons ──
            hintButton
            themeButton

            // New game
            if showResetButton { newGameButton }
        }
    }

    @ViewBuilder
    var portraitTopBar: some View {
        HStack(spacing: 8) {
            Button { dismiss() } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
                    Text("Menu").font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1))
            }

            Spacer()

            turnIndicator

            if game.isInCheck { checkBadge }

            hintButton
            themeButton

            if showResetButton { newGameButton }
        }
    }

    // Shared small pieces:

    @ViewBuilder
    var turnIndicator: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(game.currentPlayer == .white ? Color.white : Color(white: 0.15))
                .frame(width: 11, height: 11)
                .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1.5))
            Text(game.currentPlayer == .white ? "Your turn" : "AI…")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(.horizontal, 13).padding(.vertical, 9)
        .background(Color.white.opacity(0.09))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(Color.white.opacity(0.15), lineWidth: 1))
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
            HStack(spacing: 6) {
                Image(systemName: "arrow.clockwise").font(.system(size: 14, weight: .semibold))
                Text("New").font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(Color(red: 0.30, green: 0.42, blue: 0.58).opacity(0.55))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(Color(red: 0.52, green: 0.73, blue: 0.88).opacity(0.3), lineWidth: 1))
        }
    }

    // ── Hint ──

    @ViewBuilder
    var hintButton: some View {
        Button {
            if hintUsesLeft > 0, let hint = game.getHint() {
                withAnimation(.easeInOut(duration: 0.3)) {
                    hintMove = hint
                    hintUsesLeft -= 1
                }
                // Auto-clear after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation { hintMove = nil }
                }
            }
        } label: {
            HStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(hintUsesLeft > 0 ? .yellow : .white.opacity(0.3))

                    if hintUsesLeft > 0 {
                        Text("\(hintUsesLeft)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 14, height: 14)
                            .background(Circle().fill(Color.orange))
                            .offset(x: 9, y: -7)
                    }
                }
                .frame(width: 22, height: 22)

                Text("Hint")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(hintUsesLeft > 0 ? .yellow : .white.opacity(0.3))
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(Color.yellow.opacity(hintUsesLeft > 0 ? 0.15 : 0.05))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(Color.yellow.opacity(hintUsesLeft > 0 ? 0.3 : 0.08), lineWidth: 1))
        }
        .disabled(hintUsesLeft <= 0 || game.currentPlayer != .white)
        .opacity(game.currentPlayer == .white ? 1 : 0.4)
        .accessibilityLabel("Get hint, \(hintUsesLeft) remaining")
    }

    // ── Theme button ──

    @ViewBuilder
    var themeButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                showThemePicker.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(boardTheme.accent)
                Text("Theme")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(boardTheme.accent)
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(boardTheme.accent.opacity(0.15))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(boardTheme.accent.opacity(0.3), lineWidth: 1))
        }
        .accessibilityLabel("Change board theme")
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - THEME PICKER OVERLAY
    // ═══════════════════════════════════════════════════════════════════════

    @ViewBuilder
    var themePickerOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { withAnimation { showThemePicker = false } }

            VStack(spacing: 12) {
                Text("Board Theme")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 20)

                ForEach(BoardTheme.allCases) { theme in
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            boardTheme = theme
                            theme.save()
                            showThemePicker = false
                        }
                    } label: {
                        HStack(spacing: 12) {
                            // Mini board preview
                            HStack(spacing: 0) {
                                VStack(spacing: 0) {
                                    Rectangle().fill(theme.lightSquare).frame(width: 16, height: 16)
                                    Rectangle().fill(theme.darkSquare).frame(width: 16, height: 16)
                                }
                                VStack(spacing: 0) {
                                    Rectangle().fill(theme.darkSquare).frame(width: 16, height: 16)
                                    Rectangle().fill(theme.lightSquare).frame(width: 16, height: 16)
                                }
                            }
                            .cornerRadius(4)

                            Text(theme.displayName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)

                            Spacer()

                            Image(systemName: theme.icon)
                                .font(.system(size: 14))
                                .foregroundColor(theme.accent)

                            if boardTheme == theme {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(boardTheme == theme
                                      ? theme.accent.opacity(0.15)
                                      : Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(boardTheme == theme ? theme.accent.opacity(0.5) : Color.clear,
                                        lineWidth: 1.5)
                        )
                    }
                }

                Spacer().frame(height: 8)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.12, green: 0.14, blue: 0.22))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .padding(.bottom, 12)
            .shadow(color: .black.opacity(0.5), radius: 30)
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
        let lightColor = boardTheme.lightSquare
        let darkColor  = boardTheme.darkSquare
        let isSelected = game.selectedPiece.map { $0.position == (row, col) } ?? false
        let isHint = isHintSquare(row: row, col: col)

        ZStack {
            // Base square
            Rectangle()
                .fill(isSelected
                      ? (isLight ? boardTheme.selectedLight : boardTheme.selectedDark)
                      : (isLight ? lightColor : darkColor))

            // Hint highlight (pulsing green glow)
            if isHint && !isSelected {
                Rectangle()
                    .fill(Color.green.opacity(0.45))
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: hintMove != nil)
            }

            // Last move highlight
            if isLastMoveSquare(row: row, col: col) && !isSelected && !isHint {
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

            // Hint arrow indicator on destination
            if let h = hintMove, h.to == (row, col) {
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: max(8, sq * 0.25)))
                    .foregroundColor(.green)
                    .shadow(color: .green.opacity(0.8), radius: 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 1)
                    .allowsHitTesting(false)
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

            if movePairs.isEmpty {
                // ── Empty state decoration ──
                emptyMoveHistoryView
            } else {
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
        }
        .background(Color.black.opacity(0.25))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // ── Empty sidebar decoration ──

    @ViewBuilder
    var emptyMoveHistoryView: some View {
        VStack(spacing: 10) {
            Spacer()

            // Decorative chess pieces pattern
            HStack(spacing: 6) {
                ForEach(["king_white", "queen_white", "rook_white"], id: \.self) { piece in
                    Image(piece)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .opacity(0.2)
                }
            }

            Text("No moves yet")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.25))

            // Chess tip
            VStack(spacing: 4) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.yellow.opacity(0.4))
                Text(chessTip)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 8)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(Color.white.opacity(0.03))
            .cornerRadius(8)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var chessTip: String {
        let tips = [
            "Control the center early with pawns and knights.",
            "Castle early to protect your king.",
            "Develop your pieces before attacking.",
            "A knight on the rim is dim.",
            "Try using voice: say \"e4\" or \"knight f3\".",
            "Don't move the same piece twice in the opening.",
            "Rooks are powerful on open files.",
        ]
        // Use move count as seed for consistent display
        return tips[game.moveHistory.count % tips.count]
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
