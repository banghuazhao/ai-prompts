//
// Created by Banghua Zhao on 17/07/2025
// Copyright Apps Bay Limited. All rights reserved.
//
  

import SwiftUI

struct BadgeView: View {
    let icon: String?
    let text: String
    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
            }
            Text(text)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray5))
        .foregroundColor(.primary)
        .cornerRadius(8)
    }
}
