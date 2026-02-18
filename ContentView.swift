import SwiftUI
import AVFoundation
import Speech

struct ContentView: View {
    @State private var speechAuthorized = false
    @State private var microphoneAuthorized = false
    @State private var permissionsRequested = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [.black, .indigo]), startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Text("MOVES")
                        .font(.system(size: 64, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 10)
                    
                    Text("Hear the Game. Master the Mind.")
                        .font(.title)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text("\"The greatest strategic minds don't need to see the board\"")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    if speechAuthorized && microphoneAuthorized {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Voice Control Ready")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(10)
                    }
                    
                    NavigationLink(destination: ChessView().navigationBarBackButtonHidden(true)) {
                        Text("Play Accessible Chess")
                            .font(.title2.weight(.semibold))
                            .padding(.horizontal, 40)
                            .padding(.vertical, 20)
                            .background(.blue.gradient)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 25))
                            .shadow(color: .blue.opacity(0.5), radius: 20)
                    }
                }
                .accessibilityLabel("MOVES accessible chess app")
            }
            .navigationBarHidden(true)
            .onAppear {
                if !permissionsRequested {
                    permissionsRequested = true
                    
                    // Delay para asegurar que SwiftUI esté listo
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        requestPermissions()
                    }
                }
            }
        }
    }
    
    func requestPermissions() {
        PermissionsManager.shared.requestPermissions { speech, mic in
            Task { @MainActor in
                self.speechAuthorized = speech
                self.microphoneAuthorized = mic
                print("✅ Permissions updated in UI")
            }
        }
    }}
