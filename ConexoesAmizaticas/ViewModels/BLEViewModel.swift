//
//  BLEViewModel.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 15/05/26.
//

import Foundation
import SwiftUI
import SwiftData
import UIKit
import CoreBluetooth
import Aptabase

/// Coordinates the proximity-based pairing experience between two nearby users.
///
/// `BLEViewModel` drives the entire interaction loop of `BLEView`: it owns the underlying `BLEManager`,
/// tracks the visual state machine (`searching → matched → holding → confirmed`), runs the
/// "press-and-hold" timer with escalating haptic feedback, and finally persists the encounter to SwiftData.
@Observable
class BLEViewModel {

    /// Represents the lifecycle of the pairing screen.
    enum Phase {
        case searching
        case matched
        case holding
        case confirmed
    }

    private(set) var phase: Phase = .searching
    private(set) var friend: User?
    private(set) var foundFriend: Bool = false

    private(set) var holdProgress: CGFloat = 0
    private(set) var canConfirm: Bool = false
    private(set) var showSearchAgainButton: Bool = false
    private(set) var confirmedReveal: CGFloat = 0
    private(set) var showConfirmationBackground: Bool = false

    /// True when the confirmed encounter fell inside the 24h cooldown, so the confirmation overlay
    /// shows "Vocês já se encontraram hoje" instead of registering a new scoring meeting.
    private(set) var confirmedOnCooldown: Bool = false

    /// Whether the user is currently pressing the screen during the matched phase.
    var isHolding: Bool = false

    /// The profile of the device owner, broadcasted to nearby peers.
    let profile: User

    /// Duration the user must hold the screen to confirm the encounter (seconds).
    let holdDuration: Double = 1.0

    /// Invoked once the persistence flow completes and the view should be dismissed.
    var onConfirmed: (() -> Void)?

    private var bleManager: BLEManager?
    private var holdTimer: Timer?
    var blNotificationManager: BluetoothNotificationManager

    init(profile: User) {
        self.profile = profile
        self.blNotificationManager = BluetoothNotificationManager()
    }

    // MARK: - BLE lifecycle

    /// Boots a fresh `BLEManager` and starts both scanning and advertising.
    /// Re-starts the existing manager instead of recreating it if one is already live.
    func startBLE() {
        if let bleManager {
            bleManager.startBLE()
            return
        }
        let manager = BLEManager(profile: profile)
        manager.onConnectionOpened = { [weak self] in
            self?.foundFriend = true
        }
        manager.onFriendFound = { [weak self] friend in
            self?.friend = friend
        }
        self.bleManager = manager
        manager.startBLE()
    }

    /// Tears down active connections and timers. Safe to call multiple times.
    func stopBLE() {
        bleManager?.stopBLE()
        holdTimer?.invalidate()
        holdTimer = nil
    }

    // MARK: - Phase transitions

    /// Transitions to the `.matched` phase once the friend profile has fully arrived,
    /// and schedules the "search again" affordance to appear after a short delay.
    func tryTransitionToMatched() {
        guard foundFriend, friend != nil, phase == .searching else { return }
        showSearchAgainButton = false
        withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) {
            phase = .matched
        }
        let targetFriendID = friend?.id
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard phase == .matched, friend?.id == targetFriendID else { return }
            withAnimation(.easeOut(duration: 0.4)) {
                showSearchAgainButton = true
            }
        }
    }

    /// Resets the visual state machine back to `.searching` so a fresh entry to the screen never
    /// shows a stale `.confirmed`/`.matched` state left over from a previous session (the destination
    /// view model is retained by the eager `NavigationLink` in the tab bar).
    func resetSessionState() {
        foundFriend = false
        friend = nil
        showSearchAgainButton = false
        canConfirm = false
        showConfirmationBackground = false
        confirmedReveal = 0
        confirmedOnCooldown = false
        holdProgress = 0
        isHolding = false
        phase = .searching
    }

    /// Resets the entire screen state so the user can hunt for another nearby peer.
    func searchAgain() {
        foundFriend = false
        friend = nil
        showSearchAgainButton = false
        canConfirm = false
        showConfirmationBackground = false
        withAnimation(.easeInOut(duration: 0.35)) {
            phase = .searching
            holdProgress = 0
        }
        bleManager?.startBLE()
    }

    // MARK: - Hold timer (progress + haptics)

    /// Starts the progress timer that fills the lens visualization while delivering escalating haptic feedback.
    func startHold() {
        holdTimer?.invalidate()
        canConfirm = false
        showConfirmationBackground = false
        withAnimation(.easeInOut(duration: 0.18)) {
            phase = .holding
        }

        let steps = 60
        let stepInterval = holdDuration / Double(steps)
        var current = 0

        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.prepare()

        holdTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            guard self.isHolding else {
                timer.invalidate()
                return
            }
            current += 1
            let progress = min(1.0, CGFloat(current) / CGFloat(steps))
            DispatchQueue.main.async {
                self.holdProgress = progress
            }

            if current >= steps {
                timer.invalidate()
                self.canConfirm = true
                // Haptic pro usuário soltar
            } else {
                let intensity = 0.2 + 0.8 * progress
                impact.impactOccurred(intensity: intensity)
            }
        }
    }

    /// Resolves the hold gesture: confirms the encounter when the timer completed, or rolls back to the matched state.
    /// - Parameters:
    ///   - modelContext: The SwiftData context used to persist a confirmed encounter.
    ///   - existingConnections: The current list of saved connections, used to detect duplicates.
    func endHold(modelContext: ModelContext, existingConnections: [Connection]) {
        holdTimer?.invalidate()
        holdTimer = nil

        if canConfirm, let friend = friend {
            // Decide the cooldown state up front so the confirmation overlay can show the right copy
            // the instant it appears (confirmFriend, which scores, only runs ~1.9s later).
            let existing = existingConnections.first { $0.friend.id == friend.id }
            confirmedOnCooldown = existing.map { !$0.canRegisterMeeting } ?? false

            let success = UINotificationFeedbackGenerator()
            success.notificationOccurred(.success)

            showConfirmationBackground = true
            withAnimation(.easeOut(duration: 0.45)) {
                phase = .confirmed
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.78).delay(0.05)) {
                confirmedReveal = 1
            }

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1900))
                confirmFriend(friend, modelContext: modelContext, existingConnections: existingConnections)
            }
        } else {
            let light = UIImpactFeedbackGenerator(style: .light)
            light.impactOccurred()

            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                phase = .matched
                holdProgress = 0
            }
        }
        canConfirm = false
    }

    // MARK: - Connection lookup

    /// Returns the saved connection that matches the discovered peer, if any.
    func existingConnection(in connections: [Connection]) -> Connection? {
        guard let friend = friend else { return nil }
        return connections.first { $0.friend.id == friend.id }
    }

    /// Indicates whether the discovered peer is already saved as a friend.
    func isExistingFriend(in connections: [Connection]) -> Bool {
        existingConnection(in: connections) != nil
    }

    // MARK: - Persistence

    /// Persists the encounter to SwiftData: updates the `lastMet` and score for existing metaManagers,
    /// or bootstraps a brand-new `Connection` for fresh contacts.
    private func confirmFriend(_ friend: User, modelContext: ModelContext, existingConnections: [Connection]) {
        guard friend.id != profile.id else {
            onConfirmed?()
            return
        }
        let connection: Connection
        if let existing = existingConnections.first(where: { $0.friend.id == friend.id }) {
            // Only score and stamp the meeting once the 24h cooldown has elapsed, so repeated
            // encounters on the same day still confirm visually but cannot level the friendship up.
            if existing.canRegisterMeeting {
                existing.lastMet = Date.now
                existing.metaManager.addOrSubtractScore(10)
                Aptabase.shared.trackEvent("meeting_registered", with: [
                    "relationship_state": existing.metaManager.currentRelationshipState.rawValue,
                    "score": existing.metaManager.score
                ])
            } else {
                Aptabase.shared.trackEvent("meeting_on_cooldown", with: [
                    "relationship_state": existing.metaManager.currentRelationshipState.rawValue,
                    "score": existing.metaManager.score
                ])
            }
            connection = existing
        } else {
            modelContext.insert(friend)
            let newConnection = Connection(friend: friend, lastMet: .now)
            modelContext.insert(newConnection)
            connection = newConnection
            Aptabase.shared.trackEvent("friend_added")
        }
        try? modelContext.save()
        NotificationManager.scheduleMetaReminder(for: connection)
        NotificationCenter.default.post(name: .meetingConfirmed, object: nil)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            onConfirmed?()
        }
    }
    
    func requestBluetoothPermission(){
        blNotificationManager.requestBluetoothPermission()
    }

    /// Re-checks Bluetooth access on screen entry. When access was already decided (authorized or
    /// denied) it spins up the central manager to observe the live power state and start BLE; when
    /// it is still undetermined it waits for the user to tap "Autorizar" in the permission overlay.
    func refreshBluetoothAccess() {
        blNotificationManager.refreshAuthorization()
        if blNotificationManager.authorizationState != .notDetermined {
            blNotificationManager.requestBluetoothPermission()
        }
    }
    
    func centralManagerDidUpdateState(){
        blNotificationManager.requestBluetoothPermission()
    }

    #if DEBUG
    /// Test hook that simulates a found peer without going through Bluetooth discovery.
    func simulateMatch(with friend: User) {
        self.friend = friend
        self.foundFriend = true
    }
    #endif
}
