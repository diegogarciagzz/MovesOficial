//
//  AboutView.swift
//  MovesDiego
//

import SwiftUI

private extension Color {
    static let aDeep = Color(red: 0.09, green: 0.11, blue: 0.18)
    static let aNavy = Color(red: 0.13, green: 0.17, blue: 0.27)
    static let aBlue = Color(red: 0.52, green: 0.73, blue: 0.88)
    static let aMid  = Color(red: 0.30, green: 0.42, blue: 0.58)
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.aDeep, Color.aNavy],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            Circle()
                .fill(Color.aBlue.opacity(0.06))
                .frame(width: 360, height: 360)
                .blur(radius: 55)
                .offset(y: -100)

            ScrollView {
                VStack(spacing: 0) {

                    // ── Header ────────────────────────────────────────────
                    HStack {
                        Button { dismiss() } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Close")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(Color.aBlue)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Color.aBlue.opacity(0.12))
                            .cornerRadius(20)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 28).padding(.top, 24).padding(.bottom, 4)

                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 200, maxHeight: 130)
                        .padding(.bottom, 24)

                    // ── Story card ────────────────────────────────────────
                    StoryCard(icon: "crown.fill", iconColor: Color.aBlue, title: "The Story Behind MOVES") {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("I've played chess since I was a kid. I competed in tournaments and truly fell in love with the game.")

                            Text("At one of those tournaments I met a blind man who was playing chess. I was amazed — and curious. How does he play on his phone?")

                            Text("When I started looking at chess apps, the answer was sobering: **he basically can't.** None of them have meaningful accessibility features. No voice control, no audio feedback, nothing built for someone who can't see the screen.")

                            Divider().background(Color.aBlue.opacity(0.2))

                            Text("That moment stayed with me. MOVES is my answer to it — a chess app built from scratch so that **anyone**, sighted or not, can pick it up and play. Just your voice, just the game.")
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }

                    // ── Developer card ────────────────────────────────────
                    StoryCard(icon: "person.fill", iconColor: Color.aMid, title: "About the Developer") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Hi, I'm **Diego García** — a developer passionate about building things that actually matter.")

                            Text("I believe great software should be for everyone. MOVES is one of my most personal projects, sitting right at the intersection of two things I love: chess and accessible technology.")

                            Divider().background(Color.aBlue.opacity(0.2))

                            HStack(spacing: 12) {
                                TagPill(text: "Swift / SwiftUI")
                                TagPill(text: "iOS Dev")
                                TagPill(text: "Accessibility")
                            }
                        }
                    }

                    // ── Voice commands card ───────────────────────────────
                    StoryCard(icon: "mic.fill", iconColor: Color.aBlue, title: "How to Play by Voice") {
                        VStack(alignment: .leading, spacing: 8) {
                            VoiceLine(text: "\"e4\"",               desc: "move a pawn to e4")
                            VoiceLine(text: "\"knight c3\"",        desc: "develop a knight")
                            VoiceLine(text: "\"bishop c4\"",        desc: "place a bishop")
                            VoiceLine(text: "\"e2 to e4\"",         desc: "explicit from → to")
                            VoiceLine(text: "\"castle\"",            desc: "kingside castling")
                            VoiceLine(text: "\"queenside castle\"", desc: "queenside castling")
                        }
                    }

                    // ── Footer ────────────────────────────────────────────
                    VStack(spacing: 5) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color.aBlue.opacity(0.5))
                        Text("MOVES  ·  Made with ♟ by Diego García")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .padding(.top, 8).padding(.bottom, 40)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// ── Small reusable components ─────────────────────────────────────────────

private struct StoryCard<Content: View>: View {
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(iconColor.opacity(0.18))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            content()
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.82))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.09), lineWidth: 1))
        .padding(.horizontal, 20).padding(.bottom, 14)
    }
}

private struct VoiceLine: View {
    let text: String
    let desc: String
    var body: some View {
        HStack(spacing: 12) {
            Text(text)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(Color.aBlue)
                .frame(width: 160, alignment: .leading)
            Text(desc)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.65))
        }
    }
}

private struct TagPill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(Color.aBlue)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(Color.aBlue.opacity(0.12))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.aBlue.opacity(0.25), lineWidth: 1))
            .cornerRadius(14)
    }
}
