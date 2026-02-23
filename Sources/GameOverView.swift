//
//  GameOverView.swift
//  MovesDiego
//
//  Custom game-over popup matching the app's dark theme.
//

import SwiftUI

struct GameOverView: View {
    let isCheckmate: Bool
    let isStalemate: Bool
    let playerWins: Bool        // true when AI is checkmated
    let onPlayAgain: () -> Void
    let onMenu: () -> Void

    private var icon: String {
        if isStalemate { return "equal.circle.fill" }
        return playerWins ? "trophy.fill" : "xmark.octagon.fill"
    }

    private var iconColor: Color {
        if isStalemate { return Color(red: 0.52, green: 0.73, blue: 0.88) }
        return playerWins
            ? Color(red: 0.95, green: 0.78, blue: 0.20)
            : Color(red: 0.85, green: 0.30, blue: 0.30)
    }

    private var title: String {
        if isStalemate { return "Stalemate" }
        return playerWins ? "Checkmate!" : "Checkmate"
    }

    private var subtitle: String {
        if isStalemate { return "It's a draw — well played!" }
        return playerWins ? "You Win!" : "You Lose"
    }

    private var message: String {
        if isStalemate { return "Neither side can force a win. A respectable result." }
        return playerWins
            ? "Great strategy! You defeated the AI."
            : "The AI got you this time. Try again!"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.78)
                .ignoresSafeArea()
                .onTapGesture { }

            VStack(spacing: 0) {

                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.18))
                        .frame(width: 64, height: 64)
                    Image(systemName: icon)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                .padding(.top, 28)
                .padding(.bottom, 12)

                // Title
                Text(title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // Subtitle
                Text(subtitle)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(iconColor)
                    .padding(.top, 2)
                    .padding(.bottom, 10)

                // Message
                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)

                Divider().background(Color.white.opacity(0.08))

                // Buttons
                HStack(spacing: 14) {
                    // Menu button
                    Button(action: onMenu) {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Menu")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 22).padding(.vertical, 12)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                    }

                    // Play Again button
                    Button(action: onPlayAgain) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13, weight: .bold))
                            Text("Play Again")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 28).padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.30, green: 0.42, blue: 0.58), iconColor],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: iconColor.opacity(0.35), radius: 8, y: 3)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .frame(width: 360)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(red: 0.09, green: 0.11, blue: 0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(iconColor.opacity(0.25), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.65), radius: 36, y: 10)
        }
    }
}
