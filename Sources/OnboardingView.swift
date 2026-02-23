//
//  OnboardingView.swift
//  MovesDiego
//
//  First-time interactive tutorial with voice narration.
//  Shown once on first game launch; skippable at any step.
//

import SwiftUI
import AVFoundation

// ── Data model ───────────────────────────────────────────────────────────────

private struct OnboardingStep {
    let icon: String
    let iconColor: Color
    let title: String
    let body: String          // displayed text
    let voiceText: String     // spoken text (may differ slightly)
    let hint: String          // small contextual hint below the card
}

private let onboardingSteps: [OnboardingStep] = [
    OnboardingStep(
        icon: "crown.fill",
        iconColor: Color(red: 0.52, green: 0.73, blue: 0.88),
        title: "Welcome to MOVES",
        body: "MOVES is an accessible chess app you can play with just your voice or by tapping the board. This quick guide will walk you through the basics.",
        voiceText: "Welcome to MOVES! This is an accessible chess app you can play entirely by voice or by touch. Let me walk you through how it works.",
        hint: "This guide only appears once."
    ),
    OnboardingStep(
        icon: "hand.tap.fill",
        iconColor: Color(red: 0.40, green: 0.80, blue: 0.55),
        title: "Select a Piece",
        body: "Tap any white piece on the board to select it. The piece highlights and blue dots appear on every square it can legally move to.",
        voiceText: "To move a piece, start by tapping it. Your selected piece will glow, and blue dots will appear on all the squares it can move to.",
        hint: "Only your white pieces can be selected."
    ),
    OnboardingStep(
        icon: "dot.circle.fill",
        iconColor: Color(red: 0.25, green: 0.60, blue: 1.0),
        title: "Move to a Square",
        body: "After selecting a piece, tap any blue dot to move there. For captures, a blue ring highlights the enemy piece — tap it to take it.",
        voiceText: "After selecting a piece, tap one of the blue dots to move your piece there. A blue ring means you can capture that enemy piece.",
        hint: "Tap any other piece to change your selection."
    ),
    OnboardingStep(
        icon: "mic.fill",
        iconColor: Color(red: 0.52, green: 0.73, blue: 0.88),
        title: "Play by Voice",
        body: "Tap the Voice button and speak a move:\n\n• \"e4\" — move a pawn to e4\n• \"knight c3\" — move a knight\n• \"e2 to e4\" — exact from → to\n• \"castle\" — kingside castling",
        voiceText: "You can also play completely by voice! Tap the microphone button and say something like 'e four', 'knight c three', or 'e two to e four'.",
        hint: "Works best with clear pronunciation."
    ),
    OnboardingStep(
        icon: "sparkles",
        iconColor: Color(red: 0.90, green: 0.70, blue: 0.30),
        title: "You're All Set!",
        body: "The AI plays as black and responds automatically after each of your moves. Good luck — and enjoy the game!",
        voiceText: "That's everything you need to know! The AI will play as black and respond after each of your moves. Good luck, and enjoy MOVES!",
        hint: "Review commands anytime in About MOVES."
    )
]

// ── Speaker wrapper ───────────────────────────────────────────────────────────

final class OnboardingSpeaker: ObservableObject, @unchecked Sendable {
    private let synth = AVSpeechSynthesizer()

    func speak(_ text: String) {
        synth.stopSpeaking(at: .immediate)
        let utt = AVSpeechUtterance(string: text)
        utt.voice = AVSpeechSynthesisVoice(language: "en-US")
        utt.rate  = 0.46
        utt.pitchMultiplier = 1.05
        synth.speak(utt)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
    }
}

// ── Main view ────────────────────────────────────────────────────────────────

struct OnboardingView: View {
    @Binding var isPresented: Bool

    @StateObject private var speaker = OnboardingSpeaker()
    @State private var currentStep   = 0
    @State private var animateDot    = false

    private let steps = onboardingSteps

    // Fixed heights so buttons never shift position
    private let dotRowH:    CGFloat = 52
    private let iconH:      CGFloat = 100  // circle + bottom padding
    private let titleH:     CGFloat = 52   // text + bottom padding
    private let bodyAreaH:  CGFloat = 200  // body + hint — the only variable part, fixed
    private let dividerH:   CGFloat = 1
    private let buttonRowH: CGFloat = 72

    var body: some View {
        ZStack {
            Color.black.opacity(0.82)
                .ignoresSafeArea()
                .onTapGesture { }

            // Center the card
            VStack {
                Spacer()

                // ── Card ─────────────────────────────────────────────────────
                VStack(spacing: 0) {

                    // 1. Step progress dots — fixed height
                    HStack(spacing: 7) {
                        ForEach(0..<steps.count, id: \.self) { i in
                            Capsule()
                                .fill(i == currentStep
                                      ? steps[currentStep].iconColor
                                      : Color.white.opacity(0.2))
                                .frame(width: i == currentStep ? 22 : 7, height: 7)
                                .animation(.easeInOut(duration: 0.25), value: currentStep)
                        }
                    }
                    .frame(height: dotRowH, alignment: .bottom)
                    .padding(.bottom, 4)

                    // 2. Icon — fixed height
                    ZStack {
                        Circle()
                            .fill(steps[currentStep].iconColor.opacity(0.18))
                            .frame(width: 64, height: 64)

                        Circle()
                            .stroke(steps[currentStep].iconColor.opacity(animateDot ? 0 : 0.4),
                                    lineWidth: 2)
                            .frame(width: 64 + (animateDot ? 20 : 0),
                                   height: 64 + (animateDot ? 20 : 0))
                            .animation(
                                .easeOut(duration: 1.4).repeatForever(autoreverses: false),
                                value: animateDot
                            )

                        Image(systemName: steps[currentStep].icon)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(steps[currentStep].iconColor)
                    }
                    .frame(height: iconH, alignment: .center)

                    // 3. Title — fixed height
                    Text(steps[currentStep].title)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 24)
                        .frame(height: titleH, alignment: .center)

                    // 4. Body + Hint — FIXED height, this is what was jumping
                    VStack(alignment: .center, spacing: 0) {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 12) {
                                Text(steps[currentStep].body)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.white.opacity(0.78))
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(3)
                                    .padding(.horizontal, 28)
                                    .frame(maxWidth: .infinity)

                                // Hint chip
                                Text(steps[currentStep].hint)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(steps[currentStep].iconColor.opacity(0.85))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
                                    .background(steps[currentStep].iconColor.opacity(0.12))
                                    .cornerRadius(9)
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                        }
                    }
                    .frame(height: bodyAreaH)  // ← FIXED: buttons will never move

                    // 5. Divider — always at the same Y
                    Divider()
                        .background(Color.white.opacity(0.1))
                        .frame(height: dividerH)

                    // 6. Buttons — always at bottom, never shift
                    HStack(spacing: 10) {
                        // Skip
                        Button { finish() } label: {
                            Text("Skip")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.35))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }

                        Spacer()

                        // Back
                        if currentStep > 0 {
                            Button {
                                withAnimation(.easeInOut(duration: 0.22)) { currentStep -= 1 }
                                speaker.speak(steps[currentStep].voiceText)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("Back")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 11)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(11)
                            }
                        } else {
                            // Invisible placeholder so Next doesn't shift right on step 0
                            Color.clear
                                .frame(width: 72, height: 42)
                        }

                        // Next / Let's Play
                        Button {
                            if currentStep < steps.count - 1 {
                                withAnimation(.easeInOut(duration: 0.22)) { currentStep += 1 }
                                speaker.speak(steps[currentStep].voiceText)
                            } else {
                                finish()
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Text(currentStep < steps.count - 1 ? "Next" : "Let's Play!")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                if currentStep < steps.count - 1 {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .bold))
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 11)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.30, green: 0.42, blue: 0.58),
                                             steps[currentStep].iconColor],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .cornerRadius(11)
                            .shadow(color: steps[currentStep].iconColor.opacity(0.35),
                                    radius: 8, y: 3)
                        }
                    }
                    .padding(.horizontal, 18)
                    .frame(height: buttonRowH, alignment: .center)
                }
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color(red: 0.09, green: 0.11, blue: 0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(steps[currentStep].iconColor.opacity(0.22), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.65), radius: 36, y: 10)
                .padding(.horizontal, 22)

                Spacer()
            }
        }
        .onAppear {
            animateDot = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                speaker.speak(steps[0].voiceText)
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
