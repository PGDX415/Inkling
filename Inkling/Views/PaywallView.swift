import SwiftUI
import StoreKit

/// In-app purchase paywall for Inkling Pro subscription
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreManager.self) private var store

    @State private var selectedPeriod: Period = .yearly
    @State private var isPurchasing = false

    private enum Period { case monthly, yearly }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header
                headerSection

                // Feature list
                featuresSection

                // Pricing cards
                pricingSection

                // Trial info
                trialInfo

                // Purchase button
                purchaseButton

                // Links
                footerLinks

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 24)
        }
        .background(Color(.systemGroupedBackground))
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .padding(16)
            }
        }
        .task {
            await store.loadProducts()
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.brown)
                .padding(.top, 40)

            Text("store.pro_title")
                .font(.title)
                .fontWeight(.bold)

            Text("store.pro_subtitle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Features
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            featureRow(icon: "sparkles", title: "store.feature_ai_title", desc: "store.feature_ai_desc")
            featureRow(icon: "textformat", title: "store.feature_font_title", desc: "store.feature_font_desc")
            featureRow(icon: "photo.on.rectangle.angled", title: "store.feature_photo_title", desc: "store.feature_photo_desc")
            featureRow(icon: "icloud", title: "store.feature_sync_title", desc: "store.feature_sync_desc")
            featureRow(icon: "lock.doc", title: "store.feature_lock_title", desc: "store.feature_lock_desc")
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }

    private func featureRow(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.brown)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(LocalizedStringKey(desc))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Pricing
    private var pricingSection: some View {
        VStack(spacing: 12) {
            // Period toggle
            HStack(spacing: 0) {
                periodButton(.monthly)
                periodButton(.yearly)
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemBackground))
            )

            // Price display
            if store.isLoading {
                ProgressView()
                    .padding()
            } else if let product = selectedProduct {
                let price = store.formattedPrice(for: product)
                VStack(spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(price.price)
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(.primary)
                        Text("/\(price.period)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if selectedPeriod == .yearly, let savings = store.annualSavingsText {
                        Text(savings)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.green.opacity(0.1))
                            )
                    }
                }
            } else if let error = store.purchaseError {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button(String(localized: "common.retry")) {
                        Task { await store.loadProducts() }
                    }
                    .font(.caption)
                    .tint(.brown)
                }
                .padding()
            } else {
                ProgressView()
                    .padding()
            }
        }
    }

    private func periodButton(_ period: Period) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedPeriod = period }
        } label: {
            Text(period == .monthly
                 ? String(localized: "store.period_monthly")
                 : String(localized: "store.period_yearly"))
                .font(.subheadline)
                .fontWeight(selectedPeriod == period ? .semibold : .regular)
                .foregroundStyle(selectedPeriod == period ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(selectedPeriod == period ? Color.brown : Color.clear)
                )
        }
    }

    private var selectedProduct: Product? {
        switch selectedPeriod {
        case .monthly: return store.monthlyProduct
        case .yearly:  return store.yearlyProduct
        }
    }

    // MARK: - Trial
    private var trialInfo: some View {
        HStack(spacing: 6) {
            Image(systemName: "gift")
                .font(.caption)
                .foregroundStyle(.brown)
            Text("store.trial_info")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Purchase
    private var purchaseButton: some View {
        VStack(spacing: 8) {
            Button {
                guard let product = selectedProduct else { return }
                isPurchasing = true
                Task {
                    await store.purchase(product)
                    isPurchasing = false
                    if store.isPro { dismiss() }
                }
            } label: {
                HStack {
                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("store.subscribe_button")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.brown)
            .disabled(isPurchasing || selectedProduct == nil)

            if let error = store.purchaseError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Footer
    private var footerLinks: some View {
        VStack(spacing: 12) {
            Button(String(localized: "store.restore")) {
                Task { await store.restorePurchases() }
            }
            .font(.subheadline)
            .tint(.brown)

            HStack(spacing: 4) {
                Text("store.terms_prefix")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Link(String(localized: "store.terms"), destination: URL(string: "https://pgdx415.github.io/Inkling/terms")!)
                    .font(.caption2)
                Text("·")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Link(String(localized: "store.privacy"), destination: URL(string: "https://pgdx415.github.io/Inkling/privacy")!)
                    .font(.caption2)
            }
        }
    }
}

#Preview {
    PaywallView()
        .environment(StoreManager.shared)
}
