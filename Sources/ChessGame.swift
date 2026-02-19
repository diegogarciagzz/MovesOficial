//
//  ChessGame.swift
//  Chess
//
//  Created by Diego García
//

import SwiftUI
import Foundation
import UIKit


public enum PieceType: String {
    case pawn, knight, bishop, rook, queen, king
}

enum PieceColor: String, Equatable {
    case white, black

    var opponent: PieceColor {
        return self == .white ? .black : .white
    }
}

struct ChessPiece {
    let type: PieceType
    let color: PieceColor
    var position: (Int, Int)
    var hasMoved: Bool = false // To track pawn's initial move
}

struct PromotionPending: Equatable {
    let position: (Int, Int)
    let color: PieceColor

    static func == (lhs: PromotionPending, rhs: PromotionPending) -> Bool {
        return lhs.position == rhs.position && lhs.color == rhs.color
    }
}

public class ChessGame: ObservableObject, @unchecked Sendable {
    @Published var board: [[ChessPiece?]] = Array(repeating: Array(repeating: nil, count: 8), count: 8)
    @Published var selectedPiece: ChessPiece?
    @Published var possibleMoves: [(Int, Int)] = []
    @Published var isInCheck: Bool = false
    @Published var isCheckmate: Bool = false
    @Published var isStalemate: Bool = false // Added stalemate tracking
    @Published var promotionPending: PromotionPending?
    @Published var currentPlayer: PieceColor = .white
    @Published var lastMoveDescription: String = ""
    @Published var lastMovePositions: (from: (Int, Int)?, to: (Int, Int)?) = (nil, nil)
    @Published var moveHistory: [String] = []


    

    // Track castling rights
    var whiteKingMoved = false
    var blackKingMoved = false
    var whiteRookMoved = (left: false, right: false)
    var blackRookMoved = (left: false, right: false)

    // En passant tracking
    var enPassantTarget: (position: (Int, Int), color: PieceColor)?

    // Opponent engine
    var opponentEngine: OpponentChessEngine!
    
    // Historical log of game
    var boardHistory: [[[ChessPiece?]]] = []
    @Published var capturedByWhite: [PieceType] = []
    @Published var capturedByBlack: [PieceType] = []

    init(difficulty: DifficultyLevel = .easy) {
        setupBoard()
        self.opponentEngine = OpponentChessEngine(game: self, difficulty: difficulty)
    }

    func setupBoard() {
        // Setting up pawns
        for i in 0..<8 {
            board[1][i] = ChessPiece(type: .pawn, color: .white, position: (1, i))
            board[6][i] = ChessPiece(type: .pawn, color: .black, position: (6, i))
        }

        // Rooks
        board[0][0] = ChessPiece(type: .rook, color: .white, position: (0, 0))
        board[0][7] = ChessPiece(type: .rook, color: .white, position: (0, 7))
        board[7][0] = ChessPiece(type: .rook, color: .black, position: (7, 0))
        board[7][7] = ChessPiece(type: .rook, color: .black, position: (7, 7))

        // Knights
        board[0][1] = ChessPiece(type: .knight, color: .white, position: (0, 1))
        board[0][6] = ChessPiece(type: .knight, color: .white, position: (0, 6))
        board[7][1] = ChessPiece(type: .knight, color: .black, position: (7, 1))
        board[7][6] = ChessPiece(type: .knight, color: .black, position: (7, 6))

        // Bishops
        board[0][2] = ChessPiece(type: .bishop, color: .white, position: (0, 2))
        board[0][5] = ChessPiece(type: .bishop, color: .white, position: (0, 5))
        board[7][2] = ChessPiece(type: .bishop, color: .black, position: (7, 2))
        board[7][5] = ChessPiece(type: .bishop, color: .black, position: (7, 5))

        // Queens
        board[0][3] = ChessPiece(type: .queen, color: .white, position: (0, 3))
        board[7][3] = ChessPiece(type: .queen, color: .black, position: (7, 3))

        // Kings
        board[0][4] = ChessPiece(type: .king, color: .white, position: (0, 4))
        board[7][4] = ChessPiece(type: .king, color: .black, position: (7, 4))
    }
    
    func pieceValue(_ type: PieceType) -> Int {
        switch type {
        case .pawn:
            return 1
        case .knight, .bishop:
            return 3
        case .rook:
            return 5
        case .queen:
            return 9
        case .king:
            return 1000 // High value to represent the king's importance
        }
    }

    func selectPiece(at position: (Int, Int)) {
        if let piece = board[position.0][position.1], piece.color == currentPlayer {
            selectedPiece = piece
            possibleMoves = calculateLegalMoves(for: piece)
        }
    }

    func calculateLegalMoves(for piece: ChessPiece) -> [(Int, Int)] {
        let moves = calculateMoves(for: piece)
        // Filter out moves that would leave the king in check
        return moves.filter { move in
            willResolveCheck(for: piece, to: move)
        }
    }

    func calculateMoves(for piece: ChessPiece) -> [(Int, Int)] {
        var moves: [(Int, Int)] = []
        let position = piece.position

        switch piece.type {
        case .pawn:
            moves += calculatePawnMoves(for: piece)

        case .rook:
            moves += directionalMoves(for: piece, directions: [(1, 0), (-1, 0), (0, 1), (0, -1)])

        case .knight:
            let knightMoves = [(2, 1), (2, -1), (-2, 1), (-2, -1),
                               (1, 2), (1, -2), (-1, 2), (-1, -2)]
            for move in knightMoves {
                let newRow = position.0 + move.0
                let newCol = position.1 + move.1
                if isValidPosition(newRow, newCol), board[newRow][newCol]?.color != piece.color {
                    moves.append((newRow, newCol))
                }
            }

        case .bishop:
            moves += directionalMoves(for: piece, directions: [(1, 1), (1, -1), (-1, 1), (-1, -1)])

        case .queen:
            moves += directionalMoves(for: piece, directions: [(1, 0), (-1, 0), (0, 1), (0, -1),
                                                               (1, 1), (1, -1), (-1, 1), (-1, -1)])

        case .king:
            let kingMoves = [(1, 0), (-1, 0), (0, 1), (0, -1),
                             (1, 1), (1, -1), (-1, 1), (-1, -1)]
            for move in kingMoves {
                let newRow = position.0 + move.0
                let newCol = position.1 + move.1
                if isValidPosition(newRow, newCol), board[newRow][newCol]?.color != piece.color {
                    if !isSquareUnderAttack((newRow, newCol), byColor: piece.color.opponent) {
                        moves.append((newRow, newCol))
                    }
                }
            }

            // Castling
            moves += calculateCastlingMoves(for: piece)
        }

        return moves
    }

    func calculatePawnMoves(for piece: ChessPiece) -> [(Int, Int)] {
        var moves: [(Int, Int)] = []
        let position = piece.position
        let direction = piece.color == .white ? 1 : -1
        let startRow = piece.color == .white ? 1 : 6
        let nextRow = position.0 + direction

        // Normal forward move
        if isValidPosition(nextRow, position.1), board[nextRow][position.1] == nil {
            moves.append((nextRow, position.1))

            // Double move from starting row
            let twoStepsRow = position.0 + 2 * direction
            if position.0 == startRow, board[twoStepsRow][position.1] == nil, board[nextRow][position.1] == nil {
                moves.append((twoStepsRow, position.1))
            }
        }

        // Capturing diagonally
        for dx in [-1, 1] {
            let newCol = position.1 + dx
            if isValidPosition(nextRow, newCol) {
                // Normal capture
                if let targetPiece = board[nextRow][newCol], targetPiece.color == piece.color.opponent {
                    moves.append((nextRow, newCol))
                }

                // En passant capture
                if let enPassant = enPassantTarget,
                   enPassant.position == (position.0, newCol),
                   enPassant.color == piece.color.opponent {
                    moves.append((nextRow, newCol))
                }
            }
        }

        return moves
    }

    // Helper function to calculate moves in a straight line (used for rooks, bishops, and queens)
    func directionalMoves(for piece: ChessPiece, directions: [(Int, Int)]) -> [(Int, Int)] {
        var moves: [(Int, Int)] = []

        for direction in directions {
            var newRow = piece.position.0 + direction.0
            var newCol = piece.position.1 + direction.1

            while isValidPosition(newRow, newCol) {
                if let targetPiece = board[newRow][newCol] {
                    if targetPiece.color != piece.color {
                        moves.append((newRow, newCol))
                    }
                    break
                }
                moves.append((newRow, newCol))
                newRow += direction.0
                newCol += direction.1
            }
        }

        return moves
    }

    func calculateCastlingMoves(for king: ChessPiece) -> [(Int, Int)] {
        guard king.type == .king else { return [] }
        var castlingMoves: [(Int, Int)] = []

        let row = king.color == .white ? 0 : 7
        let kingMoved = king.color == .white ? whiteKingMoved : blackKingMoved
        let rookMoved = king.color == .white ? whiteRookMoved : blackRookMoved
        let opponentColor = king.color.opponent

        if kingMoved || isSquareUnderAttack((row, 4), byColor: opponentColor) {
            return castlingMoves
        }

        // Kingside castling
        if !rookMoved.right,
           board[row][5] == nil,
           board[row][6] == nil,
           !isSquareUnderAttack((row, 5), byColor: opponentColor),
           !isSquareUnderAttack((row, 6), byColor: opponentColor),
           board[row][7]?.type == .rook,
           board[row][7]?.color == king.color {
            castlingMoves.append((row, 6))
        }

        // Queenside castling
        if !rookMoved.left,
           board[row][1] == nil,
           board[row][2] == nil,
           board[row][3] == nil,
           !isSquareUnderAttack((row, 3), byColor: opponentColor),
           !isSquareUnderAttack((row, 2), byColor: opponentColor),
           board[row][0]?.type == .rook,
           board[row][0]?.color == king.color {
            castlingMoves.append((row, 2))
        }

        return castlingMoves
    }

    func isSquareUnderAttack(_ position: (Int, Int), byColor attackingColor: PieceColor) -> Bool {
        for row in 0..<8 {
            for col in 0..<8 {
                if let piece = board[row][col], piece.color == attackingColor {
                    let attackSquares = calculateAttackSquares(for: piece)
                    if attackSquares.contains(where: { $0 == position }) {
                        return true
                    }
                }
            }
        }
        return false
    }

    func calculateAttackSquares(for piece: ChessPiece) -> [(Int, Int)] {
        var attackSquares: [(Int, Int)] = []
        let position = piece.position

        switch piece.type {
        case .pawn:
            let direction = piece.color == .white ? 1 : -1
            for dx in [-1, 1] {
                let newRow = position.0 + direction
                let newCol = position.1 + dx
                if isValidPosition(newRow, newCol) {
                    attackSquares.append((newRow, newCol))
                }
            }

        case .knight:
            let knightMoves = [(2, 1), (2, -1), (-2, 1), (-2, -1),
                               (1, 2), (1, -2), (-1, 2), (-1, -2)]
            for move in knightMoves {
                let newRow = position.0 + move.0
                let newCol = position.1 + move.1
                if isValidPosition(newRow, newCol) {
                    attackSquares.append((newRow, newCol))
                }
            }

        case .bishop:
            attackSquares += attackDirectionalMoves(for: piece, directions: [(1, 1), (1, -1), (-1, 1), (-1, -1)])

        case .rook:
            attackSquares += attackDirectionalMoves(for: piece, directions: [(1, 0), (-1, 0), (0, 1), (0, -1)])

        case .queen:
            attackSquares += attackDirectionalMoves(for: piece, directions: [(1, 0), (-1, 0), (0, 1), (0, -1),
                                                                             (1, 1), (1, -1), (-1, 1), (-1, -1)])

        case .king:
            let kingMoves = [(1, 0), (-1, 0), (0, 1), (0, -1),
                             (1, 1), (1, -1), (-1, 1), (-1, -1)]
            for move in kingMoves {
                let newRow = position.0 + move.0
                let newCol = position.1 + move.1
                if isValidPosition(newRow, newCol) {
                    attackSquares.append((newRow, newCol))
                }
            }
        }

        return attackSquares
    }

    func attackDirectionalMoves(for piece: ChessPiece, directions: [(Int, Int)]) -> [(Int, Int)] {
        var attackSquares: [(Int, Int)] = []

        for direction in directions {
            var newRow = piece.position.0 + direction.0
            var newCol = piece.position.1 + direction.1

            while isValidPosition(newRow, newCol) {
                attackSquares.append((newRow, newCol))
                if board[newRow][newCol] != nil {
                    break
                }
                newRow += direction.0
                newCol += direction.1
            }
        }

        return attackSquares
    }

    func willResolveCheck(for piece: ChessPiece, to destination: (Int, Int)) -> Bool {
        // Temporarily move piece to check if move resolves check
        let originalPosition = piece.position
        let targetPiece = board[destination.0][destination.1]
        board[originalPosition.0][originalPosition.1] = nil
        board[destination.0][destination.1] = ChessPiece(type: piece.type, color: piece.color, position: destination)

        let kingPosition = piece.type == .king ? destination : findKingPosition(color: piece.color)
        let isStillInCheck = isSquareUnderAttack(kingPosition, byColor: piece.color.opponent)

        // Undo the move
        board[originalPosition.0][originalPosition.1] = ChessPiece(type: piece.type, color: piece.color, position: originalPosition)
        board[destination.0][destination.1] = targetPiece

        return !isStillInCheck
    }

    func findKingPosition(color: PieceColor) -> (Int, Int) {
        for row in 0..<8 {
            for col in 0..<8 {
                if let piece = board[row][col], piece.type == .king, piece.color == color {
                    return (row, col)
                }
            }
        }
        return (-1, -1) // Should never happen if board setup is correct
    }
    
    func movePiece(to position: (Int, Int)) -> Bool {
        guard let selectedPiece = selectedPiece else { return false }

        if possibleMoves.contains(where: { $0 == position }) {
            // Save the current board state before making the move
            saveCurrentBoardState()

            performMove(piece: selectedPiece, to: position)

            // Deselect the piece and clear possible moves
            self.selectedPiece = nil
            possibleMoves = []

            return true
        }

        return false
    }


    @MainActor func promotePawn(to newType: PieceType) {
        guard let promotion = promotionPending else { return }
        let position = promotion.position
        
        // Actualizar pieza en el tablero
        board[position.0][position.1] = ChessPiece(type: newType, color: promotion.color, position: position)
        
        // Añadir notación de promoción al historial
        if !moveHistory.isEmpty {
            let lastIndex = moveHistory.count - 1
            let promotionSymbol = pieceSymbol(newType)
            moveHistory[lastIndex] = moveHistory[lastIndex] + "=\(promotionSymbol)"
        }
        
        // Actualizar descripción de voz
        let coordinate = "\(colFile(position.1))\(position.0 + 1)"
        lastMoveDescription = "Pawn promoted to \(newType.rawValue) at \(coordinate)"
        
        // Limpiar promoción pendiente
        promotionPending = nil

        // AHORA SÍ cambiar turno
        currentPlayer = currentPlayer.opponent

        // Update game state after promotion
        updateGameState()

        // Check if game over after promotion
        if isCheckmate || isStalemate {
            return
        }

        // If opponent's turn (black), perform move after delay
        if currentPlayer == .black {
            let engine = self.opponentEngine
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                _ = engine?.makeMove()
            }
        }
    }

    
    func performMove(piece: ChessPiece, to position: (Int, Int)) {
        let startRow = piece.position.0
        let startCol = piece.position.1
        
        // Clear previous en passant target
        enPassantTarget = nil
        
        // Inside performMove function
        if piece.type == .pawn {
            // If pawn moved two steps, set En passant target
            if abs(position.0 - startRow) == 2 {
                enPassantTarget = (position: position, color: piece.color)
            }
        }
        
        // Handle castling move
        if piece.type == .king, abs(position.1 - startCol) == 2 {
            let rookStartCol = position.1 == 6 ? 7 : 0
            let rookEndCol = position.1 == 6 ? 5 : 3
            if let rook = board[startRow][rookStartCol] {
                board[startRow][rookEndCol] = ChessPiece(type: rook.type, color: rook.color, position: (startRow, rookEndCol))
                board[startRow][rookStartCol] = nil
            }
        }
        
        // Track captured piece
        if let capturedPiece = board[position.0][position.1] {
            if capturedPiece.color == .white {
                capturedByBlack.append(capturedPiece.type)
            } else {
                capturedByWhite.append(capturedPiece.type)
            }
        }
        
        // Update the board
        board[startRow][startCol] = nil
        board[position.0][position.1] = ChessPiece(
            type: piece.type,
            color: piece.color,
            position: position,
            hasMoved: true
        )
        
        // Update castling rights
        if piece.type == .king {
            if piece.color == .white {
                whiteKingMoved = true
            } else {
                blackKingMoved = true
            }
        }
        
        if piece.type == .rook {
            if piece.color == .white {
                if startCol == 0 {
                    whiteRookMoved.left = true
                } else if startCol == 7 {
                    whiteRookMoved.right = true
                }
            } else {
                if startCol == 0 {
                    blackRookMoved.left = true
                } else if startCol == 7 {
                    blackRookMoved.right = true
                }
            }
        }
        
        // Track last move positions for highlighting
        lastMovePositions = (from: (startRow, startCol), to: position)

        // MEJOR NOTACIÓN con tipo de pieza
        let pieceNotation = pieceSymbol(piece.type)
        let coordinate = "\(colFile(position.1))\(position.0 + 1)"
        lastMoveDescription = "\(piece.type.rawValue.capitalized) to \(coordinate)"
        moveHistory.append("\(pieceNotation)\(coordinate)")

        // Play sound
        if board[position.0][position.1] != nil {
            SoundManager.shared.playSound(.capture)
        } else {
            SoundManager.shared.playSound(.move)
        }
        // Haptic feedback
        if board[position.0][position.1] != nil {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        // Check for pawn promotion ANTES de cambiar turno
        if piece.type == .pawn {
            if (piece.color == .white && position.0 == 7) ||
                (piece.color == .black && position.0 == 0) {
                promotionPending = PromotionPending(position: position, color: piece.color)
                
                // Si es AI (black), promocionar automáticamente a queen
                if piece.color == .black {
                    board[position.0][position.1] = ChessPiece(
                        type: .queen,
                        color: piece.color,
                        position: position
                    )
                    promotionPending = nil
                    // Continuar con cambio de turno
                } else {
                    // Es jugador blanco, mostrar UI de promoción
                    // NO cambiar turno aún
                    updateGameState()
                    return
                }
            }
        }

        // Switch to opponent's turn SOLO si no hay promoción pendiente
        currentPlayer = currentPlayer.opponent
        
        // Update game state after switching current player
        updateGameState()
        
        // If game is over after move, handle accordingly
        if isCheckmate || isStalemate {
            return
        }
        
        // If it's the player's turn after move, no further action needed
        if currentPlayer == .white {
            return
        }
        
        // If opponent's turn, DELAY para que speech termine
        let engine = self.opponentEngine
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            _ = engine?.makeMove()
        }
    }


    func opponentMove() -> Bool { // Returns true if a valid move exists
        let opponentPieces = board.flatMap { $0 }.compactMap { $0 }.filter { $0.color == currentPlayer }

        // Clear En passant target
        enPassantTarget = nil

        for piece in opponentPieces.shuffled() { // Shuffle to randomize selection
            let moves = calculateLegalMoves(for: piece)
            if let move = moves.randomElement() {
                let startRow = piece.position.0
                let startCol = piece.position.1

               
                // Track AI captured piece
                if let capturedPiece = board[move.0][move.1] {
                    capturedByBlack.append(capturedPiece.type)
                }

                // Update the board
                board[startRow][startCol] = nil
                board[move.0][move.1] = ChessPiece(
                    type: piece.type,
                    color: piece.color,
                    position: move,
                    hasMoved: true
                )

                // Update castling rights if necessary
                if piece.type == .king {
                    blackKingMoved = true
                }
                if piece.type == .rook {
                    if startCol == 0 {
                        blackRookMoved.left = true
                    } else if startCol == 7 {
                        blackRookMoved.right = true
                    }
                }

                // Check for pawn promotion
                if piece.type == .pawn {
                    // If pawn moved two steps, set En passant target
                    if abs(move.0 - startRow) == 2 {
                        enPassantTarget = (position: move, color: piece.color)
                    }

                    if move.0 == 0 {
                        // Automatically promote to queen
                        board[move.0][move.1] = ChessPiece(
                            type: .queen,
                            color: piece.color,
                            position: move
                        )
                    }
                }

                // Switch back to player's turn
                currentPlayer = currentPlayer.opponent
                
                // Track AI move positions
                lastMovePositions = (from: (startRow, startCol), to: move)

                // MEJOR NOTACIÓN
                let pieceNotation = pieceSymbol(piece.type)
                let coordinate = "\(colFile(move.1))\(move.0 + 1)"
                lastMoveDescription = "\(piece.type.rawValue.capitalized) to \(coordinate)"
                moveHistory.append("\(pieceNotation)\(coordinate)")


                // Update game state after switching current player
                updateGameState()

                // Check if game over after opponent's move
                if isCheckmate || isStalemate {
                    return false
                }

                return true
            }
        }

        // If no moves are found, opponent is in stalemate or checkmate
        print("Opponent has no valid moves")

        // Switch back to player's turn
        currentPlayer = currentPlayer.opponent

        // Update game state after opponent's inability to move
        updateGameState()

        return false
    }


    func updateGameState() {
        let kingPosition = findKingPosition(color: currentPlayer)
        isInCheck = isSquareUnderAttack(kingPosition, byColor: currentPlayer.opponent)
        isCheckmate = isInCheck && !hasLegalMoves(forColor: currentPlayer)
        isStalemate = !isInCheck && !hasLegalMoves(forColor: currentPlayer)
        
        if isCheckmate {
            SoundManager.shared.playSound(.checkmate)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else if isInCheck {
            SoundManager.shared.playSound(.check)
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }

    }

    
    func saveCurrentBoardState() {
        let boardCopy = board.map { row in
            row.compactMap { piece in
                if let piece = piece {
                    return ChessPiece(
                        type: piece.type,
                        color: piece.color,
                        position: piece.position,
                        hasMoved: piece.hasMoved
                    )
                } else {
                    return nil
                }
            }
        }
        boardHistory.append(boardCopy)
    }
    
    func undoMove() {
        // Check if there is a previous board state
        guard !boardHistory.isEmpty else { return }

        // Remove the last board state from history and set it as the current board
        boardHistory.removeLast()
        if let lastBoard = boardHistory.last {
            board = lastBoard
        }

        // Switch the current player back
        currentPlayer = currentPlayer.opponent

        // Recalculate possible moves and game state
        selectedPiece = nil
        possibleMoves = []
        updateGameState()
    }

    func hasLegalMoves(forColor color: PieceColor) -> Bool {
        let pieces = board.flatMap { $0 }.compactMap { $0 }.filter { $0.color == color }

        for piece in pieces {
            let moves = calculateLegalMoves(for: piece)
            if !moves.isEmpty {
                return true
            }
        }
        return false
    }

    func resetGame(difficulty: DifficultyLevel) {
        board = Array(repeating: Array(repeating: nil, count: 8), count: 8)
        selectedPiece = nil
        possibleMoves = []
        isInCheck = false
        isCheckmate = false
        isStalemate = false
        promotionPending = nil
        currentPlayer = .white
        enPassantTarget = nil
        whiteKingMoved = false
        blackKingMoved = false
        whiteRookMoved = (left: false, right: false)
        blackRookMoved = (left: false, right: false)
        setupBoard()
        opponentEngine.difficulty = difficulty
        capturedByWhite = []
        capturedByBlack = []
        moveHistory = []

    }

    // Helper function to check if a position is within the board boundaries
    func isValidPosition(_ row: Int, _ col: Int) -> Bool {
        return (0..<8).contains(row) && (0..<8).contains(col)
    }
    
    func pieceSymbol(_ type: PieceType) -> String {
        switch type {
        case .pawn: return ""
        case .knight: return "N"
        case .bishop: return "B"
        case .rook: return "R"
        case .queen: return "Q"
        case .king: return "K"
        }
    }

    func colFile(_ col: Int) -> String {
        let files = ["a", "b", "c", "d", "e", "f", "g", "h"]
        return files[col]
    }

    // MARK: - Voice Command Move Helpers

    /// "e4", "knight c3", "bishop f4" — find the (unique) piece that can legally
    /// move to the given square and execute it. Returns false if ambiguous or invalid.
    func moveToSquare(toFile: String, toRank: Int, pieceType: PieceType? = nil) -> Bool {
        let files = ["a": 0, "b": 1, "c": 2, "d": 3, "e": 4, "f": 5, "g": 6, "h": 7]
        guard let toCol = files[toFile] else { return false }
        let toRow = toRank - 1
        guard isValidPosition(toRow, toCol) else { return false }

        var candidates: [ChessPiece] = []
        for row in 0..<8 {
            for col in 0..<8 {
                guard let piece = board[row][col],
                      piece.color == currentPlayer,
                      pieceType == nil || piece.type == pieceType
                else { continue }
                let legal = calculateLegalMoves(for: piece)
                if legal.contains(where: { $0 == (toRow, toCol) }) {
                    candidates.append(piece)
                }
            }
        }

        guard candidates.count == 1 else { return false } // 0 = no piece, >1 = ambiguous
        selectPiece(at: candidates[0].position)
        return movePiece(to: (toRow, toCol))
    }

    /// "castle" / "kingside castle" — king moves g-file.
    func castleKingside() -> Bool {
        let row = currentPlayer == .white ? 0 : 7
        guard board[row][4]?.type == .king, board[row][4]?.color == currentPlayer else { return false }
        selectPiece(at: (row, 4))
        guard possibleMoves.contains(where: { $0 == (row, 6) }) else {
            selectedPiece = nil; possibleMoves = []; return false
        }
        return movePiece(to: (row, 6))
    }

    /// "long castle" / "queenside castle" — king moves c-file.
    func castleQueenside() -> Bool {
        let row = currentPlayer == .white ? 0 : 7
        guard board[row][4]?.type == .king, board[row][4]?.color == currentPlayer else { return false }
        selectPiece(at: (row, 4))
        guard possibleMoves.contains(where: { $0 == (row, 2) }) else {
            selectedPiece = nil; possibleMoves = []; return false
        }
        return movePiece(to: (row, 2))
    }

    /// Converts voice input coordinates (file letter + rank number) to board positions and executes the move.
    /// - Returns: `true` if the move was executed successfully.
    func moveFrom(file fromFile: String, rank fromRank: Int, toFile: String, rank toRank: Int) -> Bool {
        let files = ["a": 0, "b": 1, "c": 2, "d": 3, "e": 4, "f": 5, "g": 6, "h": 7]

        guard let fromCol = files[fromFile], let toCol = files[toFile] else { return false }

        let fromRow = fromRank - 1 // voice says rank 1-8, board index 0-7
        let toRow = toRank - 1

        guard isValidPosition(fromRow, fromCol), isValidPosition(toRow, toCol) else { return false }

        guard let piece = board[fromRow][fromCol], piece.color == currentPlayer else { return false }

        // Select the piece and calculate legal moves
        selectPiece(at: (fromRow, fromCol))

        // Check if target is in the list of legal moves
        guard possibleMoves.contains(where: { $0 == (toRow, toCol) }) else {
            selectedPiece = nil
            possibleMoves = []
            return false
        }

        // Execute the move
        return movePiece(to: (toRow, toCol))
    }

}

