//
//  NearbyOrbitRings.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 10/06/26.
//

import SwiftUI

/// The animated background of the radar: three rings of dots slowly turning around the own avatar.
/// The dots get smaller and darker from the inner ring to the outer one. Only the top half of each
/// ring fits on screen, so the dots enter on one side and leave on the other.
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
