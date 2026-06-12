//
//  NearbyPersonCell.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 10/06/26.
//

import SwiftUI

/// One person on the radar: the avatar with a status ring, the name and a short invite message.
///
/// The ring color tells the invite state: green when the person wants to meet you, faded white
/// when you already sent an invite, plain white when nothing happened yet.
struct NearbyPersonCell: View {
    let person: NearbyPerson
    let onTap: () -> Void

    private let avatarDiameter: CGFloat = 64

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                FriendAvatar(imageData: person.user.profilePicture,
                             diameter: avatarDiameter,
                             strokeColor: ringColor)
                Text(person.user.name)
                    .font(.custom("Sora-Regular", size: 13))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                statusBadge
            }
            .frame(width: 120)
        }
        .buttonStyle(.plain)
    }

    private var ringColor: Color {
        if person.receivedInvite { return .green }
        if person.sentInvite { return .white.opacity(0.5) }
        return .white
    }

    @ViewBuilder
    private var statusBadge: some View {
        if person.receivedInvite {
            Text("quer te encontrar")
                .font(.custom("Sora-Regular", size: 11))
                .foregroundStyle(.green)
        } else if person.sentInvite {
            Text("convite enviado")
                .font(.custom("Sora-Regular", size: 11))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}
