//
// Created by Banghua Zhao on 27/10/2026
// Copyright Apps Bay Limited. All rights reserved.
//

import AppIntents
import SwiftUI
import UIKit
import WidgetKit

/// The Copy button on a widget: puts a prompt on the clipboard without opening the app.
///
/// Runs in the widget extension and finds the text in the snapshot the app wrote, so it works
/// even when the app isn't running.
struct CopyWidgetPromptIntent: AppIntent {
    static var title: LocalizedStringResource = "Copy Prompt"
    /// Only for widget buttons; Shortcuts already has the app's own Copy Prompt action.
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Prompt")
    var itemID: String

    init() {}

    init(itemID: String) {
        self.itemID = itemID
    }

    func perform() async throws -> some IntentResult {
        guard let snapshot = WidgetShared.loadSnapshot(),
              let item = (snapshot.favorites + snapshot.daily).first(where: { $0.id == itemID })
        else { return .result() }
        let text = item.copyText
        await MainActor.run {
            UIPasteboard.general.string = text
        }
        // The widgets reload after this returns and show a checkmark for a moment.
        WidgetShared.noteCopied(itemID: item.id)
        return .result()
    }
}

/// A small round Copy button for widgets, showing a checkmark right after it's used.
struct WidgetCopyButton: View {
    let itemID: String
    let isCopied: Bool

    var body: some View {
        Button(intent: CopyWidgetPromptIntent(itemID: itemID)) {
            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.purple)
                .frame(width: 30, height: 30)
                .background(Color.purple.opacity(0.14), in: Circle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCopied ? Text("Copied") : Text("Copy prompt"))
    }
}
