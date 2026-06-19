//
//  StoreManager.swift
//  ConexoesAmizaticas
//
//  Created by Jonas Fernando Nascimento Melo on 12/06/26.
//

import StoreKit
import SwiftUI
import Combine

/// Handles StoreKit purchases: loads products, runs purchase/restore flows, listens for transaction
/// updates and tracks whether the user owns the premium ("Group") entitlement.
@MainActor
class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()
    
    // Coloque aqui o Product ID que você criou no App Store Connect
    private let productIDs: Set<String> = ["Group"]
    
    @Published var products: [Product] = []
    @Published var isPremium: Bool = false
    @Published var isLoading: Bool = false
    
    private var transactionListener: Task<Void, Error>?

    /// Product id of the consumable that unlocks creating one extra group.
    private let groupProductID = "Group"
    /// Transaction ids already turned into a group slot, so a transaction delivered to both the purchase
    /// call and the updates listener is never counted twice.
    private var grantedTransactionIDs: Set<UInt64> = []

    init() {
        transactionListener = listenForTransactions()
        Task {
            await loadProducts()
            await updatePurchaseStatus()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - Carregar produtos da App Store
    func loadProducts() async {
        do {
            products = try await Product.products(for: productIDs)
        } catch {
            print("Erro ao carregar produtos: \(error)")
        }
    }
    
    // MARK: - Realizar compra
    func purchase(_ product: Product) async throws {
        isLoading = true
        defer { isLoading = false }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchaseStatus()
            await transaction.finish()
        case .userCancelled:
            break
        case .pending:
            break
        @unknown default:
            break
        }
    }
    
    // MARK: - Realizar Compra Unitária (Consumível)
    func purchaseConsumable(_ product: Product) async throws -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await redeemIfGroup(transaction)
            return true

        case .userCancelled:
            return false
        case .pending:
            return false
        @unknown default:
            return false
        }
    }

    /// Grants a group slot for a verified, unrevoked "Group" purchase exactly once, then finishes the
    /// transaction so StoreKit stops redelivering it. Called from both the purchase flow and the updates
    /// listener, so deferred (Ask to Buy) and interrupted purchases still grant the slot they paid for.
    private func redeemIfGroup(_ transaction: StoreKit.Transaction) async {
        if transaction.productID == groupProductID,
           transaction.revocationDate == nil,
           grantedTransactionIDs.insert(transaction.id).inserted {
            GroupSlots.addPurchasedSlot()
        }
        await transaction.finish()
    }
    
    // MARK: - Restaurar compras
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await AppStore.sync()
            await updatePurchaseStatus()
        } catch {
            print("Erro ao restaurar: \(error)")
        }
    }
    
    // MARK: - Verificar se é premium
    func updatePurchaseStatus() async {
        var hasPremium = false
        
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if productIDs.contains(transaction.productID) && !transaction.isExpired {
                    hasPremium = true
                }
            }
        }
        
        isPremium = hasPremium
    }
    
    // MARK: - Escutar transações em tempo real (renovações, etc.)
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.updatePurchaseStatus()
                    await self.redeemIfGroup(transaction)
                } catch {
                    print("Transação inválida: \(error)")
                }
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let value):
            return value
        }
    }
    
    var isExpired: Bool {
        return !isPremium
    }
}


extension StoreKit.Transaction {
    var isExpired: Bool {
        if let expirationDate = expirationDate {
            return expirationDate < Date()
        }
        return false
    }
}


enum StoreError: Error, LocalizedError {
    case failedVerification
    case productNotFound
    case purchaseFailed(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Não foi possível verificar a compra com a App Store."
        case .productNotFound:
            return "Produto não encontrado. Tente novamente mais tarde."
        case .purchaseFailed(let reason):
            return "Falha na compra: \(reason)"
        }
    }
}
