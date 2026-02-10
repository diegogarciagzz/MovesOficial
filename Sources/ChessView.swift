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

    public init() {
        _game = StateObject(wrappedValue: ChessGame(difficulty: .easy))
    }

    var gameOverMessage: String {
        if game.isCheckmate {
            if game.currentPlayer == .white {
                return "Checkmate. You lose 😭"
            } else {
                return "Checkmate! You win 🎉"
            }
        } else if game.isStalemate {
            return "Stalemate!"
        } else {
            return ""
        }
    }
    
    // Calculate material balance
    var materialBalance: Int {
        var whitePoints = 0
        var blackPoints = 0
        
        for piece in game.capturedByWhite {
            whitePoints += game.pieceValue(piece)
        }
        for piece in game.capturedByBlack {
            blackPoints += game.pieceValue(piece)
        }
        
        return whitePoints - blackPoints
    }
    
    // Group moves in pairs (White, Black)
    var movePairs: [(moveNumber: Int, white: String?, black: String?)] {
        var pairs: [(Int, String?, String?)] = []
        for i in stride(from: 0, to: game.moveHistory.count, by: 2) {
            let moveNum = (i / 2) + 1
            let whiteMove = game.moveHistory[i]
            let blackMove = i + 1 < game.moveHistory.count ? game.moveHistory[i + 1] : nil
            pairs.append((moveNum, whiteMove, blackMove))
        }
        return pairs
    }
    
    // Extract piece icon from notation
    func pieceIcon(from notation: String, color: PieceColor) -> String? {
        guard let firstChar = notation.first else { return nil }
        let pieceType: String
        
        switch firstChar {
        case "N": pieceType = "knight"
        case "B": pieceType = "bishop"
        case "R": pieceType = "rook"
        case "Q": pieceType = "queen"
        case "K": pieceType = "king"
        default: pieceType = "pawn"
        }
        
        return "\(pieceType)_\(color.rawValue)"
    }
    
    func colFile(_ col: Int) -> String {
        let files = ["a", "b", "c", "d", "e", "f", "g", "h"]
        return files[col]
    }

    func pieceName(_ piece: ChessPiece?) -> String {
        guard let p = piece else { return "empty" }
        return "\(p.color == .white ? "white" : "black") \(p.type.rawValue)"
    }
    
    // Helper to check if square is part of last move
    func isLastMoveSquare(row: Int, col: Int) -> Bool {
        if let from = game.lastMovePositions.from, from == (row, col) { return true }
        if let to = game.lastMovePositions.to, to == (row, col) { return true }
        return false
    }

    public var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            let sidebarWidth = min(screenWidth * 0.28, 400)
            let boardSize = min(screenWidth - sidebarWidth - 60, screenHeight - 80)
            let squareSize = boardSize / 8

            ZStack {
                // Background gradient FULLSCREEN
                LinearGradient(
                    colors: [Color(red: 0.15, green: 0.15, blue: 0.2), Color(red: 0.25, green: 0.25, blue: 0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .edgesIgnoringSafeArea(.all)
                
                HStack(spacing: 20) {
                    // LEFT: Chess Board Section
                    VStack(spacing: 16) {
                        // Botón BACK arriba a la izquierda
                        HStack {
                            Button(action: {
                                dismiss()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.left")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Menu")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(10)
                            }
                            Spacer()
                        }
                        .padding(.bottom, 8)
                        
                        // 🎤 BOTÓN DE VOZ GRANDE
                        Button(action: {
                            voiceManager.startListening()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: voiceManager.isListening ? "mic.fill" : "mic")
                                    .font(.system(size: 24, weight: .bold))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(voiceManager.isListening ? "Listening..." : "Voice Control")
                                        .font(.system(size: 18, weight: .semibold))
                                    
                                    if !voiceManager.recognizedText.isEmpty {
                                        Text(voiceManager.recognizedText)
                                            .font(.system(size: 12))
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .frame(maxWidth: boardSize)
                            .background(
                                voiceManager.isListening ?
                                LinearGradient(colors: [Color.red, Color.red.opacity(0.8)], startPoint: .leading, endPoint: .trailing) :
                                LinearGradient(colors: [Color.blue, Color.blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(12)
                            .shadow(color: voiceManager.isListening ? .red.opacity(0.5) : .blue.opacity(0.4), radius: 10)
                        }
                        .accessibilityLabel(voiceManager.isListening ? "Stop listening" : "Start voice control")
                        .padding(.bottom, 12)
                        
                        // Error message si existe
                        if !voiceManager.errorMessage.isEmpty {
                            Text(voiceManager.errorMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.red.opacity(0.2))
                                .cornerRadius(8)
                                .frame(width: boardSize)
                        }
                        
                        // Chess Board
                        VStack(spacing: 0) {
                            ForEach((0..<8).reversed(), id: \.self) { row in
                                HStack(spacing: 0) {
                                    ForEach(0..<8, id: \.self) { column in
                                        ZStack {
                                            Rectangle()
                                                .fill((row + column) % 2 == 0 ? Color.white : Color(red: 0.7, green: 0.7, blue: 0.75))
                                                .frame(width: squareSize, height: squareSize)
                                            
                                            // Highlight last move
                                            if isLastMoveSquare(row: row, col: column) {
                                                Rectangle()
                                                    .fill(Color.yellow.opacity(0.5))
                                                    .frame(width: squareSize, height: squareSize)
                                            }
                                            
                                            // Piece Image
                                            if let piece = game.board[row][column] {
                                                Image("\(piece.type.rawValue)_\(piece.color.rawValue)")
                                                    .resizable()
                                                    .frame(width: squareSize * 0.8, height: squareSize * 0.8)
                                                    .onTapGesture {
                                                        if piece.color == game.currentPlayer {
                                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                                game.selectPiece(at: (row, column))
                                                            }
                                                        }
                                                    }
                                            }

                                            // Highlight possible moves
                                            if game.possibleMoves.contains(where: { $0 == (row, column) }) {
                                                Circle()
                                                    .fill(Color.blue.opacity(0.5))
                                                    .frame(width: squareSize * 0.6, height: squareSize * 0.6)
                                                    .onTapGesture {
                                                        if let _ = game.selectedPiece {
                                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                                if !game.movePiece(to: (row, column)) {
                                                                    showGameOverAlert = true
                                                                } else {
                                                                    if game.promotionPending != nil {
                                                                        showPromotionSheet = true
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                            }
                                        }
                                        .accessibilityLabel("Square \(colFile(column))\(row + 1), \(pieceName(game.board[row][column]))")
                                    }
                                }
                            }
                        }
                        .frame(width: boardSize, height: boardSize)
                        .shadow(color: .black.opacity(0.3), radius: 10)
                        
                        // Captured Pieces & Material Balance
                        VStack(spacing: 14) {
                            // White's captured pieces
                            HStack(spacing: 8) {
                                Text("You:")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.9))
                                    .frame(width: 65, alignment: .leading)
                                
                                if game.capturedByWhite.isEmpty {
                                    Text("—")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white.opacity(0.4))
                                } else {
                                    ForEach(game.capturedByWhite, id: \.self) { type in
                                        Image("\(type.rawValue)_black")
                                            .resizable()
                                            .frame(width: 28, height: 28)
                                    }
                                }
                                
                                Spacer()
                                
                                if materialBalance > 0 {
                                    Text("+\(materialBalance)")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.green.opacity(0.2))
                                        .cornerRadius(8)
                                }
                            }
                            
                            // Black's captured pieces
                            HStack(spacing: 8) {
                                Text("AI:")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.9))
                                    .frame(width: 65, alignment: .leading)
                                
                                if game.capturedByBlack.isEmpty {
                                    Text("—")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white.opacity(0.4))
                                } else {
                                    ForEach(game.capturedByBlack, id: \.self) { type in
                                        Image("\(type.rawValue)_white")
                                            .resizable()
                                            .frame(width: 28, height: 28)
                                    }
                                }
                                
                                Spacer()
                                
                                if materialBalance < 0 {
                                    Text("+\(abs(materialBalance))")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.red.opacity(0.2))
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .frame(width: boardSize)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(14)
                        
                        // Reset button
                        if showResetButton {
                            Button(action: {
                                showResetButton = false
                                showDifficultySelection = true
                            }) {
                                Text("Reset Game")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 56)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.blue, Color.blue.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(14)
                                    .shadow(color: .blue.opacity(0.4), radius: 10)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .frame(width: boardSize)
                    
                    // RIGHT: Move History Sidebar
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        Text("Move History")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                            .padding(.bottom, 16)
                        
                        Divider()
                            .background(Color.white.opacity(0.3))
                        
                        // Table Header
                        HStack(spacing: 16) {
                            Text("#")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 45)
                            
                            Text("White")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text("Black")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.05))
                        
                        // Scrollable moves
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(movePairs, id: \.moveNumber) { pair in
                                    HStack(spacing: 16) {
                                        Text("\(pair.moveNumber)")
                                            .font(.system(size: 17))
                                            .foregroundColor(.white.opacity(0.7))
                                            .frame(width: 45)
                                        
                                        // White move
                                        HStack(spacing: 8) {
                                            if let whiteMove = pair.white, let icon = pieceIcon(from: whiteMove, color: .white) {
                                                Image(icon)
                                                    .resizable()
                                                    .frame(width: 24, height: 24)
                                            }
                                            Text(pair.white ?? "")
                                                .font(.system(size: 17))
                                                .foregroundColor(.white)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        // Black move
                                        HStack(spacing: 8) {
                                            if let blackMove = pair.black, let icon = pieceIcon(from: blackMove, color: .black) {
                                                Image(icon)
                                                    .resizable()
                                                    .frame(width: 24, height: 24)
                                            }
                                            Text(pair.black ?? "")
                                                .font(.system(size: 17))
                                                .foregroundColor(.white)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(pair.moveNumber % 2 == 0 ? Color.white.opacity(0.05) : Color.clear)
                                }
                            }
                        }
                    }
                    .frame(width: sidebarWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(18)
                    .shadow(color: .black.opacity(0.4), radius: 12)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .onAppear {
            voiceManager.game = game
            voiceManager.requestPermission { granted in
                if granted {
                    print("✅ Voice control ready")
                }
            }
        }
        .onChange(of: game.lastMoveDescription) { description in
            if !description.isEmpty {
                speaker.speak(description)
            }
        }
        .onChange(of: game.isCheckmate) { isCheckmate in
            if isCheckmate {
                showGameOverAlert = true
            }
        }
        .onChange(of: game.isStalemate) { isStalemate in
            if isStalemate {
                showGameOverAlert = true
            }
        }
        .onChange(of: game.promotionPending) { _ in
            if let promotion = game.promotionPending, promotion.color == .white {
                showPromotionSheet = true
            } else {
                showPromotionSheet = false
            }
        }
        .alert(isPresented: $showGameOverAlert) {
            Alert(
                title: Text("Game Over"),
                message: Text(gameOverMessage),
                primaryButton: .default(Text("Reset")) {
                    showDifficultySelection = true
                },
                secondaryButton: .cancel {
                    showResetButton = true
                }
            )
        }
        .onChange(of: showGameOverAlert) { isShowing in
            if isShowing {
                let message: String
                if game.isCheckmate {
                    if game.currentPlayer == .white {
                        message = "Checkmate. Black wins. Better luck next time"
                    } else {
                        message = "Checkmate. White wins. Congratulations"
                    }
                } else {
                    message = "Stalemate. It's a draw"
                }
                speaker.speak(message)
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
}
