//
//  OnboardingView.swift
//  MovesDiego
//
//  Landscape-optimized onboarding: icon left, text right, buttons fixed.
//

import SwiftUI
import AVFoundation

// ── Data ─────────────────────────────────────────────────────────────────────

private struct Step {
    let icon: String
    let color: Color
    let title: String
    let body: String
    let voice: String
    let hint: String
}

private let steps: [Step] = [
    Step(icon: "crown.fill",
         color: Color(red: 0.52, green: 0.73, blue: 0.88),
         title: "Welcome to MOVES",
         body: "An accessible chess app you can play with your voice or by tapping. Let's walk through the basics.",
         voice: "Welcome to MOVES! This is an accessible chess app you can play by voice or by touch. Let me walk you through how it works.",
         hint: "This guide only appears once."),
    Step(icon: "hand.tap.fill",
         color: Color(red: 0.40, green: 0.80, blue: 0.55),
         title: "Select a Piece",
         body: "Tap any white piece to select it. It highlights and blue dots show where it can move.",
         voice: "To move a piece, start by tapping it. Your piece will glow, and blue dots will show all the squares it can move to.",
         hint: "Only your white pieces can be selected."),
    Step(icon: "dot.circle.fill",
         color: Color(red: 0.25, green: 0.60, blue: 1.0),
         title: "Move to a Square",
         body: "Tap any blue dot to move there. A blue ring means you can capture an enemy piece.",
         voice: "After selecting a piece, tap one of the blue dots to move there. A blue ring means you can capture an enemy piece.",
         hint: "Tap another piece to change selection."),
    Step(icon: "mic.fill",
         color: Color(red: 0.52, green: 0.73, blue: 0.88),
         title: "Play by Voice",
         body: "Tap the mic button and say a move:\n\"e4\" · \"knight c3\" · \"e2 to e4\" · \"castle\"",
         voice: "You can also play by voice! Tap the microphone button and say something like 'e four', 'knight c three', or 'castle'.",
         hint: "Clear pronunciation works best."),
    Step(icon: "sparkles",
         color: Color(red: 0.90, green: 0.70, blue: 0.30),
         title: "You're All Set!",
         body: "The AI plays as black automatically. Good luck and enjoy the game!",
         voice: "That's everything! The AI will play as black. Good luck, and enjoy MOVES!",
         hint: "Review commands in About MOVES.")
]

// ── Speaker ──────────────────────────────────────────────────────────────────

final class OnboardingSpeaker: ObservableObject, @unchecked Sendable {
    private let synth = AVSpeechSynthesizer()
    func speak(_ text: String) {
        synth.stopSpeaking(at: .immediate)
        let utt = AVSpeechUtterance(string: text)
        utt.voice = AVSpeechSynthesisVoice(language: "en-US")
        utt.rate = 0.46; utt.pitchMultiplier = 1.05
        synth.speak(utt)
    }
    func stop() { synth.stopSpeaking(at: .immediate) }
}

// ── View ─────────────────────────────────────────────────────────────────────

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @StateObject private var speaker = OnboardingSpeaker()
    @State private var currentStep = 0
    @State private var pulse = false

    private var step: Step { steps[currentStep] }

    var body: some View {
        ZStack {
            Color.black.opacity(0.80)
                .ignoresSafeArea()
                .onTapGesture { }

            GeometryReader { geo in
                let cardW = min(560, geo.size.width * 0.72)
                let cardH = min(280, geo.size.height * 0.82)

                // Centered card
                VStack(spacing: 0) {

                    // ── Step dots ────────────────────────────────
                    HStack(spacing: 6) {
                        ForEach(0..<steps.count, id: \.self) { i in
                            Capsule()
                                .fill(i == currentStep ? step.color : Color.white.opacity(0.2))
                                .frame(width: i == currentStep ? 20 : 6, height: 6)
                                .animation(.easeInOut(duration: 0.2), value: currentStep)
                        }
                    }
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                    // ── Main: icon left + text right ─────────────
                    HStack(alignment: .center, spacing: 18) {

                        // Icon column
                        VStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(step.color.opacity(0.18))
                                    .frame(width: 56, height: 56)

                                Circle()
                                    .stroke(step.color.opacity(pulse ? 0 : 0.35), lineWidth: 2)
                                    .frame(width: 56 + (pulse ? 16 : 0),
                                           height: 56 + (pulse ? 16 : 0))
                                    .animation(.easeOut(duration: 1.3)
                                        .repeatForever(autoreverses: false), value: pulse)

                                Image(systemName: step.icon)
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(step.color)
                            }

                            // Step number
                            Text("\(currentStep + 1)/\(steps.count)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.3))
                                .padding(.top, 6)

                            Spacer()
                        }
                        .frame(width: 80)

                        // Text column
                        VStack(alignment: .leading, spacing: 6) {
                            Text(step.title)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            Text(step.body)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.75))
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)

                            // Hint
                            Text(step.hint)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(step.color.opacity(0.85))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(step.color.opacity(0.1))
                                .cornerRadius(7)
                                .padding(.top, 2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 22)
                    .frame(maxHeight: .infinity)

                    // ── Divider ──────────────────────────────────
                    Divider().background(Color.white.opacity(0.08))

                    // ── Buttons ──────────────────────────────────
                    HStack(spacing: 8) {
                        Button { finish() } label: {
                            Text("Skip")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.3))
                                .padding(.horizontal, 14).padding(.vertical, 10)
                        }

                        Spacer()

                        if currentStep > 0 {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { currentStep -= 1 }
                                speaker.speak(steps[currentStep].voice)
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                                    Text("Back").font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(.white.opacity(0.55))
                                .padding(.horizontal, 12).padding(.vertical, 9)
                                .background(Color.white.opacity(0.07))
                                .cornerRadius(10)
                            }
                        }

                        Button {
                            if currentStep < steps.count - 1 {
                                withAnimation(.easeInOut(duration: 0.2)) { currentStep += 1 }
                                speaker.speak(steps[currentStep].voice)
                            } else { finish() }
                        } label: {
                            HStack(spacing: 4) {
                                Text(currentStep < steps.count - 1 ? "Next" : "Let's Play!")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                if currentStep < steps.count - 1 {
                                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 18).padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.30, green: 0.42, blue: 0.58), step.color],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .cornerRadius(10)
                            .shadow(color: step.color.opacity(0.3), radius: 6, y: 2)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .frame(width: cardW, height: cardH)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(red: 0.09, green: 0.11, blue: 0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(step.color.opacity(0.2), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.6), radius: 30, y: 8)
                // Center in GeometryReader
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
        .onAppear {
            pulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                speaker.speak(steps[0].voice)
            }
        }
        .onDisappear { speaker.stop() }
    }

    private func finish() {
        speaker.stop()
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        withAnimation(.easeOut(duration: 0.3)) { isPresented = false }
    }
}
