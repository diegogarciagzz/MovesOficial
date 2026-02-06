import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var synthesizer = AVSpeechSynthesizer()
    
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
                    .simultaneousGesture(TapGesture().onEnded {
                        speak("Welcome to MOVES. Enable VoiceOver to hear board and moves.")
                    })
                }
                .accessibilityLabel("MOVES accessible chess app. Toca Play para comenzar.")
            }
            .navigationBarHidden(true)
            .onAppear {
                speak("MOVES loaded. Passionate chess for blind players.")
            }
        }
    }
    
    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }
}
