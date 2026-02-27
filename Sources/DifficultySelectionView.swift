//
//  DifficultySelectionView.swift
//  MovesDiego
//
//  Landscape-first iPad layout: hero panel left, difficulty cards right.
//

import SwiftUI

private extension Color {
    static let dDeep = Color(red: 0.07, green: 0.09, blue: 0.15)
    static let dNavy = Color(red: 0.12, green: 0.16, blue: 0.26)
    static let dBlue = Color(red: 0.52, green: 0.73, blue: 0.88)
    static let dMid  = Color(red: 0.30, green: 0.42, blue: 0.58)
    static let dGold = Color(red: 0.95, green: 0.78, blue: 0.42)
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
            Color.dDeep.ignoresSafeArea()

            // Ambient glows
            Circle()
                .fill(Color.dBlue.opacity(0.08))
                .frame(width: 420, height: 420)
                .blur(radius: 60)
                .offset(x: -180, y: -60)
            Circle()
                .fill(Color.dGold.opacity(0.05))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: 220, y: 200)

            GeometryReader { geo in
                HStack(spacing: 0) {
                    // ── Left: hero branding panel ──────────────────────────
                    heroPanel
                        .frame(width: geo.size.width * 0.40)

                    // Subtle divider
                    Rectangle()
                        .fill(Color.white.opacity(0.07))
                        .frame(width: 1)
                        .padding(.vertical, 40)

                    // ── Right: selection panel ─────────────────────────────
                    selectionPanel
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Hero Panel (left)

    private var heroPanel: some View {
        ZStack {
            LinearGradient(
                colors: [Color.dBlue.opacity(0.05), Color.dGold.opacity(0.04)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                Spacer()

                // Logo — already includes the MOVES name
                Image("sinfondo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 160, maxHeight: 110)
                    .padding(.bottom, 8)

                // Decorative pieces row
                HStack(spacing: 8) {
                    ForEach(["pawn_white", "knight_white", "bishop_white",
                              "rook_white", "queen_white"], id: \.self) { p in
                        Image(p)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .opacity(0.22)
                    }
                }
                .padding(.top, 22)

                Spacer()

                Text("Made with ♟ by Diego García")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.18))
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 28)
        }
    }

    // MARK: - Selection Panel (right)

    private var selectionPanel: some View {
        VStack(spacing: 0) {
            Spacer()

            // Header
            VStack(spacing: 6) {
                Text("Choose Difficulty")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("How tough should your opponent be?")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.45))
            }
            .padding(.bottom, 28)

            // Cards
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
            .frame(maxWidth: 480)
            .padding(.horizontal, 36)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Difficulty Card

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
            HStack(spacing: 18) {
                // Piece icon
                ZStack {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(accent.opacity(isSelected ? 0.25 : 0.14))
                        .frame(width: 56, height: 56)
                    Image(piece)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 38, height: 38)
                }

                // Labels
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.52))
                }

                Spacer()

                // Selection indicator
                ZStack {
                    Circle()
                        .fill(isSelected ? accent.opacity(0.2) : Color.clear)
                        .frame(width: 28, height: 28)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? accent : Color.white.opacity(0.2))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(isSelected ? 0.1 : 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
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
