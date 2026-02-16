//
//  PermissionsManager.swift
//  MovesDiego
//
//  Created on 15/02/26.
//

import Foundation
import Speech
import AVFoundation

@MainActor
class PermissionsManager: ObservableObject {
    @Published var speechAuthorized = false
    @Published var microphoneAuthorized = false
    @Published var isRequestingPermissions = false
    
    func requestAllPermissions() async {
        isRequestingPermissions = true
        print("🔐 Requesting all permissions on app launch...")
        
        // Request Speech Recognition first
        await requestSpeechPermission()
        
        // Then request Microphone
        await requestMicrophonePermission()
        
        isRequestingPermissions = false
        print("✅ All permissions requested")
    }
    
    private func requestSpeechPermission() async {
        print("🎤 Requesting Speech Recognition permission...")
        
        let authStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        await MainActor.run {
            switch authStatus {
            case .authorized:
                self.speechAuthorized = true
                print("✅ Speech Recognition authorized")
            case .denied:
                self.speechAuthorized = false
                print("❌ Speech Recognition denied")
            case .restricted:
                self.speechAuthorized = false
                print("❌ Speech Recognition restricted")
            case .notDetermined:
                self.speechAuthorized = false
                print("⏳ Speech Recognition not determined")
            @unknown default:
                self.speechAuthorized = false
                print("❓ Speech Recognition unknown")
            }
        }
    }
    
    private func requestMicrophonePermission() async {
        print("🎤 Requesting Microphone permission...")
        
        let granted = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        
        await MainActor.run {
            self.microphoneAuthorized = granted
            if granted {
                print("✅ Microphone permission granted")
            } else {
                print("❌ Microphone permission denied")
            }
        }
    }
}
