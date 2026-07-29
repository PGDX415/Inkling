import StoreKit
import SwiftUI

/// Manages in-app purchases and Pro entitlement via StoreKit 2
@Observable
final class StoreManager {
    static let shared = StoreManager()

    // MARK: - Product IDs (must match App Store Connect)
    private let monthlyID = "com.gongdexin.paul.Inkling.pro.monthly"
    private let yearlyID  = "com.gongdexin.paul.Inkling.pro.yearly"

    // MARK: - Published state
    private(set) var monthlyProduct: Product?
    private(set) var yearlyProduct: Product?
    private(set) var isPro = false
    private(set) var purchaseError: String?
    private(set) var isLoading = false
    private(set) var didLoadProducts = false

    private var entitlementTask: Task<Void, Never>?
    private var updatesTask: Task<Void, Never>?

    private init() {
        entitlementTask = Task { await checkEntitlement() }
        updatesTask = Task { await listenForTransactions() }
    }

    deinit {
        entitlementTask?.cancel()
        updatesTask?.cancel()
    }

    // MARK: - Load Products
    func loadProducts() async {
        isLoading = true
        defer {
            isLoading = false
            didLoadProducts = true
        }

        do {
            let products = try await Product.products(for: [monthlyID, yearlyID])
            for product in products {
                switch product.id {
                case monthlyID: monthlyProduct = product
                case yearlyID:  yearlyProduct = product
                default: break
                }
            }
            if products.isEmpty && purchaseError == nil {
                purchaseError = String(localized: "store.products_not_found")
            }
        } catch {
            purchaseError = error.localizedDescription
            print("[StoreManager] Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase
    func purchase(_ product: Product) async {
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await checkEntitlement()
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
            print("[StoreManager] Purchase failed: \(error)")
        }
    }

    // MARK: - Restore Purchases
    func restorePurchases() async {
        purchaseError = nil
        do {
            try await AppStore.sync()
            await checkEntitlement()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Entitlement Check
    private func checkEntitlement() async {
        var entitled = false
        for await verification in StoreKit.Transaction.currentEntitlements {
            if let transaction = try? checkVerified(verification),
               [monthlyID, yearlyID].contains(transaction.productID),
               transaction.revocationDate == nil {
                entitled = true
            }
        }
        isPro = entitled
    }

    // MARK: - Transaction Listener
    private func listenForTransactions() async {
        for await verification in StoreKit.Transaction.updates {
            if let transaction = try? checkVerified(verification) {
                await transaction.finish()
                await checkEntitlement()
            }
        }
    }

    // MARK: - Subscription Info
    var subscriptionStatusText: String {
        get async {
            guard let latest = await getLatestTransaction(),
                  let expiry = latest.expirationDate else { return "" }
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            let date = formatter.string(from: expiry)
            return String(format: String(localized: "store.renews_on"), date)
        }
    }

    private func getLatestTransaction() async -> StoreKit.Transaction? {
        var latest: StoreKit.Transaction?
        for await verification in StoreKit.Transaction.currentEntitlements {
            let txn = try? checkVerified(verification)
            if let txn, txn.revocationDate == nil {
                if latest == nil || (txn.expirationDate ?? .distantPast) > (latest?.expirationDate ?? .distantPast) {
                    latest = txn
                }
            }
        }
        return latest
    }

    /// Formatted price for a product, e.g. "¥6.00/month"
    func formattedPrice(for product: Product) -> (price: String, period: String) {
        let price = product.displayPrice
        let period: String
        switch product.subscription?.subscriptionPeriod.unit {
        case .month: period = String(localized: "store.per_month")
        case .year:  period = String(localized: "store.per_year")
        default:     period = ""
        }
        return (price, period)
    }

    /// Annual savings badge, e.g. "省 50%"
    var annualSavingsText: String? {
        guard let monthly = monthlyProduct?.price,
              let yearly = yearlyProduct?.price else { return nil }
        let monthlyAnnual = NSDecimalNumber(decimal: monthly).multiplying(by: 12).decimalValue
        guard monthlyAnnual > yearly else { return nil }
        let ratio = (monthlyAnnual - yearly) / monthlyAnnual
        let savings = NSDecimalNumber(decimal: ratio).multiplying(by: 100).intValue
        return String(format: String(localized: "store.save_percent"), savings)
    }

    // MARK: - Verification
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.unverified
        case .verified(let safe):
            return safe
        }
    }

    enum StoreError: LocalizedError {
        case unverified
        var errorDescription: String? {
            String(localized: "store.error_unverified")
        }
    }
}
