//
//  BoardTheme.swift
//  MovesDiego
//
//  Board color themes for the chess board.
//

import SwiftUI

enum BoardTheme: String, CaseIterable, Identifiable {
    case classic
    case wood
    case navy
    case midnight
    case coral

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic:  return "Classic"
        case .wood:     return "Wood"
        case .navy:     return "Navy"
        case .midnight: return "Midnight"
        case .coral:    return "Coral"
        }
    }

    var icon: String {
        switch self {
        case .classic:  return "leaf.fill"
        case .wood:     return "tree.fill"
        case .navy:     return "water.waves"
        case .midnight: return "moon.stars.fill"
        case .coral:    return "flame.fill"
        }
    }

    var lightSquare: Color {
        switch self {
        case .classic:  return Color(red: 0.93, green: 0.91, blue: 0.83)
        case .wood:     return Color(red: 0.87, green: 0.76, blue: 0.60)
        case .navy:     return Color(red: 0.82, green: 0.85, blue: 0.90)
        case .midnight: return Color(red: 0.72, green: 0.70, blue: 0.80)
        case .coral:    return Color(red: 0.95, green: 0.88, blue: 0.85)
        }
    }

    var darkSquare: Color {
        switch self {
        case .classic:  return Color(red: 0.47, green: 0.58, blue: 0.34)
        case .wood:     return Color(red: 0.55, green: 0.37, blue: 0.22)
        case .navy:     return Color(red: 0.22, green: 0.33, blue: 0.52)
        case .midnight: return Color(red: 0.30, green: 0.24, blue: 0.42)
        case .coral:    return Color(red: 0.75, green: 0.38, blue: 0.35)
        }
    }

    var selectedLight: Color {
        switch self {
        case .classic:  return Color(red: 1.0, green: 0.85, blue: 0.35)
        case .wood:     return Color(red: 1.0, green: 0.82, blue: 0.40)
        case .navy:     return Color(red: 0.55, green: 0.75, blue: 1.0)
        case .midnight: return Color(red: 0.70, green: 0.55, blue: 1.0)
        case .coral:    return Color(red: 1.0, green: 0.80, blue: 0.45)
        }
    }

    var selectedDark: Color {
        switch self {
        case .classic:  return Color(red: 0.75, green: 0.65, blue: 0.20)
        case .wood:     return Color(red: 0.78, green: 0.60, blue: 0.25)
        case .navy:     return Color(red: 0.35, green: 0.50, blue: 0.80)
        case .midnight: return Color(red: 0.50, green: 0.35, blue: 0.75)
        case .coral:    return Color(red: 0.80, green: 0.55, blue: 0.25)
        }
    }

    var accent: Color {
        switch self {
        case .classic:  return Color(red: 0.47, green: 0.58, blue: 0.34)
        case .wood:     return Color(red: 0.65, green: 0.45, blue: 0.28)
        case .navy:     return Color(red: 0.35, green: 0.50, blue: 0.75)
        case .midnight: return Color(red: 0.55, green: 0.40, blue: 0.75)
        case .coral:    return Color(red: 0.85, green: 0.45, blue: 0.40)
        }
    }

    // Persist selection
    static var saved: BoardTheme {
        let raw = UserDefaults.standard.string(forKey: "boardTheme") ?? "classic"
        return BoardTheme(rawValue: raw) ?? .classic
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: "boardTheme")
    }
}
