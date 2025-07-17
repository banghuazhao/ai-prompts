import SwiftUI

struct CategoryCardView: View {
    let title: String
    let count: Int
    let systemImage: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 30))
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("\(count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    LazyVGrid(columns: [
        GridItem(.flexible()),
        GridItem(.flexible())
    ], spacing: 16) {
        CategoryCardView(title: "Development", count: 15, systemImage: "laptopcomputer") {}
        CategoryCardView(title: "Creative", count: 8, systemImage: "paintbrush") {}
        CategoryCardView(title: "Education", count: 12, systemImage: "book") {}
        CategoryCardView(title: "Business", count: 6, systemImage: "briefcase") {}
    }
    .padding()
} 