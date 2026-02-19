import SwiftUI
import AVFoundation
import Speech

// ── Brand colors extracted from the MOVES logo ───────────────────────────
private extension Color {
    static let movesNavy  = Color(red: 0.13, green: 0.17, blue: 0.27)  // dark navy bg
    static let movesDeep  = Color(red: 0.09, green: 0.11, blue: 0.18)  // deeper navy
    static let movesBlue  = Color(red: 0.52, green: 0.73, blue: 0.88)  // light blue accent
    static let movesMid   = Color(red: 0.30, green: 0.42, blue: 0.58)  // mid blue
}

struct ContentView: View {
    @State private var speechAuthorized    = false
    @State private var microphoneAuthorized = false
    @State private var permissionsRequested = false
    @State private var showAbout           = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background matches the logo's dark navy tone
                LinearGradient(
                    colors: [Color.movesDeep, Color.movesNavy],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Subtle decorative glow behind the logo area
                Circle()
                    .fill(Color.movesBlue.opacity(0.07))
                    .frame(width: 420, height: 420)
                    .blur(radius: 60)
                    .offset(y: -100)

                ScrollView {
                    VStack(spacing: 0) {

                        // ── Logo ──────────────────────────────────────────
                        Image("logo")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 320, maxHeight: 220)
                            .padding(.top, 48)
                            .padding(.bottom, 8)

                        // ── Tagline ───────────────────────────────────────
                        Text("Hear the Game. Master the Mind.")
                            .font(.system(size: 19, weight: .medium, design: .rounded))
                            .foregroundColor(Color.movesBlue)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.bottom, 6)

                        Text("\"The greatest strategic minds don't need to see the board\"")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white.opacity(0.45))
                            .padding(.horizontal, 40)
                            .padding(.bottom, 36)

                        // ── Voice Ready badge ─────────────────────────────
                        if speechAuthorized && microphoneAuthorized {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 15))
                                Text("Voice Control Ready")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.green.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.green.opacity(0.35), lineWidth: 1)
                            )
                            .cornerRadius(20)
                            .padding(.bottom, 28)
                        } else {
                            Spacer().frame(height: 28)
                        }

                        // ── Play button ───────────────────────────────────
                        NavigationLink(destination: ChessView().navigationBarBackButtonHidden(true)) {
                            HStack(spacing: 14) {
                                Image("icono")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 28, height: 28)

                                Text("Play Accessible Chess")
                                    .font(.system(size: 19, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(
                                    colors: [Color.movesMid, Color.movesBlue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 28))
                            .shadow(color: Color.movesBlue.opacity(0.45), radius: 18, y: 6)
                        }
                        .padding(.bottom, 16)

                        // ── About button ──────────────────────────────────
                        Button {
                            showAbout = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 14))
                                Text("About MOVES")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                            }
                            .foregroundColor(Color.movesBlue.opacity(0.85))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.movesBlue.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.movesBlue.opacity(0.3), lineWidth: 1)
                            )
                            .cornerRadius(20)
                        }
                        .padding(.bottom, 48)
                    }
                    .frame(maxWidth: .infinity)
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

    func requestPermissions() {
        PermissionsManager.shared.requestPermissions { speech, mic in
            DispatchQueue.main.async {
                self.speechAuthorized    = speech
                self.microphoneAuthorized = mic
            }
        }
    }
}
