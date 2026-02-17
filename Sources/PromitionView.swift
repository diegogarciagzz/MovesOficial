//
//  PromitionView.swift
//  Chess
//
//  Created by Diego García
//

import SwiftUI
import Foundation

struct PromotionView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var game: ChessGame

    private let bg = Color(red: 0.10, green: 0.10, blue: 0.14)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Promote Your Pawn")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Text("Choose a piece")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.45))
                }

                HStack(spacing: 18) {
                    promotionButton(type: .queen, icon: "queen_white", label: "Queen")
                    promotionButton(type: .rook, icon: "rook_white", label: "Rook")
                    promotionButton(type: .bishop, icon: "bishop_white", label: "Bishop")
                    promotionButton(type: .knight, icon: "knight_white", label: "Knight")
                }
            }
            .padding(40)
        }
    }

    private func promotionButton(type: PieceType, icon: String, label: String) -> some View {
        Button {
            game.promotePawn(to: type)
            dismiss()
        } label: {
            VStack(spacing: 10) {
                Image(icon)
                    .resizable()
                    .frame(width: 64, height: 64)

                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(20)
            .background(Color.white.opacity(0.06))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}
