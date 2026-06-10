//
//  NearbyPeopleViewModel.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 10/06/26.
//

import SwiftUI

/// Drives the "Pessoas por perto" radar screen.
///
/// `NearbyPeopleViewModel` owns the `NearbyManager` that discovers people around, decides on which
/// ring each person appears and, when two people invite each other, exposes the friend through
/// `matchedFriend` so the view can open the meeting screen.
@Observable
class NearbyPeopleViewModel {

    /// A nearby person with their position on the radar already resolved.
    struct PlacedPerson {
        let person: NearbyPerson
        let point: CGPoint
    }

    /// The people currently nearby, closest first.
    var people: [NearbyPerson] { manager.people }

    /// Set when this user and a nearby person invited each other. Opens the meeting screen.
    var matchedFriend: User?

    /// The profile of the device owner, shared with the people around.
    let profile: User

    private let manager: NearbyManager

    /// Distance from the center to each ring, as a fraction of the space between the own avatar
    /// and the top of the people area.
    private static let ringDistanceFractions: [CGFloat] = [0.45, 0.70, 0.95]

    /// The inner ring never gets closer to the center than this, so it stays visible around the
    /// own avatar even on small screens.
    private static let minimumInnerDistance: CGFloat = 130

    /// Space between people on the same ring, in degrees, while the ring is not crowded.
    private static let groupedSpacing: Double = 40

    init(profile: User) {
        self.profile = profile
        self.manager = NearbyManager(profile: profile)
    }

    // MARK: - Lifecycle

    /// Starts discovering people and watches for a mutual invite.
    func start() {
        manager.onMutualMatch = { [weak self] friend in
            self?.matchedFriend = friend
            self?.manager.pauseForMeeting()
        }
        manager.start()
    }

    /// Stops discovering. Call when the screen is left.
    func stop() {
        manager.stop()
    }

    /// Call when the user comes back from the meeting screen, to become visible again.
    func resumeAfterMeeting() {
        matchedFriend = nil
        manager.resume()
    }

    /// Sends a meeting invite to the tapped person, or takes it back on a second tap.
    func toggleInvite(for person: NearbyPerson) {
        manager.toggleInvite(person.user.id)
    }

    // MARK: - Ring layout

    /// How far each ring sits from the center of the own avatar, where `field` is the distance
    /// between that center and the top of the people area.
    func ringDistances(field: CGFloat) -> [CGFloat] {
        Self.ringDistanceFractions.map { max($0 * field, Self.minimumInnerDistance) }
    }

    /// Gives every person a position on the radar. The closest people go to the inner ring.
    /// While a ring has few people they stay grouped near the top. When it gets crowded, the
    /// people spread around the whole circle and `rotation` (driven by the drag gesture on the
    /// screen) spins them, so the ones outside the screen can be brought into view.
    func placedPeople(center: CGPoint, ringDistances: [CGFloat], rotation: Double) -> [PlacedPerson] {
        let people = manager.people
        guard !people.isEmpty else { return [] }

        var rings: [[NearbyPerson]] = [[], [], []]
        for (index, person) in people.enumerated() {
            let ring = people.count == 1 ? 0 : index * 3 / people.count
            rings[ring].append(person)
        }

        var placed: [PlacedPerson] = []
        for (ring, ringPeople) in rings.enumerated() {
            let fullCircleSpacing = 360.0 / Double(max(ringPeople.count, 1))
            for (position, person) in ringPeople.enumerated() {
                let degrees: Double
                if fullCircleSpacing >= Self.groupedSpacing {
                    // Few people: alternate to the left and to the right of the top.
                    let step = Double((position + 1) / 2) * Self.groupedSpacing
                    degrees = 270 + rotation + (position.isMultiple(of: 2) ? -step : step)
                } else {
                    // Crowded: spread evenly around the whole circle.
                    degrees = 270 + rotation + Double(position) * fullCircleSpacing
                }
                let angle = degrees * .pi / 180
                placed.append(PlacedPerson(
                    person: person,
                    point: CGPoint(x: center.x + cos(angle) * ringDistances[ring],
                                   y: center.y + sin(angle) * ringDistances[ring])
                ))
            }
        }
        return placed
    }

    #if DEBUG
    /// Fills the radar with fake people to test the screen on a single device.
    func injectMockPeople() {
        manager.injectMockPeople()
    }
    #endif
}
