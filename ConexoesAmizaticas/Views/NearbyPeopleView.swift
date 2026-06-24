//
//  NearbyPeopleView.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 09/06/26.
//

import SwiftUI
import CoreBluetooth

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

            searchHintBanner

            radarOverlay
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

    /// Guides the user to fix whatever is blocking discovery: Local Network permission (without it the
    /// radar finds nobody), Bluetooth permission, or Bluetooth simply being switched off. On the
    /// simulator there is no radio, so nothing is shown and the radar plus its mock people stay testable.
    @ViewBuilder
    private var radarOverlay: some View {
        #if targetEnvironment(simulator)
        EmptyView()
        #else
        if viewModel.localNetworkDenied {
            BLEDisabledOverlay(reason: .localNetworkDenied, onOpenSettings: openSettings)
                .transition(.opacity)
                .zIndex(10)
        } else if viewModel.bluetooth.accessState == .needsPermission {
            BLEPermissionOverlay(onAuthorize: { viewModel.requestBluetoothPermission() })
                .transition(.opacity)
                .zIndex(10)
        } else if viewModel.bluetooth.accessState == .unavailable,
                  viewModel.bluetooth.managerState != .unsupported {
            BLEDisabledOverlay(
                reason: viewModel.bluetooth.managerState == .poweredOff ? .poweredOff : .permissionDenied,
                onOpenSettings: openSettings
            )
            .transition(.opacity)
            .zIndex(10)
        }
        #endif
    }

    /// Soft, dismissable-by-success hint shown when the radar has found nobody for a while. An empty
    /// radar is ambiguous (nobody around, or Bluetooth/Local Network off), so it only suggests what to
    /// check. Tapping opens Settings. Hidden whenever a blocking overlay is already explaining the cause.
    @ViewBuilder
    private var searchHintBanner: some View {
        if viewModel.searchHint {
            VStack {
                Button(action: openSettings) {
                    HStack(spacing: 8) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                        Text("Ninguém por perto? Verifique o Bluetooth e a Rede Local nos Ajustes.")
                            .font(Font.custom("Sora", size: 13).weight(.medium))
                            .multilineTextAlignment(.leading)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                Spacer()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
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
}
