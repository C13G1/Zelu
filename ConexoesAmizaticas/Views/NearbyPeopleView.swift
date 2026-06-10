//
//  NearbyPeopleView.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 09/06/26.
//

import SwiftUI

/// The user's own avatar sits at the bottom of the screen and three rings of dots orbit around it.
/// Each nearby person appears on one of the rings: the closer the person is in real life, the
/// closer the ring. Tapping a person sends a meeting invite and, when both people invite each
/// other, the screen opens the meeting confirmation.
struct NearbyPeopleView: View {
    @State private var viewModel: NearbyPeopleViewModel

    /// How much the user has spun the rings, in degrees. Dragging sideways changes it.
    @State private var rotation: Double = 0
    /// The rotation at the moment the current drag started.
    @State private var rotationAtDragStart: Double?

    /// Distance from the bottom of the screen to the center of the own avatar.
    private let ownAvatarOffset: CGFloat = 92
    /// Space kept clear at the top so people on the outer ring stay fully visible.
    private let topInset: CGFloat = 96

    init(profile: User) {
        _viewModel = State(initialValue: NearbyPeopleViewModel(profile: profile))
    }

    var body: some View {
        ZStack {
            Color.bleBackground.ignoresSafeArea()

            GeometryReader { geo in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height - ownAvatarOffset)
                let ringDistances = viewModel.ringDistances(field: center.y - topInset)
                let placedPeople = viewModel.placedPeople(center: center,
                                                          ringDistances: ringDistances,
                                                          rotation: rotation)

                NearbyOrbitRings(center: center, ringDistances: ringDistances)

                ForEach(placedPeople, id: \.person.id) { placed in
                    NearbyPersonCell(person: placed.person) {
                        viewModel.toggleInvite(for: placed.person)
                    }
                    .position(placed.point)
                    .animation(.spring(duration: 0.5), value: viewModel.people.map(\.id))
                }

                FriendAvatar(imageData: viewModel.profile.profilePicture,
                             diameter: 150,
                             strokeColor: .white,
                             strokeWidth: 6)
                    .position(center)
            }

            if viewModel.people.isEmpty {
                emptyState
            }
        }
        .gesture(spinGesture)
        .navigationTitle("Pessoas por perto")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.bleBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        #if DEBUG
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Mock") { viewModel.injectMockPeople() }
            }
        }
        #endif
        .navigationDestination(isPresented: showMeetingScreen) {
            if let friend = viewModel.matchedFriend {
                BLEView(profile: viewModel.profile, presetFriend: friend)
            }
        }
        .onAppear {
            viewModel.start()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-mockNearby") {
                viewModel.injectMockPeople()
            }
            #endif
        }
        .onDisappear { viewModel.stop() }
    }

    /// Spins the rings like a dial: dragging sideways rotates everyone around the own avatar, so
    /// people outside the screen can be brought into view. Taps still reach the person cells.
    private var spinGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                if rotationAtDragStart == nil { rotationAtDragStart = rotation }
                rotation = (rotationAtDragStart ?? rotation) + value.translation.width * 0.35
            }
            .onEnded { _ in rotationAtDragStart = nil }
    }

    /// Shows the meeting screen while there is a matched friend. Resumes the radar on the way back.
    private var showMeetingScreen: Binding<Bool> {
        Binding(
            get: { viewModel.matchedFriend != nil },
            set: { presented in
                if !presented { viewModel.resumeAfterMeeting() }
            }
        )
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
