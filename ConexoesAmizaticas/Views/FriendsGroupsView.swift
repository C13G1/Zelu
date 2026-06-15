//
//  FriendsGroupsView.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 12/06/26.
//

import SwiftUI
import SwiftData

struct FriendsGroupsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var friendsGroupVM: FriendsGroupsViewModel
    
    init() {
        self._friendsGroupVM = State(initialValue: FriendsGroupsViewModel())
    }
    
    var body: some View {
        VStack (spacing: 100){
            VStack (spacing: 40){
                if friendsGroupVM.friendsGroups.isEmpty {
                    Text("Crie um grupo com os amigos que você escolher e acompanhe a saúde geral dessas amizades num lugar só.")
                        .font(.custom("Sora-ExtraBold", size: 16))
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                        .frame(width: 281)
                    
                    Text("você ainda  não tem nenhum grupo")
                        .font(.custom("Sora-Bold", size: 20))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .frame(width: 209)
                }
                else {
                    FriendsGroupsScroll(viewModel: friendsGroupVM)
                }
            }
            
            Button(action: {
                friendsGroupVM.addFriendsGroup()
            }, label: {
                ZStack {
                    Image(systemName: "plus")
                        .foregroundStyle(.backgoundGreen)
                        .fontWeight(.bold)
                        .font(.system(size: 64))
                        
                }
            })
            .frame(width: 3000)
            .background(Color.themeBackground)
            .border(.red)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.themeBackground)
        .onAppear() {
            friendsGroupVM.setModelContext(modelContext: modelContext)
            friendsGroupVM.fetchData()
        }
    }
}

#Preview {
    FriendsGroupsView()
}
