import Foundation
import StoreKit
import Observation

/// Handles the "Compass To Pro" non-consumable in-app purchase via StoreKit 2.
///
/// Keeps `UserDefaults.standard["isPro"]` in sync with the current entitlement
/// so existing `@AppStorage("isPro")` reads across the app stay correct without
/// any changes to those call sites.
@Observable
final class PurchaseManager {
    static let proProductID = "org.hoeschen.lukas.Compass-to.pro"

    private(set) var product: Product?
    private(set) var isPro: Bool
    private(set) var isLoading = false
    var errorMessage: String?

    private var updateListenerTask: Task<Void, Never>?

    init() {
        isPro = UserDefaults.standard.bool(forKey: "isPro")
        updateListenerTask = Self.listenForTransactions { [weak self] in
            await self?.updateEntitlementStatus()
        }
        Task {
            await loadProduct()
            await updateEntitlementStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    @MainActor
    func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.proProductID])
            product = products.first
        } catch {
            errorMessage = "Could not load product: \(error.localizedDescription)"
        }
    }

    @MainActor
    func purchase() async {
        guard let product else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try Self.checkVerified(verification)
                await transaction.finish()
                await updateEntitlementStatus()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await updateEntitlementStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func updateEntitlementStatus() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? Self.checkVerified(result) else { continue }
            if transaction.productID == Self.proProductID {
                active = true
            }
        }
        isPro = active
        UserDefaults.standard.set(active, forKey: "isPro")
    }

    private static func listenForTransactions(onUpdate: @escaping () async -> Void) -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if let transaction = try? checkVerified(result) {
                    await transaction.finish()
                }
                await onUpdate()
            }
        }
    }

    private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    enum StoreError: Error {
        case failedVerification
    }
}
