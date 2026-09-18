import SwiftUI

struct ProPaywallView: View {
    @Environment(PurchaseManager.self) private var purchaseManager
    @Environment(\.dismiss) private var dismiss

    private let benefits: [(icon: String, title: String, detail: String)] = [
        ("person.2.fill", "Unlimited People",
         "Free includes \(freePersonLimit) person. With Pro you track as many friends and family as you like."),
        ("mappin.and.ellipse", "Unlimited Places",
         "Free includes \(freeLocationLimit) places. With Pro you save as many as you want."),
        ("bell.badge.fill", "Early Access to New Features",
         "New features arrive in Pro first."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 10) {
                        Image(systemName: "location.north.circle.fill")
                            .font(.system(size: 56))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.accentColor.gradient)
                        Text("Compass To Pro")
                            .font(.largeTitle.bold())
                        Text("Keep an eye on every place and person — without limits.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(benefits, id: \.title) { benefit in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: benefit.icon)
                                    .font(.title3)
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(benefit.title).font(.subheadline.bold())
                                    Text(benefit.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(.horizontal)

                    VStack(spacing: 8) {
                        Text("Made by a student")
                            .font(.footnote.bold())
                        Text("I develop Compass To on my own, alongside my studies. With Pro you directly support further development — and if you have questions, I answer personally.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                }
                .padding(.bottom, 120)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    if purchaseManager.isPro {
                        Label("Pro is active — thank you for your support!", systemImage: "checkmark.seal.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            Task {
                                await purchaseManager.purchase()
                                if purchaseManager.isPro { dismiss() }
                            }
                        } label: {
                            HStack {
                                if purchaseManager.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(unlockButtonTitle)
                                        .font(.headline)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(purchaseManager.isLoading || purchaseManager.product == nil)

                        Button("Restore Purchases") {
                            Task {
                                await purchaseManager.restorePurchases()
                                if purchaseManager.isPro { dismiss() }
                            }
                        }
                        .font(.caption)
                        .disabled(purchaseManager.isLoading)

                        if let errorMessage = purchaseManager.errorMessage {
                            Text(errorMessage)
                                .font(.caption2)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding()
                .background(.bar)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                if purchaseManager.product == nil {
                    await purchaseManager.loadProduct()
                }
            }
        }
    }

    private var unlockButtonTitle: String {
        if let price = purchaseManager.product?.displayPrice {
            return "Unlock for \(price)"
        }
        return "Unlock Now"
    }
}
