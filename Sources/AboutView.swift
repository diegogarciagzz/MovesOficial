//
//  AboutView.swift
//  MovesDiego
//

import SwiftUI

// MARK: - Palette

private extension Color {
    static let aDeep = Color(red: 0.07, green: 0.09, blue: 0.16)
    static let aNavy = Color(red: 0.11, green: 0.15, blue: 0.25)
    static let aBlue = Color(red: 0.52, green: 0.73, blue: 0.88)
    static let aMid  = Color(red: 0.30, green: 0.42, blue: 0.58)
    static let aGold = Color(red: 0.95, green: 0.78, blue: 0.42)
}

// MARK: - Main View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.aDeep, Color.aNavy, Color.aDeep],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .onAppear { enforceLandscape() }

            Circle()
                .fill(Color.aBlue.opacity(0.07))
                .frame(width: 500, height: 500)
                .blur(radius: 80)
                .offset(x: -80, y: -160)

            Circle()
                .fill(Color.aGold.opacity(0.04))
                .frame(width: 380, height: 380)
                .blur(radius: 70)
                .offset(x: 120, y: 300)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── Close button ──────────────────────────────────────
                    HStack {
                        Button { dismiss() } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Close")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(Color.aBlue)
                            .padding(.horizontal, 18).padding(.vertical, 10)
                            .background(Color.aBlue.opacity(0.12))
                            .cornerRadius(22)
                            .overlay(RoundedRectangle(cornerRadius: 22)
                                .stroke(Color.aBlue.opacity(0.2), lineWidth: 1))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 28).padding(.top, 28).padding(.bottom, 8)

                    // ── Logo only (no text — logo already says MOVES) ──────
                    Image("sinfondo")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 220, maxHeight: 150)
                        .padding(.bottom, 36)

                    // ═══════════════════════════════════════════
                    // Max-width container — iPad-optimized
                    // ═══════════════════════════════════════════
                    VStack(spacing: 20) {

                        // 1 ── About the Developer ─────────────────────────
                        AboutCard(icon: "person.fill", iconColor: Color.aMid,
                                  title: "About the Developer") {
                            VStack(alignment: .leading, spacing: 18) {

                                Text("Hi, I'm **Diego García** — a developer, leader, and chess player who builds things that actually matter.")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineSpacing(4)

                                // CS Society + SEITC — single block
                                HStack(alignment: .top, spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.aGold.opacity(0.14))
                                            .frame(width: 40, height: 40)
                                        Image(systemName: "person.3.fill")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color.aGold)
                                    }
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Computer Science Student Society")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                        Text("President")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(Color.aGold.opacity(0.85))
                                        Text("Leading a 30+ member team, representing 1,000+ students. We organize large-scale academic and technical events, connect our community with industry, and help peers grow, collaborate, and make an impact beyond the classroom.")
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.65))
                                            .lineSpacing(3)
                                    }
                                }
                                .padding(14)
                                .background(Color.aGold.opacity(0.06))
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.aGold.opacity(0.18), lineWidth: 1))

                                Text("I believe technology should lift everyone up. MOVES is the product of that belief — built for the community, with access and inclusion at its core.")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineSpacing(4)

                                Divider().background(Color.aBlue.opacity(0.2))

                                HStack(spacing: 10) {
                                    TagPill(text: "Swift / SwiftUI", color: Color.aBlue)
                                    TagPill(text: "iOS Dev", color: Color.aMid)
                                    TagPill(text: "Accessibility", color: Color.aGold)
                                }
                            }
                        }

                        // 2 ── Photos ───────────────────────────────────────
                        PhotoPairSection()

                        // 3 ── Story ────────────────────────────────────────
                        AboutCard(icon: "crown.fill", iconColor: Color.aGold,
                                  title: "The Story Behind MOVES") {
                            VStack(alignment: .leading, spacing: 16) {
                                StoryParagraph(
                                    icon: "figure.chess",
                                    text: "I've played chess since I was a kid. I competed in tournaments and truly fell in love with the game."
                                )
                                StoryParagraph(
                                    icon: "eye.slash",
                                    text: "At one of those tournaments I met a blind man who was playing chess. I was amazed — and curious. **How does he play on his phone?**"
                                )
                                StoryParagraph(
                                    icon: "exclamationmark.circle",
                                    text: "When I started looking at chess apps, the answer was sobering: **he basically can't.** None of them have meaningful accessibility features — no voice control, no audio feedback, nothing built for someone who can't see the screen."
                                )

                                Divider()
                                    .background(Color.aBlue.opacity(0.2))
                                    .padding(.vertical, 2)

                                Text("That moment stayed with me. MOVES is my answer — a chess app built from scratch so that **anyone**, sighted or not, can pick it up and play. Just your voice, just the game.")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineSpacing(4)
                            }
                        }

                        // 4 ── Voice commands ───────────────────────────────
                        AboutCard(icon: "mic.fill", iconColor: Color.aBlue,
                                  title: "How to Play by Voice") {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(voiceCommands, id: \.0) { cmd in
                                    VoiceLine(text: cmd.0, desc: cmd.1)
                                        .padding(.vertical, 9)
                                    if cmd.0 != voiceCommands.last!.0 {
                                        Divider().background(Color.white.opacity(0.07))
                                    }
                                }
                            }
                        }

                    }
                    .frame(maxWidth: 680)
                    .padding(.horizontal, 20)

                    // ── Footer ────────────────────────────────────────────
                    VStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color.aGold.opacity(0.4))
                        Text("MOVES  ·  Made with ♟ by Diego García")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.25))
                    }
                    .padding(.top, 16).padding(.bottom, 50)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private let voiceCommands: [(String, String)] = [
        ("\"e4\"",               "move a pawn to e4"),
        ("\"knight c3\"",        "develop a knight"),
        ("\"bishop c4\"",        "place a bishop"),
        ("\"e2 to e4\"",         "explicit from → to"),
        ("\"castle\"",           "kingside castling"),
        ("\"queenside castle\"", "queenside castling"),
    ]
}

// MARK: - Photo Pair (simple, no frame)

private struct PhotoPairSection: View {
    var body: some View {
        HStack(spacing: 14) {
            SimplePhoto(imageName: "photo1", caption: "At the board")
            SimplePhoto(imageName: "photo2", caption: "Where it all started")
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SimplePhoto: View {
    let imageName: String
    let caption: String

    var body: some View {
        VStack(spacing: 8) {
            if UIImage(named: imageName) != nil {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipped()
                    .cornerRadius(16)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.04))
                    VStack(spacing: 8) {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 30))
                            .foregroundColor(Color.aBlue.opacity(0.35))
                        Text("photo coming soon")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.25))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 220)
            }

            Text(caption)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.45))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Cards & Helpers

private struct AboutCard<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let content: () -> Content

    init(icon: String, iconColor: Color, title: String,
         @ViewBuilder content: @escaping () -> Content) {
        self.icon = icon; self.iconColor = iconColor
        self.title = title; self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11)
                        .fill(iconColor.opacity(0.18))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                Text(title)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            content()
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.09), lineWidth: 1))
    }
}

private struct StoryParagraph: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(Color.aBlue.opacity(0.7))
                .frame(width: 20, height: 20)
                .padding(.top, 1)
            Text(.init(text))
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct VoiceLine: View {
    let text: String
    let desc: String
    var body: some View {
        HStack(spacing: 14) {
            Text(text)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(Color.aBlue)
                .frame(minWidth: 160, alignment: .leading)
            Text(desc)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
            Spacer()
        }
    }
}

private struct TagPill: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(color.opacity(0.12))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.25), lineWidth: 1))
            .cornerRadius(16)
    }
}
