//
//  Haptics.swift
//  AIPrompts
//
//  Created by Lulin Yang on 2025/7/18.
//

import UIKit
import Sharing

struct Haptics {
    @Shared(.appStorage("vibrateEnabled")) var vibrateEnabled: Bool
     = true
    static let shared = Haptics()
    func vibrateIfEnabled() {
        print("Vibration setting is \(vibrateEnabled ? "ON" : "OFF")") // debug
        if vibrateEnabled {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
        }
    }
}
