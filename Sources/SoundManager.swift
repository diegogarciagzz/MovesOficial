//
//  SoundManager.swift
//  MovesDiego
//
//  Created by Mariana G on 05/02/26.
//


import AVFoundation

class SoundManager: @unchecked Sendable {
    static let shared = SoundManager()
    var audioPlayer: AVAudioPlayer?
    
    private init() {}
    
    enum SoundType {
        case move, capture, check, checkmate
    }
    
    nonisolated func playSound(_ type: SoundType) {
        let systemSound: SystemSoundID
        switch type {
        case .move:
            systemSound = 1103 // Pop
        case .capture:
            systemSound = 1104 // Peek
        case .check:
            systemSound = 1106 // Alert
        case .checkmate:
            systemSound = 1107 // Fanfare
        }
        AudioServicesPlaySystemSound(systemSound)
    }
}
