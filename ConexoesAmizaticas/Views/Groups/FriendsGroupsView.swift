//
//  FriendsGroupsView.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 12/06/26.
//

import SwiftUI
import SwiftData
import StoreKit
import CoreData
import Combine


/// The groups section under the tab bar: the carousel of existing groups and the create-group button.
struct FriendsGroupsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var friendsGroupVM: FriendsGroupsViewModel
    @State private var showCreateGroupSheet = false
    @State private var showStoreError = false
    @State private var showGroupInfo = false
    @StateObject private var storeManager = StoreKitManager.shared
    
    init() {
        self._friendsGroupVM = State(initialValue: FriendsGroupsViewModel())
    }
    
    var body: some View {
        VStack(spacing: 60) {
            if friendsGroupVM.friendsGroups.isEmpty {
                Text("Crie um grupo com os amigos que você escolher e acompanhe a saúde geral dessas amizades num lugar só.")
                    .font(.custom("Sora-ExtraBold", size: 16))
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .frame(width: 281)
                
                Text("você ainda não tem nenhum grupo")
                    .font(.custom("Sora-Bold", size: 20))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .frame(width: 209)
            } else {
                FriendsGroupsScroll(viewModel: friendsGroupVM)
            }
            
            VStack(spacing: 8) {
                Button(action: {
                    Task { await purchaseGroup() }
                }, label: {
                    ZStack {
                        if storeManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .backgoundGreen))
                                .scaleEffect(1.5)
                        } else {
                            Image(systemName: "plus")
                                .foregroundStyle(.backgoundGreen)
                                .fontWeight(.bold)
                                .font(.system(size: 64))
                        }
                    }
                })
                .disabled(storeManager.isLoading)

                // Make the free-then-paid model explicit instead of leaving the bare "+" ambiguous,
                // with an info button that explains the credit rule.
                HStack(spacing: 6) {
                    Text(groupButtonCaption)
                        .font(.custom("Sora-Regular", size: 14))
                        .foregroundStyle(.gray)
                    Button {
                        showGroupInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(.gray)
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateGroupSheet){
            CreatGroupSheetView()
        }
        .padding(.top, 10)
        .padding(.bottom, 70)
        .frame(maxWidth: .infinity)
        .background(Color.themeBackground)
        .onAppear() {
            friendsGroupVM.setModelContext(modelContext: modelContext)
            friendsGroupVM.fetchData()
            GroupSlots.reconcile(existingCount: friendsGroupVM.friendsGroups.count)
        }
        .onReceive(NotificationCenter.default.publisher(for: .GroupUpdated)) { _ in
            friendsGroupVM.fetchData()
            GroupSlots.reconcile(existingCount: friendsGroupVM.friendsGroups.count)
        }
        // The VM fetches groups manually (not via @Query), so CloudKit imports that arrive after the view
        // appeared won't show up on their own — refresh when CloudKit reports a sync event. CloudKit posts
        // this on a background queue, so hop to main before touching the VM ("Publishing changes from
        // background threads is not allowed").
        .onReceive(NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification).receive(on: RunLoop.main)) { _ in
            friendsGroupVM.fetchData()
            GroupSlots.reconcile(existingCount: friendsGroupVM.friendsGroups.count)
        }
        .task {
            if storeManager.products.isEmpty {
                await storeManager.loadProducts()
            }
        }
        .alert("Não foi possível concluir a compra", isPresented: $showStoreError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Verifique sua conexão e tente novamente.")
        }
        .alert("Como funcionam os grupos", isPresented: $showGroupInfo) {
            Button("Entendi", role: .cancel) {}
        } message: {
            Text("Seu primeiro grupo é grátis. Cada grupo a mais é comprado uma vez. Se você apagar um grupo que pagou, o crédito fica guardado: dá para criar outro no lugar sem pagar de novo. Os créditos seguem a sua conta pelo iCloud.")
        }
    }

    /// Single caption under the create button — kept to one line so it never shifts the carousel above it.
    /// States the cost up front, or how many groups can still be created without paying (free group plus
    /// any credits from deleted paid groups).
    private var groupButtonCaption: String {
        let count = friendsGroupVM.friendsGroups.count
        if count == 0 {
            return "Seu primeiro grupo é grátis"
        }
        let remaining = GroupSlots.freeRemaining(existingCount: count)
        if remaining > 0 {
            return remaining == 1
                ? "Você pode criar 1 grupo sem pagar"
                : "Você pode criar \(remaining) grupos sem pagar"
        }
        if let price = storeManager.products.first(where: { $0.id == "Group" })?.displayPrice {
            return "Novo grupo • \(price)"
        }
        return "Novo grupo"
    }

    /// Opens the creation sheet directly when the user still owns a free or previously-bought slot,
    /// otherwise buys one slot first. Reloads the products if the store hasn't finished loading, and
    /// surfaces an alert instead of silently doing nothing when the product is unavailable.
    private func purchaseGroup() async {
        let count = friendsGroupVM.friendsGroups.count
        // Groups that already exist were already paid for — never charge for them again.
        GroupSlots.reconcile(existingCount: count)
        // Covered by the free group or a slot freed by deleting an earlier group: no charge.
        if !GroupSlots.needsPurchase(existingCount: count) {
            showCreateGroupSheet = true
            return
        }
        if storeManager.products.isEmpty {
            await storeManager.loadProducts()
        }
        guard let product = storeManager.products.first(where: { $0.id == "Group" }) else {
            showStoreError = true
            return
        }
        do {
            // The slot is granted inside StoreKitManager when the verified transaction is processed (also
            // covering deferred/interrupted purchases), so here we only open the creation sheet.
            if try await storeManager.purchaseConsumable(product) {
                showCreateGroupSheet = true
            }
        } catch {
            showStoreError = true
        }
    }
}
