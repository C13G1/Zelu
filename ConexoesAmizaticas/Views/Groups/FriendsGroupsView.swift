//
//  FriendsGroupsView.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 12/06/26.
//

import SwiftUI
import SwiftData
import StoreKit


/// The groups section under the tab bar: the carousel of existing groups and the create-group button.
struct FriendsGroupsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var friendsGroupVM: FriendsGroupsViewModel
    @State private var showCreateGroupSheet = false
    @State private var showStoreError = false
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
        }
        .onReceive(NotificationCenter.default.publisher(for: .GroupUpdated)) { _ in
            friendsGroupVM.fetchData()
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
    }

    /// Buys the consumable that unlocks creating a group, then opens the creation sheet on success.
    /// Reloads the products first if the store hasn't finished loading, and surfaces an alert instead
    /// of silently doing nothing when the product is unavailable (offline or not yet approved).
    private func purchaseGroup() async {
        if storeManager.products.isEmpty {
            await storeManager.loadProducts()
        }
        guard let product = storeManager.products.first(where: { $0.id == "Group" }) else {
            showStoreError = true
            return
        }
        do {
            if try await storeManager.purchaseConsumable(product) {
                showCreateGroupSheet = true
            }
        } catch {
            showStoreError = true
        }
    }
}
