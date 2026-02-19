//
//  PermissionsManager.swift
//  MovesDiego
//

import Foundation
import Speech
import AVFoundation

final class PermissionsManager: @unchecked Sendable {

    static let shared = PermissionsManager()

    private init() {}

    func requestPermissions(completion: @escaping @Sendable (Bool, Bool) -> Void) {
        print("Requesting speech permission...")

        SFSpeechRecognizer.requestAuthorization { status in
            let speechGranted = (status == .authorized)
            print("Speech: \(speechGranted ? "granted" : "denied")")

            print("Requesting microphone permission...")
            // iOS 17+ async API (same as friend's code)
            Task {
                let micGranted = await AVAudioApplication.requestRecordPermission()
                print("Microphone: \(micGranted ? "granted" : "denied")")

                await MainActor.run {
                    completion(speechGranted, micGranted)
                }
            }
        }
    }

    func checkPermissions() -> (speech: Bool, mic: Bool) {
        let speech = (SFSpeechRecognizer.authorizationStatus() == .authorized)
        // iOS 17+ API (same as friend's code)
        let mic = (AVAudioApplication.shared.recordPermission == .granted)
        return (speech, mic)
    }
}
