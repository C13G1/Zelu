//
//  NearbyPeopleView.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 09/06/26.
//
//  The "Pessoas por perto" radar: the current user's avatar anchors the bottom of the screen and
//  three concentric rings of dots orbit around it. Every nearby app user discovered over BLE sits
//  on one of the rings — the closer the person is in real life (NearbyPerson.proximity), the inner
//  the ring. Tapping a person sends a meeting invite; once both people invite each other, the
//  screen routes into the existing matched/confirm flow.
//

import SwiftUI

struct NearbyPeopleView: View {
    let profile: User

    @State private var manager: NearbyManager
    /// Set when a mutual invite happens — pushes the meeting screen for that friend.
    @State private var matchedFriend: User?

    /// Angle slots per ring (degrees, 270 = straight up). Outer rings get narrower arcs so the
    /// avatars never leave the screen sides.
    private static let angleSlots: [[Double]] = [
        [240, 300, 270, 215, 325],
        [256, 284, 270, 242, 298],
        [263, 277, 270]
    ]
    /// Ring radii as fractions of the orbit field (own avatar center → top of the people area).
    private static let radiusFractions: [CGFloat] = [0.40, 0.67, 0.94]

    private let avatarDiameter: CGFloat = 64

    init(profile: User) {
        self.profile = profile
        _manager = State(initialValue: NearbyManager(profile: profile))
    }

    var body: some View {
        ZStack {
            Color.bleBackground.ignoresSafeArea()

            GeometryReader { geo in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height - 92)
                let field = center.y - 96
                let radii = Self.radiusFractions.map { $0 * field }

                NearbyOrbitRings(center: center, radii: radii)

                ForEach(placedPeople(center: center, radii: radii), id: \.person.id) { placed in
                    Button { manager.toggleInvite(placed.person.user.id) } label: {
                        personCell(placed.person)
                    }
                    .buttonStyle(.plain)
                    .position(placed.point)
                    .animation(.spring(duration: 0.5), value: manager.people.map(\.id))
                }

                FriendAvatar(imageData: profile.profilePicture,
                             diameter: 150,
                             strokeColor: .white,
                             strokeWidth: 6)
                    .position(center)
            }

            if manager.people.isEmpty {
                emptyState
            }
        }
        .navigationTitle("Pessoas por perto")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.bleBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        #if DEBUG
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Mock") { manager.injectMockPeople() }
            }
        }
        #endif
        .navigationDestination(isPresented: Binding(
            get: { matchedFriend != nil },
            set: { presented in
                if !presented {
                    matchedFriend = nil
                    manager.resume()   // back from the meeting — become discoverable again
                }
            }
        )) {
            if let matchedFriend {
                BLEView(profile: profile, presetFriend: matchedFriend)
            }
        }
        .onAppear {
            manager.onMutualMatch = { friend in
                matchedFriend = friend
                manager.pauseForMeeting()   // vanish from other grids while meeting
            }
            manager.start()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-mockNearby") {
                manager.injectMockPeople()
            }
            #endif
        }
        .onDisappear { manager.stop() }
    }

    private struct PlacedPerson {
        let person: NearbyPerson
        let point: CGPoint
    }

    /// Distributes people (already sorted closest-first by the manager) over the three rings and
    /// resolves each one to a screen position on its ring.
    private func placedPeople(center: CGPoint, radii: [CGFloat]) -> [PlacedPerson] {
        let people = manager.people
        var slotCursor = [0, 0, 0]

        return people.enumerated().map { index, person in
            var ring = people.count == 1 ? 0 : index * 3 / people.count
            // ring full — spill to the nearest ring with a free slot
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

    private func personCell(_ person: NearbyPerson) -> some View {
        VStack(spacing: 6) {
            FriendAvatar(imageData: person.user.profilePicture,
                         diameter: avatarDiameter,
                         strokeColor: ringColor(for: person))
            Text(person.user.name)
                .font(.custom("Sora-Regular", size: 13))
                .foregroundStyle(.white)
                .lineLimit(1)
            inviteBadge(for: person)
        }
        .frame(width: 120)
        .opacity(person.sentInvite || person.receivedInvite ? 1 : 0.95)
    }

    /// Green = they want to meet you; white-ish dim = invite sent and pending; white = idle.
    private func ringColor(for person: NearbyPerson) -> Color {
        if person.receivedInvite { return .green }
        if person.sentInvite { return .white.opacity(0.5) }
        return .white
    }

    @ViewBuilder
    private func inviteBadge(for person: NearbyPerson) -> some View {
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

    private var emptyState: some View {
        VStack(spacing: 12) {
            ProgressView().tint(.white)
            Text("Procurando pessoas por perto...")
                .font(.custom("Sora-Regular", size: 15))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.bottom, 180)
    }
}
