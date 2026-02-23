import SwiftUI
import AVFoundation
import Speech

// ── Brand colors extracted from the MOVES logo ───────────────────────────
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
                let isLandscape = w > h

                ZStack {
                    // ── Dark gradient background ─────────────────────
                    LinearGradient(
                        colors: [Color.movesDeep, Color.movesNavy],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()

                    // ── Chess pieces background image (subtle) ───────
                    Image("backgroundpiecessin")
                        .resizable()
                        .scaledToFill()
                        .opacity(0.12)
                        .ignoresSafeArea()

                    // ── Decorative glow ──────────────────────────────
                    Circle()
                        .fill(Color.movesBlue.opacity(0.06))
                        .frame(width: 360, height: 360)
                        .blur(radius: 55)
                        .offset(y: isLandscape ? 0 : -80)

                    // ── Main content: adapts to landscape/portrait ───
                    if isLandscape {
                        landscapeLayout(w: w, h: h)
                    } else {
                        portraitLayout(w: w, h: h)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
            .onAppear {
                if !permissionsRequested {
                    permissionsRequested = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        requestPermissions()
                    }
                }
            }
        }
    }

    // ── PORTRAIT LAYOUT ──────────────────────────────────────────────────

    @ViewBuilder
    func portraitLayout(w: CGFloat, h: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo
            Image("sinfondo")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: min(320, w * 0.75), maxHeight: h * 0.30)

            Spacer().frame(height: h * 0.03)

            // Voice badge
            voiceBadge

            Spacer().frame(height: h * 0.04)

            // Play button
            playButton

            Spacer().frame(height: h * 0.02)

            // About button
            aboutButton

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // ── LANDSCAPE LAYOUT ─────────────────────────────────────────────────

    @ViewBuilder
    func landscapeLayout(w: CGFloat, h: CGFloat) -> some View {
        HStack(spacing: 0) {
            // Left side: logo
            VStack {
                Spacer()
                Image("sinfondo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: w * 0.40, maxHeight: h * 0.65)
                Spacer()
            }
            .frame(width: w * 0.45)

            // Right side: buttons
            VStack(spacing: 14) {
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

    // ── Shared sub-views ─────────────────────────────────────────────────

    @ViewBuilder
    var voiceBadge: some View {
        if speechAuthorized && microphoneAuthorized {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 14))
                Text("Voice Control Ready")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.13))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(18)
        }
    }

    @ViewBuilder
    var playButton: some View {
        NavigationLink(destination: ChessView().navigationBarBackButtonHidden(true)) {
            Text("Play Accessible Chess")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 42)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.movesMid, Color.movesBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 26))
                .shadow(color: Color.movesBlue.opacity(0.4), radius: 16, y: 5)
        }
    }

    @ViewBuilder
    var aboutButton: some View {
        Button { showAbout = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 13))
                Text("About MOVES")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
            }
            .foregroundColor(Color.movesBlue.opacity(0.8))
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background(Color.movesBlue.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.movesBlue.opacity(0.25), lineWidth: 1)
            )
            .cornerRadius(18)
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
