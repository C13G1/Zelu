//
//  FriendsGroupsView.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 12/06/26.
//

import SwiftUI

struct FriendsGroupsFrame: View {
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var body: some View {
        Circle()
            .frame(width: width * 0.45, height: height * 0.27)
    }
}

#Preview {
    return FriendsGroupsFrame()
        .preferredColorScheme(.dark)
}
