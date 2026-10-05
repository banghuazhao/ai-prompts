//
// Created by Banghua Zhao on 17/07/2025
// Copyright Apps Bay Limited. All rights reserved.
//
  

import SwiftUI

struct BadgeView: View {
    let icon: String?
    let text: String
    var body: some View {
        HStack(spacing: 5) {
            if let icon = icon {
                Image(systemName: icon)
            }
            Text(Bundle.main.localizedString(forKey: text, value: text, table: nil))
        }
        .font(.caption.weight(.semibold))
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(AIStudioPalette.violet)
        .background(AIStudioPalette.violet.opacity(0.10), in: Capsule())
    }
}
