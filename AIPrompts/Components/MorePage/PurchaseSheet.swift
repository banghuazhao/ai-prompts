//
//  PurchaseSheet.swift
//  TimesMatter
//
//  Created by Lulin Yang on 2025/7/12.
//

import SwiftUI
import Dependencies

struct PurchaseSheet: View {
    @Dependency(\.purchaseManager) var purchaseManager
    @Dependency(\.themeManager) var themeManager
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false
    @State private var showSuccessModal = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(.systemYellow).opacity(0.08).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    // Close button
                    HStack {
                        Button(action: { 
                            Haptics.shared.vibrateIfEnabled()
                            dismiss() 
                        }) {
                            Image(systemName: "xmark")
                        
                        }
                        .buttonStyle(.appCircular)
                        Spacer()
                    }
                    .padding(.top, 12)
                    .padding(.leading, 12)

                    // Top image
                    ZStack {
                        LinearGradient(
                            gradient: Gradient(colors: [Color.pink, Color.orange, Color.yellow, Color.purple, Color.green]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(width: 90, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 18))

                        Image(systemName: "bell.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .foregroundColor(Color(red: 1.0, green: 0.92, blue: 0.88)) // Cuter pastel peach
                            .shadow(radius: 6)
                       
                    }
                    .frame(width: 90, height: 90)
                    
                    // Title & description
                    Text("Enjoy an ad-free experience with Premium!")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            Text("• ").font(.title3).fontWeight(.semibold)
                            Text("No Ads: ")
                                .fontWeight(.semibold) + Text("Say goodbye to ads and hello to smoother event tracking.")
                        }
                        //HStack(alignment: .top) {
                        //    Text("• ").font(.title3).fontWeight(.bold)
                        //    Text("Unlimited Habits: ")
                        //        .fontWeight(.semibold) + Text("Create and track as many healthy habits as you want—no limits.")
                        //}
                    }
                    .font(.body)
                    .padding(.horizontal)

                    // Purchase button
                    if let product = purchaseManager.premiumProduct {
                        if purchaseManager.isPremiumUserPurchased {
                            Text("You are now Premium user!")
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .padding(.bottom, 12)
                        } else {
                            Button(action: {
                                Haptics.shared.vibrateIfEnabled()
                                Task {
                                    isPurchasing = true
                                    let result = await purchaseManager.purchasePremium()
                                    switch result {
                                    case .success:
                                        showSuccessModal = true
                                    case .failure(let error):
                                        print("Purchase failed: \(error.localizedDescription)")
                                    }
                                    isPurchasing = false
                                }
                            }) {
                                HStack {
                                    if isPurchasing {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    }
                                    Text("\(product.displayPrice) - Upgrade to Premium")
                                        .font(.subheadline)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 20)
                                .background(themeManager.current.primaryColor)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                            }
                            .padding(.horizontal)
                            .disabled(isPurchasing)
                        }
                    } else {
                        ProgressView()
                        Text("Loading product...")
                                    .foregroundColor(.gray)
                                    .padding(.top, 4)
                    }
                    // Links
                    VStack(spacing: 16) {
                        Button("Restore Purchases") {
                            Haptics.shared.vibrateIfEnabled()
                            Task {
                                isPurchasing = true
                                await purchaseManager.restorePurchases()
                                isPurchasing = false
                            }
                        }
                        .foregroundColor(themeManager.current.primaryColor)
                        
                        Button("Contact Support") {
                            Haptics.shared.vibrateIfEnabled()
                            if let url = URL(string: "https://apps-bay.github.io/Apps-Bay-Website/contact/") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .foregroundColor(themeManager.current.primaryColor)
                        
                        Button("Privacy Policy") {
                            Haptics.shared.vibrateIfEnabled()
                            if let url = URL(string: "https://apps-bay.github.io/Apps-Bay-Website/privacy/") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .foregroundColor(themeManager.current.primaryColor)
                    }
                    .font(.body)
                    .padding(.bottom, 24)
                }
            }
        }
        .sheet(isPresented: $showSuccessModal) {
            PremiumSuccessView()
        }
        .task {
            await purchaseManager.loadPremiumProduct()
        }
        .onAppear {
            isPurchasing = false
        }
    }
}

struct ConfettiDot: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let color: Color
    let size: CGFloat
}



struct PremiumSuccessView: View {
    var onContinue: (() -> Void)? = nil
    @State private var animate = false
    @Environment(\.dismiss) var dismiss

    private let confetti: [ConfettiDot] = (0..<20).map { _ in
        ConfettiDot(
            x: CGFloat.random(in: 40...340),
            y: CGFloat.random(in: 40...600),
            color: [Color.pink.opacity(0.7), Color.mint, Color.indigo, Color.teal, Color.orange.opacity(0.7)].randomElement()!,
            size: CGFloat.random(in: 8...14)
        )
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.white, Color.pink.opacity(0.1)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Confetti
            ForEach(confetti) { dot in
                Circle()
                    .fill(dot.color)
                    .frame(width: dot.size, height: dot.size)
                    .position(x: dot.x, y: animate ? dot.y : dot.y - 80)
                    .opacity(0.6)
                    .animation(.easeOut(duration: 1.2), value: animate)
            }

            VStack(spacing: 26) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.2)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 110, height: 110)
                        .blur(radius: 6)
                    Image(systemName: "sparkles")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 70, height: 70)
                        .foregroundColor(.indigo)
                        .shadow(color: .indigo.opacity(0.3), radius: 10)
                }

                Text("You're All Set!")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.primary)

                Text("✨ Thanks for unlocking the full experience.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        Text("Ad-free experience")
                    }
                    HStack {
                        Image(systemName: "heart.fill").foregroundColor(.pink)
                        Text("Support for future updates")
                    }
                }
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    if let action = onContinue {
                        action()
                    } else {
                        dismiss()
                    }
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 44)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.teal, Color.indigo]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(18)
                        .shadow(radius: 4)
                }
            }
            .padding(36)
            .background(
                RoundedRectangle(cornerRadius: 26)
                    .fill(Color.white.opacity(0.95))
            )
            .shadow(radius: 20)
            .padding(.horizontal, 24)
            .onAppear { animate = true }
        }
    }
}


#Preview {
    PurchaseSheet()
}
