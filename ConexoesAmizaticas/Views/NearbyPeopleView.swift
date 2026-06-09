//
//  NearbyPeopleView.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 09/06/26.
//
//  The "Pessoas por perto" grid: shows every nearby app user discovered over BLE (photo + name),
//  with the current user's own avatar anchored at the bottom. Tapping a person will (Phase 2) send a
//  meeting invite; for now it forwards the selected `User` to `onSelect`.
//

import SwiftUI

struct NearbyPeopleView: View {
    let profile: User
    /// Called when the user taps a discovered person.
    var onSelect: (User) -> Void = { _ in }

    @State private var manager: NearbyManager

    private let avatarDiameter: CGFloat = 96

    init(profile: User, onSelect: @escaping (User) -> Void = { _ in }) {
        self.profile = profile
        self.onSelect = onSelect
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
        .onAppear { manager.start() }
        .onDisappear { manager.stop() }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 28) {
                ForEach(manager.people) { person in
                    Button { onSelect(person.user) } label: {
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
                         strokeColor: .white)
            Text(person.user.name)
                .font(.custom("Sora-Regular", size: 14))
                .foregroundStyle(.white)
                .lineLimit(1)
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
