//
//  NearbyOrbitRings.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 10/06/26.
//

import SwiftUI

/// The orbit field behind the "Pessoas por perto" radar: three concentric rings of dots slowly
/// orbiting the own avatar. Dots shrink and fade with the distance — big and bright on the inner
/// ring, small and dim on the outer one. Only the upper half of each ring is on screen, so the
/// dots keep drifting in from one side and out the other.
struct NearbyOrbitRings: View {
    let center: CGPoint
    let radii: [CGFloat]

    @State private var spinning = false

    private static let dotCounts = [26, 34, 42]
    private static let dotSizes: [CGFloat] = [18, 13, 8]
    private static let dotOpacities: [Double] = [0.7, 0.5, 0.32]
    private static let durations: [Double] = [70, 105, 150]

    var body: some View {
        ZStack {
            ForEach(radii.indices, id: \.self) { ring in
                let radius = radii[ring]

                ZStack {
                    ForEach(0..<Self.dotCounts[ring], id: \.self) { i in
                        let angle = Double(i) / Double(Self.dotCounts[ring]) * 2 * .pi
                        Circle()
                            .fill(Color(white: 0.8).opacity(Self.dotOpacities[ring]))
                            .frame(width: Self.dotSizes[ring], height: Self.dotSizes[ring])
                            .offset(x: cos(angle) * radius, y: sin(angle) * radius)
                    }
                }
                .rotationEffect(.degrees(spinning ? (ring.isMultiple(of: 2) ? 360 : -360) : 0))
                .animation(.linear(duration: Self.durations[ring]).repeatForever(autoreverses: false),
                           value: spinning)
                .position(center)
            }
        }
        .onAppear { spinning = true }
        .allowsHitTesting(false)
    }
}
