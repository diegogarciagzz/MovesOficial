//
//  DifficultySelectionView.swift
//  MovesDiego
//

import SwiftUI

private extension Color {
    static let dDeep = Color(red: 0.08, green: 0.09, blue: 0.14)
    static let dNavy = Color(red: 0.13, green: 0.17, blue: 0.27)
    static let dBlue = Color(red: 0.52, green: 0.73, blue: 0.88)
    static let dMid  = Color(red: 0.30, green: 0.42, blue: 0.58)
}

struct DifficultySelectionView: View {
    @Binding var selectedDifficulty: DifficultyLevel
    @Environment(\.presentationMode) var presentationMode

    private let levels: [(level: DifficultyLevel,
                          label: String,
                          piece: String,
                          description: String,
                          accent: Color)] = [
        (.easy,   "Easy",   "pawn_white",
         "Random moves — great for beginners",
         Color(red: 0.30, green: 0.75, blue: 0.45)),
        (.medium, "Medium", "knight_white",
         "Prefers captures — a real challenge",
         Color(red: 0.52, green: 0.73, blue: 0.88)),
        (.hard,   "Hard",   "queen_white",
         "Minimax AI — bring your best game",
         Color(red: 0.85, green: 0.45, blue: 0.35))
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.dDeep, Color.dNavy],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.dBlue.opacity(0.07))
                .frame(width: 340, height: 340)
                .blur(radius: 55)
                .offset(y: -80)

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color.dBlue.opacity(0.7))
                        .padding(.top, 36)

                    Text("Choose Difficulty")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("How tough should your opponent be?")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.bottom, 28)
                }

                // Difficulty cards
                VStack(spacing: 14) {
                    ForEach(levels, id: \.label) { item in
                        DifficultyCard(
                            level: item.level,
                            label: item.label,
                            piece: item.piece,
                            description: item.description,
                            accent: item.accent,
                            isSelected: selectedDifficulty == item.level
                        ) {
                            selectedDifficulty = item.level
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
    }
}

private struct DifficultyCard: View {
    let level: DifficultyLevel
    let label: String
    let piece: String
    let description: String
    let accent: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Piece icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(accent.opacity(0.18))
                        .frame(width: 52, height: 52)
                    Image(piece)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                }

                // Labels
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.55))
                }

                Spacer()

                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? accent : Color.white.opacity(0.25))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(isSelected ? 0.1 : 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? accent.opacity(0.7) : Color.white.opacity(0.08),
                                    lineWidth: isSelected ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
