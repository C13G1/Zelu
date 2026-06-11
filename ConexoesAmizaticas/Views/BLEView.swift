//
//  BLEView.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 15/05/26.
//

import SwiftUI
import SwiftData
import UIKit
import Aptabase

/// The proximity-based discovery and pairing screen.
///
/// `BLEView` is the pure UI layer on top of `BLEViewModel`. It composes the avatars, the press-and-hold
/// "vesica/lens" effect and the confirmation overlay, while delegating BLE lifecycle, hold timing,
/// haptics and persistence to the view model.
struct BLEView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var existingConnections: [Connection]

    @State private var viewModel: BLEViewModel
    /// Drives the avatar "wrong passcode" shake when a press is rejected during the meeting cooldown.
    @State private var cooldownShakeCount = 0
    /// Limits the shake/haptic to one per press — `DragGesture.onChanged` fires continuously.
    @State private var didShakeForCooldown = false
    
    private let avatarDiameter: CGFloat = 132

    init(profile: User, presetFriend: User? = nil) {
        _viewModel = State(initialValue: BLEViewModel(profile: profile, presetFriend: presetFriend))
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            if isWhiteMode {
                Color.white.ignoresSafeArea()
            }

            GeometryReader { geo in
                let topY = topAvatarCenterY(in: geo.size)
                let bottomY = bottomAvatarCenterY(in: geo.size)

                ZStack {
                    if viewModel.phase == .holding {
                        Color.clear.ignoresSafeArea()
                    }

                    if shouldShowLens {
                        BLELensLayer(
                            size: geo.size,
                            phase: viewModel.phase,
                            holdProgress: viewModel.holdProgress,
                            avatarDiameter: avatarDiameter,
                            topY: topY,
                            bottomY: bottomY
                        )
                        .allowsHitTesting(false)
                        .zIndex(0)
                        .drawingGroup()
                    }

                    BLEAvatarsLayer(
                        size: geo.size,
                        profileImageData: viewModel.profile.profilePicture,
                        friendImageData: viewModel.friend?.profilePicture,
                        phase: viewModel.phase,
                        avatarDiameter: avatarDiameter,
                        topY: topY,
                        bottomY: bottomY,
                        isDimmed: isMatchedOnCooldown,
                        shakeTrigger: cooldownShakeCount
                    )
                    .zIndex(1)
                    .compositingGroup()

                    if viewModel.isPreset || viewModel.blNotificationManager.accessState == .ready {
                        textLayer(in: geo.size)
                            .allowsHitTesting(viewModel.phase != .holding)
                    }

                    if viewModel.phase == .confirmed {
                        BLEConfirmedOverlay(reveal: viewModel.confirmedReveal)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(holdGesture)
            }

            bluetoothAccessOverlay
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.blNotificationManager.accessState)
        .onAppear {
            viewModel.resetSessionState()
            viewModel.onConfirmed = { dismiss() }
            // Preset mode (came from the nearby grid): the friend is already known, so skip Bluetooth
            // entirely and open straight in the matched state.
            if viewModel.isPreset {
                viewModel.startPreset()
                return
            }
            viewModel.refreshBluetoothAccess()
            // The view model (and its Bluetooth state) is retained across visits, so on a second entry
            // `isBluetoothReady` is already true and never changes — `onChange` won't fire. Kick off a
            // fresh search here when access is already granted, otherwise `onChange` handles the first.
            if viewModel.blNotificationManager.isBluetoothReady {
                startSearching()
            }
        }
        .onChange(of: viewModel.blNotificationManager.isBluetoothReady) { _, isReady in
            guard isReady, !viewModel.isPreset else { return }
            startSearching()
        }
        .onDisappear { viewModel.stopBLE() }
        .onChange(of: viewModel.foundFriend) { _, _ in viewModel.tryTransitionToMatched() }
        .onChange(of: viewModel.friend?.id) { _, _ in viewModel.tryTransitionToMatched() }
        .navigationTitle("Adicionar amigo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(toolbarBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(isWhiteMode ? .light : .dark, for: .navigationBar)
    }

    // MARK: - Bluetooth access overlay

    @ViewBuilder
    private var bluetoothAccessOverlay: some View {
        if viewModel.isPreset {
            EmptyView()   // preset mode doesn't use Bluetooth, so never gate behind its permission
        } else {
            bluetoothAccessOverlayContent
        }
    }

    @ViewBuilder
    private var bluetoothAccessOverlayContent: some View {
        switch viewModel.blNotificationManager.accessState {
        case .needsPermission:
            BLEPermissionOverlay(
                onAuthorize: { viewModel.requestBluetoothPermission() }
            )
            .transition(.opacity)
            .zIndex(10)
        case .unavailable:
            BLEDisabledOverlay(
                onOpenSettings: { openBluetoothSettings() }
            )
            .transition(.opacity)
            .zIndex(10)
        case .ready:
            EmptyView()
        }
    }

    private func openBluetoothSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    /// Logs the screen view and starts a fresh scan/advertise cycle. Triggered both when Bluetooth
    /// first becomes ready and immediately on entry when access was already granted on a previous visit.
    private func startSearching() {
        Aptabase.shared.trackEvent("screen_view", with: ["name": "ble_search"])
        viewModel.startBLE()
    }

    // MARK: - Derived UI state

    private var shouldShowLens: Bool {
        viewModel.holdProgress > 0.001 || viewModel.phase == .holding || viewModel.phase == .confirmed
    }

    /// The saved connection for the currently matched peer, if they're already a friend.
    private var matchedConnection: Connection? {
        viewModel.existingConnection(in: existingConnections)
    }

    /// True when the matched peer is an existing friend met too recently to register again — the cooldown
    /// (`Connection.meetingCooldown`) hasn't elapsed. Checked here, at match time, so the screen shows the
    /// "já se encontraram" copy instead of inviting another registration.
    private var isMatchedOnCooldown: Bool {
        guard let matchedConnection else { return false }
        return !matchedConnection.canRegisterMeeting
    }

    private var isWhiteMode: Bool {
        viewModel.phase == .confirmed || viewModel.showConfirmationBackground
    }

    private var backgroundColor: Color {
        isWhiteMode ? Color.white : Color.bleBackground
    }

    /// While a Bluetooth overlay dims the screen, the navigation bar must match that dimmed tone
    /// (`bleBackground` darkened by the overlay's black 85% scrim) instead of the full-brightness
    /// `bleBackground`, otherwise the bar reads as a lighter band above the overlay.
    private var toolbarBackground: Color {
        if viewModel.blNotificationManager.accessState != .ready {
            return Color.bleOverlayBackground
        }
        return isWhiteMode ? Color.white : Color.bleBackground
    }

    // MARK: - Layout helpers

    /// Mirrors the bottom avatar across the vertical center so both photos sit the same distance from
    /// the middle of the screen (i.e. the friend avatar is as far from the top edge as the user's own
    /// avatar is from the bottom edge).
    private func topAvatarCenterY(in size: CGSize) -> CGFloat {
        size.height - bottomAvatarCenterY(in: size)
    }

    private func bottomAvatarCenterY(in size: CGSize) -> CGFloat {
        size.height - 39 - avatarDiameter / 2
    }

    // MARK: - Text / button layer

    private func textLayer(in size: CGSize) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: topAvatarCenterY(in: size) + avatarDiameter / 2 + 24)

            Group {
                switch viewModel.phase {
                case .searching:
                    searchingText
                case .matched:
                    matchedText
                case .holding, .confirmed:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)

            // On cooldown there's nothing to confirm, so offer "search again" right away instead of
            // after the usual delay.
            if viewModel.phase == .matched, viewModel.showSearchAgainButton || isMatchedOnCooldown {
                searchAgainButton
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .padding(.top, 8)
            }

            Spacer(minLength: 0)
        }
        .frame(width: size.width, height: size.height)
        .animation(.easeInOut(duration: 0.35), value: viewModel.phase)
        .animation(.easeInOut(duration: 0.35), value: viewModel.showSearchAgainButton)
    }

    private var searchingText: some View {
        VStack(spacing: 14) {
            Text("Buscando contatos por perto...")
                .font(.custom("Sora-ExtraBold", size: 26))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            #if DEBUG
            debugButtons
            #endif
        }
        .transition(.opacity)
    }

    @ViewBuilder
    private var matchedText: some View {
        if isMatchedOnCooldown, let friend = viewModel.friend {
            cooldownText(for: friend)
        } else {
            normalMatchedText
        }
    }

    /// Shown when the matched friend was already met within the cooldown window. The second line is
    /// driven by the friend's meeting goal (`Meta.reuniteText`).
    private func cooldownText(for friend: User) -> some View {
        VStack(spacing: 14) {
            Text("Você e \(friend.name) já se encontraram hoje!")
                .font(
                    Font.custom("Sora", size: 28)
                        .weight(.heavy)
                )
                .kerning(0.38)
                .multilineTextAlignment(.center)
                .foregroundColor(Color(red: 1, green: 1, blue: 0.96))
                .frame(width: 306, alignment: .top)

            Text(matchedConnection?.metaManager.meta.reuniteText ?? "")
                .font(Font.custom("Sora", size: 20))
                .kerning(0.38)
                .multilineTextAlignment(.center)
                .foregroundColor(Color(red: 1, green: 1, blue: 0.96))
                .frame(width: 300, alignment: .top)
        }
        .transition(.opacity)
    }

    private var normalMatchedText: some View {
        let friend = viewModel.friend
        let headline = friend.map { friend in
            viewModel.isExistingFriend(in: existingConnections)
                ? "Você e \(friend.name) se encontraram!"
                : "Parece que você e \(friend.name) se encontraram!"
        }

        return VStack(spacing: 14) {
            Text(headline ?? "")
                .font(.custom("Sora-ExtraBold", size: 26))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Text("pressione e segure para confirmar o momento.")
                .font(.custom("Sora-Regular", size: 15))
                .foregroundStyle(Color.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .opacity(friend == nil ? 0 : 1)
        .transition(.opacity)
    }

    private var searchAgainButton: some View {
        Button {
            viewModel.searchAgain()
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Text("procurar por outra pessoa")
                    .font(
                        Font.custom("Sora", size: 14)
                            .weight(.bold)
                    )
                    .kerning(0.38)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color.bleBackground)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 0)
            .frame(minHeight: 34)
            .background(Color.white)
            .cornerRadius(30)
        }
    }

    #if DEBUG
    private var debugButtons: some View {
        VStack() {
            Button("Simular novo amigo (teste)") {
                let fake = User(
                    name: "Amigo Novo",
                    profilePicture: UIImage(named: "defaultPicture")?.jpegData(compressionQuality: 0.8) ?? Data()
                )
                viewModel.simulateMatch(with: fake)
            }

            if let first = existingConnections.first {
                Button("Simular encontro com \(first.friend.name) (teste)") {
                    viewModel.simulateMatch(with: first.friend)
                }
            }
        }
    }
    #endif

    // MARK: - Gestures

    private var holdGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard viewModel.phase == .matched else { return }
                // Already met within the cooldown — block confirming and reject the press with a
                // "wrong passcode" shake plus error haptic; only "search again" is allowed.
                if isMatchedOnCooldown {
                    if !didShakeForCooldown {
                        didShakeForCooldown = true
                        withAnimation(.linear(duration: 0.45)) { cooldownShakeCount += 1 }
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                    }
                    return
                }
                if !viewModel.isHolding {
                    viewModel.isHolding = true
                    viewModel.startHold()
                }
            }
            .onEnded { _ in
                didShakeForCooldown = false
                guard viewModel.isHolding else { return }
                viewModel.isHolding = false
                viewModel.endHold(
                    modelContext: modelContext,
                    existingConnections: existingConnections
                )
            }
    }
}

#Preview {
    NavigationStack {
        BLEView(profile: User())
    }
    .modelContainer(for: AppSchema.models, inMemory: true)
}
