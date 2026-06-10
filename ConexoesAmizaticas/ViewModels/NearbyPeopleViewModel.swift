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

    /// Positions available on each ring, in degrees (270 = straight up). Outer rings use a
    /// narrower arc so the avatars never leave the sides of the screen.
    private static let angleSlots: [[Double]] = [
        [240, 300, 270, 215, 325],
        [256, 284, 270, 242, 298],
        [263, 277, 270]
    ]

    /// Size of each ring, as a fraction of the space between the own avatar and the top.
    private static let radiusFractions: [CGFloat] = [0.40, 0.67, 0.94]

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

    /// The radius of each ring, where `field` is the distance between the center of the own
    /// avatar and the top of the people area.
    func ringRadii(field: CGFloat) -> [CGFloat] {
        Self.radiusFractions.map { $0 * field }
    }

    /// Gives every person a position on the radar. The closest people go to the inner ring and
    /// each ring fills its positions in order. When a ring is full, the person goes to the next one.
    func placedPeople(center: CGPoint, radii: [CGFloat]) -> [PlacedPerson] {
        let people = manager.people
        var slotCursor = [0, 0, 0]

        return people.enumerated().map { index, person in
            var ring = people.count == 1 ? 0 : index * 3 / people.count
            while slotCursor[ring] >= Self.angleSlots[ring].count {
                ring = (ring + 1) % 3
            }
            let angle = Self.angleSlots[ring][slotCursor[ring]] * .pi / 180
            slotCursor[ring] += 1

            return PlacedPerson(
                person: person,
                point: CGPoint(x: center.x + cos(angle) * radii[ring],
                               y: center.y + sin(angle) * radii[ring])
            )
        }
    }

    #if DEBUG
    /// Fills the radar with fake people to test the screen on a single device.
    func injectMockPeople() {
        manager.injectMockPeople()
    }
    #endif
}
