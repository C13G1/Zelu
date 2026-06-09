//
//  BLEAvatarsLayer.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 27/05/26.
//

import SwiftUI

/// Positions the two circular avatars of the `BLEView`: the friend's avatar slides in from above
/// when a match is detected, while the user's own avatar stays anchored at the bottom.
struct BLEAvatarsLayer: View {
    let size: CGSize
    let profileImageData: Data
    let friendImageData: Data?
    let phase: BLEViewModel.Phase
    let avatarDiameter: CGFloat
    let topY: CGFloat
    let bottomY: CGFloat
    /// Washes the avatars with a faint white veil to read as "disabled" — used when the matched friend
    /// is on cooldown and the encounter can't be registered.
    var isDimmed: Bool = false

    var body: some View {
        let centerX = size.width / 2

        ZStack {
            if let friendImageData = friendImageData {
                FriendAvatar(
                    imageData: friendImageData,
                    diameter: avatarDiameter,
                    strokeColor: .white
                )
                .overlay(dimVeil)
                .scaleEffect(phase == .searching ? 0.8 : 1.0)
                .position(
                    x: centerX,
                    y: phase == .searching ? -avatarDiameter : topY
                )
            }

            FriendAvatar(
                imageData: profileImageData,
                diameter: avatarDiameter,
                strokeColor: .white
            )
            .overlay(dimVeil)
            .position(x: centerX, y: bottomY)
        }
    }

    private var dimVeil: some View {
        Circle().fill(Color.white.opacity(isDimmed ? 0.3 : 0))
    }
}
