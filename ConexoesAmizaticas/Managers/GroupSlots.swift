//
//  GroupSlots.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 18/06/26.
//

import Foundation

/// Tracks how many extra group "slots" the user owns, beyond the one free group.
///
/// Creating a group is sold as a StoreKit consumable, and consumables cannot be restored by StoreKit, so
/// the entitlement is persisted here in iCloud key-value storage: it syncs across the user's devices and
/// survives reinstalling the app. The slot count — not the existence of any one group — is the durable
/// source of truth, so deleting a group frees its slot to be recreated without paying again, and a
/// purchase whose creation sheet is dismissed still banks the slot for next time.
enum GroupSlots {
    private static let store = NSUbiquitousKeyValueStore.default
    private static let key = "purchasedGroupSlots"

    /// Groups allowed before any purchase: the first group is free.
    static let freeAllowance = 1

    // MARK: - Pure rules (no storage, kept separate so they stay trivially testable)

    /// Total groups allowed for a given number of purchased slots.
    static func allowance(purchased: Int) -> Int { freeAllowance + max(0, purchased) }

    /// Whether creating one more group, on top of `existingCount`, requires buying a slot.
    static func needsPurchase(existingCount: Int, purchased: Int) -> Bool {
        existingCount >= allowance(purchased: purchased)
    }

    /// Self-healed slot count: every group past the free one was paid for, so the stored count can only
    /// rise to match the groups that already exist — never charging twice for groups synced from another
    /// device or restored from CloudKit after a reinstall. Deleting groups never lowers it (the `max`),
    /// which is exactly what keeps a freed slot available.
    static func reconciled(purchased: Int, existingCount: Int) -> Int {
        max(purchased, existingCount - freeAllowance)
    }

    // MARK: - iCloud-backed state

    static var purchased: Int { Int(store.longLong(forKey: key)) }

    /// Whether the next group must be bought, given the slots currently owned.
    static func needsPurchase(existingCount: Int) -> Bool {
        needsPurchase(existingCount: existingCount, purchased: purchased)
    }

    /// Banks one paid slot after a successful purchase.
    static func addPurchasedSlot() {
        store.set(Int64(purchased + 1), forKey: key)
        store.synchronize()
    }

    /// Raises the stored count to cover groups that already exist, so they are never charged for again.
    static func reconcile(existingCount: Int) {
        let healed = reconciled(purchased: purchased, existingCount: existingCount)
        if healed != purchased {
            store.set(Int64(healed), forKey: key)
            store.synchronize()
        }
    }

    /// Clears purchased slots on account deletion for a clean slate.
    static func reset() {
        store.removeObject(forKey: key)
        store.synchronize()
    }
}
