//
//  RelationshipChart.swift
//  ConexoesAmizaticas
//
//  Created by Dayô Araújo on 26/05/26.
//

import SwiftUI
import Charts

/// The donut-style pie chart that breaks the user's connections down by `RelationshipState`.
///
/// `RelationshipChart` is the visual layer driven by `UserProfileViewModel`. It renders one sector per bucket,
/// highlights the slice currently hovered via `selectedAngle`, and overlays a central label that summarizes
/// either the selected slice or the chart title.
struct RelationshipChart: View {
    @Bindable var viewModel: UserProfileViewModel
    let size: CGSize

    /// The chart's plot rectangle, captured so the tap gesture can find the donut center.
    @State private var plotFrame: CGRect = .zero

    var body: some View {
        Chart {
            ForEach(viewModel.friendsByState, id: \.state) { item in
                SectorMark(
                    angle: .value("Quantidade", item.count),
                    innerRadius: .inset(24),
                    angularInset: 2
                )
                .cornerRadius(4)
                .opacity(viewModel.sliceOpacity(for: item.state))
                .foregroundStyle(Color(item.state.color))
            }
        }
        // Press-and-hold scrubbing (temporary, follows the finger).
        .chartAngleSelection(value: $viewModel.selectedAngle)
        .chartBackground { chartProxy in
            GeometryReader { geometry in
                if let anchor = chartProxy.plotFrame {
                    let frame = geometry[anchor]
                    centerLabel
                        .position(x: frame.midX, y: frame.midY)
                    // Keep the plot rectangle up to date for the tap gesture below.
                    Color.clear
                        .onAppear { plotFrame = frame }
                        .onChange(of: frame) { _, newFrame in plotFrame = newFrame }
                }
            }
        }
        // Tap a slice to pin its info (tap it again, or the center, to clear). Runs alongside the hold
        // scrub via a simultaneous gesture, so both interactions work.
        .simultaneousGesture(
            SpatialTapGesture().onEnded { value in selectSlice(at: value.location, in: plotFrame) }
        )
        .chartLegend(.hidden)
        .frame(width: size.width, height: size.height)
    }

    /// Maps a tap inside the donut to the slice under it and pins the selection. Tapping the donut hole,
    /// outside the ring, or the already-selected slice clears it.
    private func selectSlice(at location: CGPoint, in frame: CGRect) {
        let total = Double(viewModel.friendCount)
        guard total > 0 else { return }

        let dx = location.x - frame.midX
        let dy = location.y - frame.midY
        let distance = sqrt(dx * dx + dy * dy)
        let outerRadius = min(frame.width, frame.height) / 2
        let innerRadius = outerRadius - 24   // matches SectorMark's .inset(24)

        // Only the ring is interactive — tapping the hole or outside clears the pin.
        guard distance >= innerRadius, distance <= outerRadius else {
            viewModel.pinnedAngle = nil
            return
        }

        // Angle measured from the top (12 o'clock), clockwise, to match how the slices are drawn.
        var angle = atan2(dx, -dy)
        if angle < 0 { angle += 2 * .pi }
        let value = angle / (2 * .pi) * total

        // Toggle off when tapping the slice that's already pinned.
        if let current = viewModel.selectedItem,
           let index = viewModel.categoryRanges.firstIndex(where: { $0.range.contains(value) }),
           viewModel.friendsByState[index].state == current.state {
            viewModel.pinnedAngle = nil
        } else {
            viewModel.pinnedAngle = value
        }
    }

    private var centerLabel: some View {
        VStack(spacing: 4) {
            if let selected = viewModel.selectedItem, let percentage = viewModel.selectedPercentage {
                Text("\(percentage)%")
                    .font(.custom("Bolota", size: 36))
                    .foregroundStyle(Color(uiColor: selected.state.color))
                Text(selected.state.displayName.uppercased())
                    .font(.custom("Sora-SemiBold", size: 22))
                    .foregroundStyle(Color(uiColor: selected.state.color))
            } else {
                Text("RODA DA\nAMIZADE")
                    .font(.custom("Bolota", size: 36))
                    .foregroundStyle(.lightBackground)
            }
        }
        .multilineTextAlignment(.center)
    }
}
