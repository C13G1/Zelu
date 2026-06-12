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
    /// Incremented by the parent to play one "wrong passcode" shake on the avatars — used to reject
    /// a press while the matched friend is on cooldown.
    var shakeTrigger: Int = 0
    
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
        .modifier(ShakeEffect(animatableData: CGFloat(shakeTrigger)))
    }

    private var dimVeil: some View {
        Circle().fill(Color.white.opacity(isDimmed ? 0.3 : 0))
    }
}

/// Horizontal "wrong passcode" shake: each unit step of `animatableData` plays `shakesPerUnit`
/// full left-right oscillations, so animating an `Int` trigger by 1 yields one complete shake.
private struct ShakeEffect: GeometryEffect {
    var travelDistance: CGFloat = 9
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: travelDistance * sin(animatableData * .pi * 2 * shakesPerUnit),
            y: 0
        ))
    }
}
