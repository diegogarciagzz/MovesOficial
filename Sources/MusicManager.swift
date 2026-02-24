//
//  MusicManager.swift
//  MovesDiego
//
//  Procedural ambient music using AVAudioEngine.
//  Generates soft pad chords for a chess atmosphere — no audio files needed.
//

import AVFoundation
import Combine

class MusicManager: ObservableObject {
    static let shared = MusicManager()

    @Published var isPlaying = false
    @Published var volume: Float = 0.18  // subtle by default

    private var engine = AVAudioEngine()
    private var mixerNode = AVAudioMixerNode()
    private var oscillators: [AVAudioSourceNode] = []
    private var fadeTimer: Timer?

    // Chord frequencies — calm minor chords that evoke a classic chess atmosphere
    private let chords: [[Float]] = [
        [146.83, 174.61, 220.00],   // D minor  (D3, F3, A3)
        [130.81, 164.81, 196.00],   // C major  (C3, E3, G3)
        [110.00, 130.81, 164.81],   // A minor  (A2, C3, E3)
        [123.47, 155.56, 185.00],   // B dim-ish (B2, Eb3, Gb3)
    ]

    private var currentChordIndex = 0
    private var targetAmplitude: Float = 0
    private var currentAmplitude: Float = 0

    private init() {
        configureAudioSession()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    func toggle() {
        if isPlaying {
            stop()
        } else {
            start()
        }
    }

    func start() {
        guard !isPlaying else { return }
        configureAudioSession()
        buildGraph()
        do {
            try engine.start()
            isPlaying = true
            fadeIn()
            scheduleChordRotation()
        } catch {
            print("MusicManager: engine failed to start — \(error)")
        }
    }

    func stop() {
        guard isPlaying else { return }
        fadeTimer?.invalidate()
        fadeTimer = nil
        fadeOut { [weak self] in
            self?.engine.stop()
            self?.tearDownOscillators()
            self?.isPlaying = false
        }
    }

    // MARK: - Audio graph

    private func buildGraph() {
        engine = AVAudioEngine()
        mixerNode = AVAudioMixerNode()
        engine.attach(mixerNode)

        let mainMixer = engine.mainMixerNode
        let format = mainMixer.outputFormat(forBus: 0)

        engine.connect(mixerNode, to: mainMixer, format: format)
        mixerNode.outputVolume = 0  // start silent, fade in

        addChord(chords[currentChordIndex], format: format)
    }

    private func addChord(_ frequencies: [Float], format: AVAudioFormat) {
        tearDownOscillators()

        let sampleRate = Float(format.sampleRate)
        let amp = volume / Float(frequencies.count)

        for freq in frequencies {
            var phase: Float = 0
            let phaseIncrement = (2.0 * Float.pi * freq) / sampleRate

            let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList in
                guard let self = self else { return noErr }
                let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
                let currentAmp = amp * (self.currentAmplitude)

                for frame in 0..<Int(frameCount) {
                    // Soft sine with slight warmth (add a touch of 2nd harmonic)
                    let sine = sin(phase)
                    let warm = sin(phase * 2) * 0.15
                    let value = (sine + warm) * currentAmp

                    phase += phaseIncrement
                    if phase >= 2.0 * Float.pi { phase -= 2.0 * Float.pi }

                    for buffer in ablPointer {
                        let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                        buf?[frame] = (buf?[frame] ?? 0) + value
                    }
                }
                return noErr
            }

            engine.attach(node)
            engine.connect(node, to: mixerNode, format: format)
            oscillators.append(node)
        }
    }

    private func tearDownOscillators() {
        for node in oscillators {
            engine.disconnectNodeOutput(node)
            engine.detach(node)
        }
        oscillators.removeAll()
    }

    // MARK: - Fades

    private func fadeIn() {
        currentAmplitude = 0
        targetAmplitude = 1.0
        animateAmplitude(duration: 2.0)
    }

    private func fadeOut(completion: @escaping () -> Void) {
        targetAmplitude = 0
        animateAmplitude(duration: 1.5, completion: completion)
    }

    private func animateAmplitude(duration: TimeInterval, completion: (() -> Void)? = nil) {
        let steps = 30
        let interval = duration / Double(steps)
        let delta = (targetAmplitude - currentAmplitude) / Float(steps)
        var step = 0

        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            step += 1
            self.currentAmplitude += delta
            self.mixerNode.outputVolume = max(0, self.currentAmplitude)

            if step >= steps {
                timer.invalidate()
                self.currentAmplitude = self.targetAmplitude
                self.mixerNode.outputVolume = max(0, self.currentAmplitude)
                completion?()
            }
        }
    }

    // MARK: - Chord rotation (slow, ambient feel)

    private func scheduleChordRotation() {
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isPlaying else { return }
            self.currentChordIndex = (self.currentChordIndex + 1) % self.chords.count

            // Cross-fade: briefly reduce amplitude, swap chord, bring back
            let savedAmp = self.currentAmplitude
            self.targetAmplitude = 0.15
            self.animateAmplitude(duration: 1.0) {
                let format = self.engine.mainMixerNode.outputFormat(forBus: 0)
                self.addChord(self.chords[self.currentChordIndex], format: format)
                self.targetAmplitude = savedAmp
                self.animateAmplitude(duration: 1.5)
            }
        }
    }
}
