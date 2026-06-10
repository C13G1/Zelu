//
//  UserProfileViewModel.swift
//  ConexoesAmizaticas
//
//  Created by Dayô Araújo on 26/05/26.
//

import Foundation
import SwiftUI

/// Aggregates and formats the analytical data shown by `UserProfileView`.
///
/// `UserProfileViewModel` turns the raw `Connection` list into the buckets, ranges and labels consumed
/// by the SwiftUI Charts pie chart. It also exposes a `selectedAngle` driver for the angle-selection gesture.
@Observable
class UserProfileViewModel {
    /// Mirror of the SwiftData query result. Update from the view whenever connections change.
    var connections: [Connection] = []

    /// Angle being scrubbed right now via press-and-hold (`.chartAngleSelection`); clears on release.
    var selectedAngle: Double?
    /// Angle pinned by a tap; stays until tapped again. Used when nothing is being scrubbed.
    var pinnedAngle: Double?

    /// The angle that should drive the highlight: a live scrub takes priority over a pinned tap.
    var activeAngle: Double? { selectedAngle ?? pinnedAngle }

    /// Total number of saved metaManagers.
    var friendCount: Int { connections.count }

    /// Friendships grouped by `RelationshipState`, ordered for a stable chart layout.
    var friendsByState: [(state: RelationshipState, count: Int)] {
        let orderedStates: [RelationshipState] = [
            .afastados, .proximos, .distantes, .estaveis, .inseparaveis
        ]
        let grouped = Dictionary(grouping: connections) {
            $0.metaManager.currentRelationshipState
        }
        return orderedStates.compactMap { state in
            let count = grouped[state]?.count ?? 0
            guard count > 0 else { return nil }
            return (state: state, count: count)
        }
    }

    /// Per-bucket angle ranges used to map the user's pointer position to a relationship state.
    var categoryRanges: [(state: RelationshipState, range: Range<Double>)] {
        var total = 0.0
        return friendsByState.map { item in
            let newTotal = total + Double(item.count)
            let result = (state: item.state, range: total..<newTotal)
            total = newTotal
            return result
        }
    }

    /// The bucket the user is currently pointing at, or `nil` when no selection is active.
    var selectedItem: (state: RelationshipState, count: Int)? {
        guard let activeAngle else { return nil }
        guard let index = categoryRanges.firstIndex(where: { $0.range.contains(activeAngle) }) else { return nil }
        return friendsByState[index]
    }

    /// Localized text describing the most recent meeting across all metaManagers.
    var lastMeetingText: String {
        let mostRecent = connections.compactMap { $0.lastMet }.max()
        guard let mostRecent else { return "NUNCA" }
        let days = Calendar.current.dateComponents([.day], from: mostRecent, to: .now).day ?? 0
        if days == 0 { return "HOJE" }
        if days == 1 { return "HÁ 1 DIA" }
        return "HÁ \(days) DIAS"
    }

    /// Percentage of the total friend count occupied by the currently selected bucket.
    var selectedPercentage: Int? {
        guard let selected = selectedItem, friendCount > 0 else { return nil }
        return Int(round(Double(selected.count) / Double(friendCount) * 100))
    }

    /// Returns the opacity to render a chart slice based on the current selection.
    func sliceOpacity(for state: RelationshipState) -> Double {
        guard let selected = selectedItem else { return 1.0 }
        return selected.state == state ? 1.0 : 0.4
    }
}
