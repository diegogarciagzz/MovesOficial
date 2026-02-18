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
        print("🔐 Requesting speech permission...")
        
        SFSpeechRecognizer.requestAuthorization { status in
            let speechGranted = (status == .authorized)
            print("Speech: \(speechGranted ? "✅" : "❌")")
            
            print("🎤 Requesting microphone permission...")
            AVAudioSession.sharedInstance().requestRecordPermission { micGranted in
                print("Microphone: \(micGranted ? "✅" : "❌")")
                
                DispatchQueue.main.async {
                    completion(speechGranted, micGranted)
                }
            }
        }
    }
    
    func checkPermissions() -> (speech: Bool, mic: Bool) {
        let speech = (SFSpeechRecognizer.authorizationStatus() == .authorized)
        let mic = (AVAudioSession.sharedInstance().recordPermission == .granted)
        return (speech, mic)
    }
}
