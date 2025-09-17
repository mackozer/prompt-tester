import Foundation
import Combine
import StoreKit
import SwiftUI

@MainActor
final class TipStore: ObservableObject {
    // Replace these identifiers with your real product IDs from App Store Connect.
    // Keep them as non-consumable products for a one-time tip.
    private let productIDs: Set<String> = [
        "com.mackozer.MyPromptTester.tip"
    ]

    @Published var products: [Product] = []
    @Published var isLoading: Bool = false
    @Published var lastMessage: String? = nil

    // Persistence for one-time tip state
    private let tippedKey = "hasTippedDeveloper"
    @Published var hasTipped: Bool = false

    init() {
        // Load persisted tip state (fallback)
        self.hasTipped = UserDefaults.standard.bool(forKey: tippedKey)
        Task { [weak self] in
            await self?.refreshEntitlement()
        }
        Task { [weak self] in
            await self?.loadProducts()
        }
        Task { [weak self] in
            await self?.observeTransactions()
        }
    }

    func loadProducts() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await Product.products(for: Array(productIDs))
            // Only non-consumable tips are valid here
            self.products = fetched
                .filter { $0.type == .nonConsumable }
                .sorted { $0.displayPrice < $1.displayPrice }
        } catch {
            self.lastMessage = "Couldn’t load tip products."
        }
    }

    /// Refresh entitlement by checking current verified transactions for non-consumable tip
    func refreshEntitlement() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, productIDs.contains(transaction.productID) {
                owned = true
                break
            }
        }
        self.hasTipped = owned
        UserDefaults.standard.set(owned, forKey: tippedKey)
    }

    /// Observe transaction updates to reflect new purchases and keep state in sync
    func observeTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result, productIDs.contains(transaction.productID) {
                // Finish and mark as owned
                await transaction.finish()
                self.hasTipped = true
                UserDefaults.standard.set(true, forKey: tippedKey)
            }
        }
    }

    func purchaseTip() async {
        guard let product = products.first else {
            lastMessage = "Tip product unavailable."
            return
        }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    // For non-consumables, finish after delivering the entitlement
                    await transaction.finish()
                    self.hasTipped = true
                    UserDefaults.standard.set(true, forKey: self.tippedKey)
                    lastMessage = "Thank you for the tip!"
                case .unverified(_, _):
                    lastMessage = "Purchase couldn’t be verified."
                }
            case .userCancelled:
                lastMessage = "Purchase cancelled."
            case .pending:
                lastMessage = "Purchase pending."
            @unknown default:
                lastMessage = "Unknown purchase result."
            }
        } catch {
            lastMessage = "Purchase failed."
        }
    }
    
    /// Attempt to restore previous purchases and refresh entitlement state
    func restorePurchases() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            if hasTipped {
                lastMessage = "Purchases restored. Thank you!"
            } else {
                lastMessage = "No previous tips to restore."
            }
        } catch {
            lastMessage = "Restore failed."
        }
    }
}
