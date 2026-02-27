import SwiftUI
import AVFoundation
import Speech

// ── Brand colors ─────────────────────────────────────────────────────────
private extension Color {
    static let movesNavy  = Color(red: 0.13, green: 0.17, blue: 0.27)
    static let movesDeep  = Color(red: 0.09, green: 0.11, blue: 0.18)
    static let movesBlue  = Color(red: 0.52, green: 0.73, blue: 0.88)
    static let movesMid   = Color(red: 0.30, green: 0.42, blue: 0.58)
}

struct ContentView: View {
    @State private var speechAuthorized    = false
    @State private var microphoneAuthorized = false
    @State private var permissionsRequested = false
    @State private var showAbout           = false

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ZStack {
                    // ── Background ────────────────────────────────────
                    LinearGradient(
                        colors: [Color.movesDeep, Color.movesNavy],
                        startPoint: .top, endPoint: .bottom
                    )
                    .ignoresSafeArea()

                    Image("backgroundpiecessin")
                        .resizable()
                        .scaledToFill()
                        .opacity(0.12)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)

                    Circle()
                        .fill(Color.movesBlue.opacity(0.06))
                        .frame(width: 340, height: 340)
                        .blur(radius: 50)

                    // ── Always landscape — orientation is locked ────────
                    landscapeContent(w: max(w, h), h: min(w, h))
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showAbout) {
                AboutView().onAppear { enforceLandscape() }
            }
            .onAppear {
                enforceLandscape()
                if !permissionsRequested {
                    permissionsRequested = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        requestPermissions()
                    }
                }
            }
        }
    }

    // ── LANDSCAPE (primary) ──────────────────────────────────────────────

    @ViewBuilder
    func landscapeContent(w: CGFloat, h: CGFloat) -> some View {
        HStack(spacing: 0) {
            // Left: logo
            VStack {
                Spacer()
                Image("sinfondo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: w * 0.38, maxHeight: h * 0.65)
                Spacer()
            }
            .frame(width: w * 0.45)

            // Right: buttons
            VStack(spacing: 16) {
                Spacer()
                voiceBadge
                playButton
                aboutButton
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
    }

    // ── Shared components ────────────────────────────────────────────────

    @ViewBuilder
    var voiceBadge: some View {
        if speechAuthorized && microphoneAuthorized {
            HStack(spacing: 7) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green).font(.system(size: 13))
                Text("Voice Control Ready")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, 16).padding(.vertical, 7)
            .background(Color.green.opacity(0.12))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.3), lineWidth: 1))
            .cornerRadius(16)
        }
    }

    @ViewBuilder
    var playButton: some View {
        NavigationLink(destination: ChessView().navigationBarBackButtonHidden(true)) {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .bold))
                Text("Start Game")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 46)
            .padding(.vertical, 18)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.20, green: 0.55, blue: 0.35),
                                         Color(red: 0.30, green: 0.72, blue: 0.45)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                }
            )
            .shadow(color: Color(red: 0.25, green: 0.65, blue: 0.40).opacity(0.5), radius: 20, y: 6)
        }
    }

    @ViewBuilder
    var aboutButton: some View {
        Button { showAbout = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "info.circle").font(.system(size: 12))
                Text("About MOVES").font(.system(size: 13, weight: .medium, design: .rounded))
            }
            .foregroundColor(Color.movesBlue.opacity(0.75))
            .padding(.horizontal, 20).padding(.vertical, 9)
            .background(Color.movesBlue.opacity(0.07))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.movesBlue.opacity(0.2), lineWidth: 1))
            .cornerRadius(16)
        }
    }

    func requestPermissions() {
        PermissionsManager.shared.requestPermissions { speech, mic in
            DispatchQueue.main.async {
                self.speechAuthorized    = speech
                self.microphoneAuthorized = mic
            }
        }
    }
}
