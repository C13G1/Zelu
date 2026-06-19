//
//  MemberAvatar.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 18/06/26.
//

import SwiftUI

/// A friend's avatar ringed with their relationship color plus their name — the shared chip used
/// across the group screens (member grids and the selected-members strip).
struct MemberAvatar: View {
    let connection: Connection

    private let side = UIScreen.main.bounds.width * 0.16

    var body: some View {
        VStack {
            Image(uiImage: UIImage(data: connection.friend?.profilePicture ?? Data()) ?? UIImage(named: "defaultPicture")!)
                .resizable()
                .frame(width: side, height: side)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(Color(uiColor: connection.metaManager?.currentRelationshipState.color ?? RelationshipState.afastados.color), lineWidth: 3)
                }
            Text(connection.friend?.name ?? "")
                .font(.custom("Sora-SemiBold", size: 14))
        }
    }
}
