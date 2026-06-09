//
//  BLEConfirmedOverlay.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 27/05/26.
//

import SwiftUI

/// The celebratory circle that fades in over the avatars when an encounter is successfully confirmed.
///
/// `reveal` drives both the opacity and a subtle scale animation: it should ramp from `0` to `1` once
/// the press-and-hold gesture completes.
struct BLEConfirmedOverlay: View {
    let reveal: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.bleBackground)
                .frame(width: 233, height: 233)
                .scaleEffect(0.92 + 0.08 * reveal)

            VStack(spacing: 2) {
                Text("Encontro registrado!")
            }
            .font(
                Font.custom("Bolota", size: 32)
                    .weight(.bold)
            )
            .kerning(0.38)
            .foregroundColor(Color.white)
            .multilineTextAlignment(.center)
            .frame(width: 263, alignment: .top)
        }
        .opacity(Double(reveal))
    }
}
