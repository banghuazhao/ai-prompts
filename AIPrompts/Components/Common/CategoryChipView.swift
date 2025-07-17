import SwiftUI

struct CategoryChipView: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    HStack {
        CategoryChipView(title: "All", isSelected: true) {}
        CategoryChipView(title: "Development", isSelected: false) {}
        CategoryChipView(title: "Creative", isSelected: false) {}
    }
    .padding()
} 