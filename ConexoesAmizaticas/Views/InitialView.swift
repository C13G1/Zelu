//
//  InitialView.swift
//  ConexoesAmizaticas
//
//  Created by Dayô Araújo on 25/05/26.
//


import SwiftUI
import UIKit
import CoreData
import _SpriteKit_SwiftUI
import _SwiftData_SwiftUI


// MARK: - InitialView


/// The primary interactive workspace of the application.
///
/// `InitialView` is a hybrid component that overlays standard SwiftUI navigation and toolbars onto
/// the custom SpriteKit simulation (`FriendsScene`). It is responsible for bridging touches from the
/// 2D physics world into standard SwiftUI navigation paths.
struct InitialView: View {
    @Environment(\.modelContext) private var modelContext
    @State var vm: InitialViewModel = InitialViewModel()
    @State private var showVacuoView: Bool = false
    @State var navigation: NavigationPath = NavigationPath()
    
    @Query private var connections: [Connection]
    @Query private var users: [User]

    @AppStorage("ownUserID") private var ownUserID = ""

    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    @State private var scene: FriendsScene = {
        let s = FriendsScene(size: UIScreen.main.bounds.size, connections: Set(), sceneType: .initial)
        s.scaleMode = .aspectFill
        return s
    }()
    
    /// Resolves which `User` is the account owner and points `vm.profile` at it.
    ///
    /// Order of trust: (1) the synced `isOwner` flag — authoritative and import-order independent;
    /// (2) recovery for stores created before the flag existed, promoting the profile that is no one's
    /// friend. Recovery only acts when the choice is unambiguous, so a friend whose `Connection` has not
    /// finished importing is never mistaken for the owner. Runs again on every users/connections change.
    private func syncOwner() {
        if let owner = User.owner(in: users) {
            // Converge duplicate owners (onboarded on several devices before syncing) to one stable profile.
            let extras = users.filter { $0.isOwner && $0.id != owner.id }
            if !extras.isEmpty {
                extras.forEach { $0.isOwner = false }
                try? modelContext.save()
            }
            adoptOwner(owner)
            return
        }

        let nonFriends = users.filter { $0.connection == nil }
        if let saved = nonFriends.first(where: { $0.id.uuidString == ownUserID }) {
            promoteToOwner(saved)
        } else if nonFriends.count == 1 {
            promoteToOwner(nonFriends[0])
        } else if let stable = nonFriends.min(by: { $0.id.uuidString < $1.id.uuidString }) {
            // Ambiguous (legacy duplicates or mid-sync): show a stable choice so the profile always loads,
            // but don't lock in the flag until the data settles to a single non-friend.
            vm.profile = stable
        }
    }

    /// Backfills the synced owner flag on a legacy/unflagged profile, then adopts it.
    private func promoteToOwner(_ user: User) {
        user.isOwner = true
        try? modelContext.save()
        adoptOwner(user)
    }

    private func adoptOwner(_ user: User) {
        if ownUserID != user.id.uuidString { ownUserID = user.id.uuidString }
        vm.profile = user
    }

    var body: some View {
        NavigationStack(path: $navigation) {
            ZStack {
                SpriteView(scene: scene, debugOptions: [])
                    .frame(height: height)
                
                ZStack {
                    ToolBar(vm: $vm)
                        .padding(.bottom, width * 2.28)
                    
                    if connections.isEmpty {
                        ZStack {
                            VStack(spacing: 20) {
                                Text("Bem Vindo Ao Zelu")
                                    .font(.custom("Bolota", size: 32))
                                
                                Text("adicione seus amigos\npara iniciar")
                                    .font(.custom("Sora-Regular", size: 20))
                                    .multilineTextAlignment(.center)
                                    .frame(width: width * 0.6)
                            }
                            .foregroundStyle(.addFriendsText)
                            
                            Image("roundArrowAddFriends")
                                .resizable()
                                .frame(width: width * 0.22, height: height * 0.1)
                                .padding(.leading, width * 0.6)
                                .padding(.top, height * 0.2)
                        }
                        .padding(.top, height * 0.3)
                    }
                }
                TabBar(viewModel: $vm, navigation: $navigation, user: vm.profile)
                    .padding(.top, width * 2.15)
                    .navigationDestination(for: Connection.self) { value in
                        FriendsProfileView(connection: value)
                    }
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case .search(let filterConnections):
                            SearchView(viewModel: $vm, navigation: $navigation, connectionsFilter: filterConnections)
                        case .ble:
                            BLEView(profile: vm.profile)
                        case .setMeta(let friendVM):
                            SetMetaView(viewModel: friendVM)
                        case .groupDetails(let group):
                            GroupDetails(navigation: $navigation, group: group)
                        case .editGroup(let group):
                            EditGroupView(group: group, navigation: $navigation)
                        }
                    }
                    .navigationDestination(isPresented: $showVacuoView) {
                        VacuoView()
                    }
            }
        }
        .onAppear {
            vm.setModelContext(modelContext: modelContext)
            vm.fetchData()
            vm.bootstrap(connections: connections)
            scene.onFriendTapped = { connection in
                DispatchQueue.main.async {
                    navigation.append(connection)
                }
            }
            scene.onSpiralTapped = {
                showVacuoView = true
            }
            syncOwner()
        }
        .onChange(of: users) {
            syncOwner()
        }
        .onChange(of: connections, initial: true) { _, newConnections in
            syncOwner()
            scene.updateConnections(receivedConnections: Set(newConnections.filter { !$0.inVacuo }))
            scene.updateNodeVisuals()
        }
        .onReceive(NotificationCenter.default.publisher(for: .meetingConfirmed)) { _ in
            scene.updateConnections(receivedConnections: Set(connections.filter { !$0.inVacuo }))
            scene.updateNodeVisuals()
        }
        .onReceive(NotificationCenter.default.publisher(for: .friendProfileUpdated)) { _ in
            scene.updateNodeVisuals()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)) { _ in
            // CloudKit imports records incrementally — friend photos often arrive after the first paint.
            // Re-sync the scene and re-pull textures so avatars fill in without needing an app relaunch.
            syncOwner()
            scene.updateConnections(receivedConnections: Set(connections.filter { !$0.inVacuo }))
            scene.updateNodeVisuals()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .background(.lightBackground)
    }
}


#Preview {
    InitialView()
}
 
