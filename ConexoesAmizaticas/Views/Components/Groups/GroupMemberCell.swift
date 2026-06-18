//
//  GroupMemberCell.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 18/06/26.
//

import SwiftUI

/// One member inside a group's grid: the friend's avatar ringed with their relationship color,
/// the name, and a remove badge. Tapping the cell calls `onRemove`.
struct GroupMemberCell: View {
    let connection: Connection
    let onRemove: () -> Void

    private let badgeSide = UIScreen.main.bounds.height * 0.0211

    var body: some View {
        ZStack(alignment: .topTrailing) {
            MemberAvatar(connection: connection)
            ZStack {
                Circle()
                    .frame(width: badgeSide)
                    .foregroundStyle(.black)
                Image(systemName: "xmark")
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                    .bold()
            }
        }
        .onTapGesture(perform: onRemove)
    }
}
