//
//  NearbyPeopleView.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 09/06/26.
//
//  The "Pessoas por perto" grid: shows every nearby app user discovered over BLE (photo + name),
//  with the current user's own avatar anchored at the bottom. Tapping a person sends a meeting invite;
//  once both people invite each other, the screen routes into the existing matched/confirm flow.
//

import SwiftUI

struct NearbyPeopleView: View {
    let profile: User

    @State private var manager: NearbyManager
    /// Set when a mutual invite happens — pushes the meeting screen for that friend.
    @State private var matchedFriend: User?

    private let avatarDiameter: CGFloat = 96

    init(profile: User) {
        self.profile = profile
        _manager = State(initialValue: NearbyManager(profile: profile))
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            Color.bleBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                if manager.people.isEmpty {
                    emptyState
                } else {
                    grid
                }

                Spacer(minLength: 12)

                ownAvatar
                    .padding(.bottom, 32)
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
        }
        .onDisappear { manager.stop() }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 28) {
                ForEach(manager.people) { person in
                    Button { manager.toggleInvite(person.user.id) } label: {
                        personCell(person)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
    }

    private func personCell(_ person: NearbyPerson) -> some View {
        VStack(spacing: 8) {
            FriendAvatar(imageData: person.user.profilePicture,
                         diameter: avatarDiameter,
                         strokeColor: ringColor(for: person))
            Text(person.user.name)
                .font(.custom("Sora-Regular", size: 14))
                .foregroundStyle(.white)
                .lineLimit(1)
            inviteBadge(for: person)
        }
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
        } else {
            Text(" ").font(.custom("Sora-Regular", size: 11))   // keeps cells the same height
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView().tint(.white)
            Text("Procurando pessoas por perto...")
                .font(.custom("Sora-Regular", size: 15))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
        }
    }

    private var ownAvatar: some View {
        FriendAvatar(imageData: profile.profilePicture,
                     diameter: 132,
                     strokeColor: .white)
    }
}
