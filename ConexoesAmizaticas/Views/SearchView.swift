//
//  SearchView.swift
//  ConexoesAmizaticas
//
//  Created by Dayô Araújo on 25/05/26.
//

import SwiftData
import SwiftUI
import SpriteKit

/// A specialized exploratory view utilizing a text-based filter over the physical simulation.
///
/// `SearchView` is the presentational shell over `SearchViewModel`. It pairs the SwiftUI `.searchable`
/// modifier with the `FriendsScene` background, mirroring the SwiftData query into the view model so the
/// scene can react to the typed query in real time.
struct SearchView: View {
    @Binding var viewModel: InitialViewModel
    @Binding var navigation: NavigationPath
    @State private var searchViewModel = SearchViewModel()

    @Query private var connections: [Connection]
    @Query private var users: [User]

    @State private var scene: FriendsScene = {
        let scene = FriendsScene(size: UIScreen.main.bounds.size, connections: Set(), sceneType: .search)
        scene.scaleMode = .aspectFill
        return scene
    }()

    var body: some View {
        @Bindable var bindable = searchViewModel

        ZStack {
            SpriteView(scene: scene)
                .ignoresSafeArea()
                .tag("searchView")

            if searchViewModel.hasEmptyResults {
                Text("Você não tem nenhum contato com esse nome")
                    .font(.custom("Sora-Regular", size: 24))
                    .frame(width: UIScreen.main.bounds.width * 0.8)
                    .multilineTextAlignment(.center)
            }
        }
        .background(Color.lightBackground)
        .searchable(
            text: $bindable.searchText,
            placement: .navigationBarDrawer(displayMode: .always)
        )
        .navigationDestination(for: Connection.self) { value in
            FriendsProfileView(connection: value)
        }
        .onAppear {
            scene.updateConnections(receivedConnections: Set(connections))
            scene.onFriendTapped = { connection in
                // ✅ Appenda no path do InitialView, não no navPath local
                DispatchQueue.main.async {
                    navigation.append(connection)
                }
            }
        }
        .onChange(of: connections, initial: true) { _, newConnections in
            searchViewModel.connections = newConnections
            scene.updateConnections(receivedConnections: Set(newConnections))
            scene.updateNodeVisuals()
        }
        .onChange(of: searchViewModel.searchText) { _, newValue in
            scene.filterByName(newValue)
        }
    }
}

#Preview {
    @Previewable @State var viewModel = InitialViewModel()
    @Previewable @State var navigation = NavigationPath()
    NavigationStack {
        SearchView(viewModel: $viewModel, navigation: $navigation)
    }
    .modelContainer(for: AppSchema.models)
}
