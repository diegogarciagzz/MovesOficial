//
//  AboutView.swift
//  MovesDiego
//
//  Presentation page — About the developer & the story behind MOVES
//

import SwiftUI

// Reuse the brand colors declared in ContentView.swift
private extension Color {
    static let aNavy = Color(red: 0.13, green: 0.17, blue: 0.27)
    static let aDeep = Color(red: 0.09, green: 0.11, blue: 0.18)
    static let aBlue = Color(red: 0.52, green: 0.73, blue: 0.88)
    static let aMid  = Color(red: 0.30, green: 0.42, blue: 0.58)
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Same background as home screen
            LinearGradient(
                colors: [Color.aDeep, Color.aNavy],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Soft glow
            Circle()
                .fill(Color.aBlue.opacity(0.06))
                .frame(width: 380, height: 380)
                .blur(radius: 55)
                .offset(y: -80)

            ScrollView {
                VStack(spacing: 0) {

                    // ── Header with logo ──────────────────────────────────
                    HStack {
                        Button { dismiss() } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Close")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(Color.aBlue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.aBlue.opacity(0.12))
                            .cornerRadius(20)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 24)
                    .padding(.bottom, 8)

                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 200, maxHeight: 140)
                        .padding(.bottom, 28)

                    // ── Developer card ─────────────────────────────────────
                    InfoCard(
                        icon: "person.fill",
                        iconColor: Color.aBlue,
                        title: "About the Developer"
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Hi, I'm **Diego García** — a passionate developer who believes technology should be inclusive and meaningful for everyone.")
                                .fixedSize(horizontal: false, vertical: true)

                            Text("I build apps that solve real problems, with a focus on clean code, thoughtful design, and accessibility. MOVES is one of my most personal projects: it's proof that a great chess experience doesn't require touching a screen.")
                                .fixedSize(horizontal: false, vertical: true)

                            Divider().background(Color.aBlue.opacity(0.2))

                            Label("Swift / SwiftUI", systemImage: "swift")
                            Label("iOS & iPadOS Development", systemImage: "iphone")
                            Label("Accessibility & Voice UX", systemImage: "mic.fill")
                        }
                    }

                    // ── App story card ─────────────────────────────────────
                    InfoCard(
                        icon: "chess.queen",           // fallback to text if icon missing
                        iconColor: Color.aBlue,
                        title: "The Story Behind MOVES",
                        sfSymbol: "gamecontroller.fill"
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Chess is one of humanity's greatest games — but most digital chess apps require you to **see and touch** the board. MOVES flips that idea entirely.")
                                .fixedSize(horizontal: false, vertical: true)

                            Text("With MOVES you control every piece using only your voice:")
                                .fixedSize(horizontal: false, vertical: true)

                            VoiceFormatRow(icon: "mic", text: "\"e4\"  —  advance a pawn")
                            VoiceFormatRow(icon: "mic", text: "\"knight c3\"  —  develop a piece")
                            VoiceFormatRow(icon: "mic", text: "\"e2 to e4\"  —  explicit move")
                            VoiceFormatRow(icon: "mic", text: "\"castle\"  —  kingside castling")

                            Divider().background(Color.aBlue.opacity(0.2))

                            Text("MOVES was built to show that accessible design isn't a limitation — it's a superpower. Anyone, anywhere, should be able to play and love chess.")
                                .fixedSize(horizontal: false, vertical: true)
                                .foregroundColor(.white.opacity(0.75))
                        }
                    }

                    // ── Tech stack card ────────────────────────────────────
                    InfoCard(
                        icon: "cpu.fill",
                        iconColor: Color.aMid,
                        title: "Built With",
                        sfSymbol: "cpu.fill"
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            TechRow(label: "Language",  value: "Swift 5")
                            TechRow(label: "UI",         value: "SwiftUI")
                            TechRow(label: "Voice",      value: "SFSpeechRecognizer + AVAudioRecorder")
                            TechRow(label: "TTS",        value: "AVSpeechSynthesizer")
                            TechRow(label: "Platform",   value: "iOS 17 · iPadOS 17")
                            TechRow(label: "AI",         value: "Minimax with 3 difficulty levels")
                        }
                    }

                    // ── Footer ─────────────────────────────────────────────
                    VStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color.aBlue.opacity(0.6))
                        Text("MOVES  ·  Made with ♟ by Diego García")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 48)
                }
            }
        }
    }
}

// ── Reusable card component ───────────────────────────────────────────────
private struct InfoCard<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let sfSymbol: String?
    let content: () -> Content

    init(icon: String,
         iconColor: Color,
         title: String,
         sfSymbol: String? = nil,
         @ViewBuilder content: @escaping () -> Content) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.sfSymbol = sfSymbol
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Card header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: sfSymbol ?? icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            // Card body
            content()
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.80))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
}

// ── Small helpers ─────────────────────────────────────────────────────────
private struct VoiceFormatRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Color.aBlue)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
        }
    }
}

private struct TechRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.aBlue)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.80))
            Spacer()
        }
    }
}
