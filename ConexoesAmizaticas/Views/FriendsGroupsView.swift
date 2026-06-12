//
//  FriendsGroupsView.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 12/06/26.
//

import SwiftUI

struct FriendsGroupsView: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.themeBackground)
            VStack {
                Text("Crie um grupo com os amigos que você escolher e acompanhe a saúde geral dessas amizades num lugar só.")
                    .font(.custom("Sora-ExtraBold", size: 16))
                    .foregroundStyle(.bleOverlayText)
                    .multilineTextAlignment(.center)
                    .frame(width: 281)
                Text("você ainda  não tem nenhum grupo")
                    .font(.custom("Sora-Bold", size: 20))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .frame(width: 209)
            }
        }
    }
}

#Preview {
    FriendsGroupsView()
}
