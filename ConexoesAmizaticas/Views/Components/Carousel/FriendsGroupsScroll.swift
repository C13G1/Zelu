//
//  FriendsGroupsScroll.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 12/06/26.
//

import SwiftUI
import SwiftData

/// A 3D-styled, interactive carousel for browsing a connection's memory feed.
///
/// `PictureScroll` listens to horizontal drag gestures and uses trigonometric functions provided by `FriendFeedViewModel`
/// to calculate depth (`zIndex`), scale, and opacity for each `GalleryFrame`. This creates the illusion of
/// photos wrapped around a rotating virtual cylinder.
struct FriendsGroupsScroll: View {
    var viewModel: FriendsGroupsViewModel
    var arrowWidth = UIScreen.main.bounds.width * 0.09
    var arrowHeight = UIScreen.main.bounds.height * 0.03
    var frameWidth = UIScreen.main.bounds.width * 0.45
    var frameHeight = UIScreen.main.bounds.height * 0.25
    
    var body: some View {
        ZStack {
            if viewModel.friendsGroups.isEmpty {
                // Empty state indicating where photos will appear once uploaded.
                Circle()
                    .foregroundStyle(.gray.opacity(0.5))
                    .frame(width: frameWidth, height: frameHeight)
            } else {
                ForEach(Array(viewModel.friendsGroups.enumerated()), id: \.element.id) { index, group in
                    FriendsGroupsFrame(
                        group: group,
                        isCentered: viewModel.isCentered(index),
                        onFocus: { viewModel.focus(index) }
                    )
                        .zIndex(viewModel.zIndex(index))
                        .offset(
                            x: viewModel.xOffset(index),
                            y: viewModel.yOffset(index)
                        )
                        .opacity(viewModel.opacity(index))
                }
            }
        }
        // Fill the whole carousel area and make the empty space hit-testable so the drag works
        // anywhere on the screen, not only directly on a card.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        // Attaches the physics-based drag tracking to the entire scroll area.
        .gesture(
            DragGesture()
                .onChanged { value in
                    viewModel.onDragChanged(value: value)
                }
                .onEnded { value in
                    viewModel.onDragEnded(value: value)
                }
        )
    }
}
#Preview {
    PreviewWrapper()
}

private struct PreviewWrapper: View {
    let container: ModelContainer
    let mockViewModel: FriendsGroupsViewModel
    
    init() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: FriendGroup.self, configurations: config)
        
        // 2. Cria os dados falsos (Mocks)
        let mockGroup1 = FriendGroup(name: "", image: Data(), connections: [])
        let mockGroup2 = FriendGroup(name: "Futebol de Quinta", image: Data(), connections: [])
        let mockGroup3 = FriendGroup(name: "Clube do Livro", image: Data(), connections: [])
        let mockGroup4 = FriendGroup(name: "Clube do Livro", image: Data(), connections: [])
        
        // 3. Insere no banco de dados da memória
        container.mainContext.insert(mockGroup1)
        container.mainContext.insert(mockGroup2)
        container.mainContext.insert(mockGroup3)
        container.mainContext.insert(mockGroup4)
        
        // 4. Prepara o ViewModel
        mockViewModel = FriendsGroupsViewModel()
        mockViewModel.friendsGroups = [mockGroup1, mockGroup2, mockGroup3]
    }
    
    var body: some View {
        // 5. Retorna a sua View original atrelada ao container
        FriendsGroupsScroll(viewModel: mockViewModel)
            .modelContainer(container)
    }
}
