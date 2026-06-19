//
//  ContentView.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 14/05/26.
//

import SwiftUI
import SwiftData

/// The root routing component of the application.
///
/// `ContentView` determines the initial presentation state based on the existence of a user profile
/// in the local SwiftData container. It seamlessly bridges the user into the `OnboardingView` on first launch
/// or directs them to the main `InitialView` dashboard on subsequent sessions.
struct ContentView: View {
    // Identifies the owner profile so it survives CloudKit's nondeterministic import order, and gates
    // onboarding without depending on the async `users` query (which is empty mid-sync and caused a flash).
    @AppStorage("ownUserID") private var ownUserID = ""
    // Set the instant the user deletes their account so routing snaps to onboarding without waiting on the
    // CloudKit delete to flush the `users` query. Cleared when a new profile is created.
    @AppStorage("accountDeleted") private var accountDeleted = false
    @Query private var users: [User]

    @State private var sync = CloudKitSyncMonitor()
    /// Safety net so a stalled/offline sync never traps the user on the loading screen forever.
    @State private var syncTimedOut = false

    /// We already have a profile (marker set, or any user present locally), so go straight to the app.
    private var hasProfile: Bool { !ownUserID.isEmpty || !users.isEmpty }

    /// Show onboarding once we know nothing is worth recovering: either the account was just deleted, or
    /// sync finished (or timed out) with no profile present.
    private var shouldOnboard: Bool {
        if accountDeleted { return true }
        return !hasProfile && (sync.hasFinishedInitialSync || syncTimedOut)
    }

    /// Still checking CloudKit for existing data — keep the loading screen up instead of flashing onboarding.
    private var isCheckingCloud: Bool { !hasProfile && !shouldOnboard }

    var body: some View {
        ZStack{
            // Rebuild from scratch when the account is deleted so the old profile, friend nodes and scene
            // don't bleed through the translucent onboarding overlay — the background resets to a clean
            // first-launch welcome.
            InitialView()
                .id(accountDeleted)

            if isCheckingCloud {
                LoadingView()
            } else if shouldOnboard {
                Rectangle()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(0.9)
                    .ignoresSafeArea(.all)
                OnboardingView()
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(8))
            syncTimedOut = true
        }
    }
}

/// Lightweight splash shown while CloudKit reports whether existing data is on its way down.
struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.lightBackground.ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                Text("Carregando seus dados...")
                    .font(.custom("Sora-Regular", size: 16))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
