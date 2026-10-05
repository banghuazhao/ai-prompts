//
// Created by Banghua Zhao on 05/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI

/// A small "fill this in for me" action backed by the on-device model, with its loading and error states.
struct AISuggestButton: View {
    let title: LocalizedStringKey
    let isLoading: Bool
    let failure: OnDeviceAIFailure?
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                Haptics.shared.vibrateIfEnabled()
                action()
            } label: {
                HStack(spacing: 6) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(title)
                }
                .font(.subheadline)
            }
            .glassButtonStyle()
            .tint(.purple)
            .disabled(isLoading)

            if let failure {
                Text(failure.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
