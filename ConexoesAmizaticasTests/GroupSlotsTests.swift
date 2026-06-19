//
//  GroupSlotsTests.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 18/06/26.
//

import Testing
@testable import ConexoesAmizaticas

/// Covers the pure slot rules that decide when a group costs money — the part that, if wrong, charges
/// the user twice or gives groups away. The iCloud-backed storage is intentionally not exercised here.
@Suite("GroupSlots rules")
struct GroupSlotsTests {

    @Test("O primeiro grupo é grátis")
    func firstGroupIsFree() {
        #expect(GroupSlots.needsPurchase(existingCount: 0, purchased: 0) == false)
    }

    @Test("O segundo grupo cobra quando não há slot comprado")
    func secondGroupCharges() {
        #expect(GroupSlots.needsPurchase(existingCount: 1, purchased: 0) == true)
    }

    @Test("Um slot comprado libera o próximo grupo")
    func boughtSlotUnlocksNext() {
        #expect(GroupSlots.allowance(purchased: 1) == 2)
        #expect(GroupSlots.needsPurchase(existingCount: 1, purchased: 1) == false)
        #expect(GroupSlots.needsPurchase(existingCount: 2, purchased: 1) == true)
    }

    @Test("Apagar um grupo mantém o slot: recria de graça")
    func deletingKeepsTheSlot() {
        // Comprou 1 slot, tinha 2 grupos, apagou um -> count 1, purchased 1.
        #expect(GroupSlots.needsPurchase(existingCount: 1, purchased: 1) == false)
    }

    @Test("Reconcile nunca cobra de novo por grupos que já existem")
    func reconcilePreventsDoubleCharge() {
        // Reinstalou: KVS zerou, mas 2 grupos voltaram do CloudKit. Pelo menos 1 foi pago.
        #expect(GroupSlots.reconciled(purchased: 0, existingCount: 2) == 1)
        // Com o count curado, só o próximo grupo (o 3º) cobra.
        #expect(GroupSlots.needsPurchase(existingCount: 2, purchased: 1) == true)
    }

    @Test("Reconcile nunca abaixa a contagem (slot liberado sobrevive)")
    func reconcileNeverLowers() {
        #expect(GroupSlots.reconciled(purchased: 3, existingCount: 1) == 3)
    }

    @Test("Reconcile com zero grupos não vira negativo")
    func reconcileFloorsAtZero() {
        #expect(GroupSlots.reconciled(purchased: 0, existingCount: 0) == 0)
    }
}
