import SwiftUI
import SwiftData
import StoreKit

struct FriendsGroupsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var friendsGroupVM: FriendsGroupsViewModel
    @State private var showCreateGroupSheet = false
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
                if let produtoParaComprar = storeManager.products.first(where: { $0.id == "Group" }) {
                    Task {
                        do {
                            let compraAprovada = try await storeManager.purchaseConsumable(produtoParaComprar)
                            if compraAprovada {
                                showCreateGroupSheet = true
                            }
                        } catch {
                            print("Falha na transação: \(error)")
                        }
                    }
                } else {
                    print("Produto não carregou.")
                }
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
        .onChange(of: storeManager.isPremium) { _, novoStatus in
            if novoStatus {
                showCreateGroupSheet = true
            }
        }
        .onChange(of: showCreateGroupSheet) {
            do {
                let descriptor = FetchDescriptor<FriendGroup>()
                let groups = try modelContext.fetch(descriptor)
                
                friendsGroupVM.friendsGroups = groups
            } catch {
                print("Erro ao buscar grupos: \(error)")
            }
            
        }
    }
}
