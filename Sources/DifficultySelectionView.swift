//
//  DifficultySelectionView.swift
//  Chess
//
//  Created by Diego García
//

import SwiftUI

struct DifficultySelectionView: View {
    @Binding var selectedDifficulty: DifficultyLevel
    @Environment(\.dismiss) var dismiss

    private let bg = Color(red: 0.10, green: 0.10, blue: 0.14)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("Choose Difficulty")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)

                    Text("Select your opponent's strength")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.45))
                }

                HStack(spacing: 20) {
                    difficultyCard(
                        level: .easy,
                        icon: "pawn_black",
                        title: "Easy",
                        subtitle: "Random moves",
                        accent: Color.green
                    )
                    difficultyCard(
                        level: .medium,
                        icon: "knight_black",
                        title: "Medium",
                        subtitle: "Strategic play",
                        accent: Color.orange
                    )
                    difficultyCard(
                        level: .hard,
                        icon: "queen_black",
                        title: "Hard",
                        subtitle: "Expert AI",
                        accent: Color.red
                    )
                }
            }
            .padding(40)
        }
    }

    private func difficultyCard(
        level: DifficultyLevel,
        icon: String,
        title: String,
        subtitle: String,
        accent: Color
    ) -> some View {
        Button {
            selectedDifficulty = level
            dismiss()
        } label: {
            VStack(spacing: 14) {
                Image(icon)
                    .resizable()
                    .frame(width: 64, height: 64)

                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .background(Color.white.opacity(0.06))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(accent.opacity(0.25), lineWidth: 1)
            )
        }
    }
}
