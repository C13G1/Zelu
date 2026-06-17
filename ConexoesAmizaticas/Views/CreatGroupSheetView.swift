//
//  CreatGroupView.swift
//  ConexoesAmizaticas
//
//  Created by Jonas Fernando Nascimento Melo on 17/06/26.
//

import SwiftUI
import SwiftData

// TODO: Bullet Plz documenta este arquivo <3
struct CreatGroupSheetView: View {
    @State var isChoosingGroupMembers = true
    @State var selectedConnections: [Connection] = []
    var body: some View {
        NavigationStack{
            if isChoosingGroupMembers {
                ChooseGroupMembersView(isChoosingGroupMembers: $isChoosingGroupMembers, selectedConecctions: $selectedConnections)
            }
            else {
                SetGroupView(selectedConnections: selectedConnections)
            }
        }
    }
}

#Preview {
    CreatGroupSheetView()
}
