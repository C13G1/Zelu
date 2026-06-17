//
//  InitialView.swift
//  ConexoesAmizaticas
//
//  Created by Dayô Araújo on 25/05/26.
//

import SwiftUI
import UIKit
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
    
    var currentUser: User { users.first ?? User() }
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    @State private var scene: FriendsScene = {
        let s = FriendsScene(size: UIScreen.main.bounds.size, connections: Set(), sceneType: .initial)
        s.scaleMode = .aspectFill
        return s
    }()
    
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
                        case .search:
                            SearchView(viewModel: $vm, navigation: $navigation)
                        case .ble:
                            BLEView(profile: vm.profile)
                        case .setMeta(let friendVM):
                            SetMetaView(viewModel: friendVM)
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
            if users.first != nil {
                vm.profile = currentUser
            }
        }
        .onChange(of: users) {
            vm.profile = currentUser
        }
        .onChange(of: connections, initial: true) { _, newConnections in
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .background(.lightBackground)
    }
}

#Preview {
    InitialView()
}
