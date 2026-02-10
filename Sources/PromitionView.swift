//
//  PromitionView.swift
//  Chess
//
//  Created by Diego García
//

import SwiftUI
import Foundation

struct PromotionView: View {
    @Environment(\.dismiss) var dismiss // <- AGREGA ESTO
    @ObservedObject var game: ChessGame
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Promote Your Pawn")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Choose a piece:")
                .font(.headline)
            
            HStack(spacing: 30) {
                Button(action: {
                    game.promotePawn(to: .queen)
                    dismiss() // <- AGREGA ESTO
                }) {
                    VStack {
                        Image("queen_white")
                            .resizable()
                            .frame(width: 80, height: 80)
                        Text("Queen")
                            .font(.caption)
                    }
                }
                
                Button(action: {
                    game.promotePawn(to: .rook)
                    dismiss() // <- AGREGA ESTO
                }) {
                    VStack {
                        Image("rook_white")
                            .resizable()
                            .frame(width: 80, height: 80)
                        Text("Rook")
                            .font(.caption)
                    }
                }
                
                Button(action: {
                    game.promotePawn(to: .bishop)
                    dismiss() // <- AGREGA ESTO
                }) {
                    VStack {
                        Image("bishop_white")
                            .resizable()
                            .frame(width: 80, height: 80)
                        Text("Bishop")
                            .font(.caption)
                    }
                }
                
                Button(action: {
                    game.promotePawn(to: .knight)
                    dismiss() // <- AGREGA ESTO
                }) {
                    VStack {
                        Image("knight_white")
                            .resizable()
                            .frame(width: 80, height: 80)
                        Text("Knight")
                            .font(.caption)
                    }
                }
            }
            .padding()
        }
        .padding(40)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 10)
    }
}
