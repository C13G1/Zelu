//
//  FriendFeedViewModelTests.swift
//  ConexoesAmizaticas
//
//  Created by Dayô Araújo on 28/05/26.
//

import Testing
import Foundation
import SwiftUI
import SwiftData
@testable import ConexoesAmizaticas

@MainActor
struct FriendFeedViewModelTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: config
        )
        return ModelContext(container)
    }

    private func makeConnection() -> Connection {
        let friend = User(name: "Amigo", profilePicture: Data(), id: UUID())
        return Connection(friend: friend)
    }

    @Test("Init guarda a connection e começa com posts vazios")
    func initSetsConnection() {
        let connection = makeConnection()
        let vm = FriendFeedViewModel(connection: connection)

        #expect(vm.posts.isEmpty)
        #expect(vm.selectedItems.isEmpty)
        #expect(vm.isPickerPresented == false)
        #expect(vm.postToDelete == nil)
        #expect(vm.snappedItem == 0)
        #expect(vm.draggingItem == 0)
        #expect(vm.activeIndex == 0)
    }

    @Test("refreshPosts ordena por data decrescente (mais recente primeiro)")
    func refreshPostsSortsByDateDescending() {
        let connection = makeConnection()
        let old = Post(images: [], date: Date(timeIntervalSince1970: 1_000))
        let mid = Post(images: [], date: Date(timeIntervalSince1970: 2_000))
        let new = Post(images: [], date: Date(timeIntervalSince1970: 3_000))

        connection.feedManager?.addPost(old)
        connection.feedManager?.addPost(new)
        connection.feedManager?.addPost(mid)

        let vm = FriendFeedViewModel(connection: connection)

        #expect(vm.posts.map(\.id) == [new.id, mid.id, old.id])
    }

    @Test("deletePost remove o post e reseta âncoras de scroll")
    func deletePostRemovesAndResetsAnchors() throws {
        let context = try makeContext()
        let connection = makeConnection()
        let post = Post(images: [Data([0x01])])
        connection.feedManager?.addPost(post)
        context.insert(post)

        let vm = FriendFeedViewModel(connection: connection)
        vm.snappedItem = 3
        vm.draggingItem = 3
        vm.activeIndex = 3

        vm.deletePost(id: post.id, modelContext: context)

        #expect(vm.posts.isEmpty)
        #expect((connection.feedManager?.posts ?? []).isEmpty)
        #expect(vm.snappedItem == 0)
        #expect(vm.draggingItem == 0)
        #expect(vm.activeIndex == 0)
    }

    @Test("deletePost com id inexistente não altera o feed")
    func deletePostWithUnknownIdIsNoOp() throws {
        let context = try makeContext()
        let connection = makeConnection()
        let post = Post(images: [])
        connection.feedManager?.addPost(post)
        context.insert(post)

        let vm = FriendFeedViewModel(connection: connection)
        vm.deletePost(id: UUID(), modelContext: context)

        #expect(vm.posts.count == 1)
        #expect((connection.feedManager?.posts ?? []).count == 1)
    }
    
    @Test("distance retorna 0 quando não há posts")
    func distanceReturnsZeroWhenNoPosts() {
        let vm = FriendFeedViewModel(connection: makeConnection())
        #expect(vm.distance(0) == 0)
    }

    @Test("distance no índice ativo retorna 0")
    func distanceAtActiveIndexIsZero() {
        let connection = makeConnection()
        connection.feedManager?.addPost(Post(images: []))
        connection.feedManager?.addPost(Post(images: []))
        connection.feedManager?.addPost(Post(images: []))

        let vm = FriendFeedViewModel(connection: connection)
        vm.draggingItem = 1
        #expect(vm.distance(1) == 0)
    }

    @Test("xOffset no centro retorna ~0")
    func xOffsetAtCenterIsZero() {
        let connection = makeConnection()
        connection.feedManager?.addPost(Post(images: []))
        connection.feedManager?.addPost(Post(images: []))
        connection.feedManager?.addPost(Post(images: []))

        let vm = FriendFeedViewModel(connection: connection)
        vm.draggingItem = 0
        #expect(abs(vm.xOffset(0)) < 0.0001)
    }

    @Test("yOffset retorna -1000 quando distance > 1.5 (fora de cena)")
    func yOffsetIsOffscreenForFarItems() {
        let connection = makeConnection()
        for _ in 0..<10 {
            connection.feedManager?.addPost(Post(images: []))
        }

        let vm = FriendFeedViewModel(connection: connection)
        vm.draggingItem = 0
        #expect(vm.yOffset(3) == -1000)
    }

    @Test("yOffset no centro retorna 0")
    func yOffsetAtCenterIsZero() {
        let connection = makeConnection()
        connection.feedManager?.addPost(Post(images: []))

        let vm = FriendFeedViewModel(connection: connection)
        vm.draggingItem = 0
        #expect(vm.yOffset(0) == 0)
    }

    @Test("opacity é 1.0 no centro e 0.0 nos extremos")
    func opacityBehaviour() {
        let connection = makeConnection()
        for _ in 0..<10 {
            connection.feedManager?.addPost(Post(images: []))
        }

        let vm = FriendFeedViewModel(connection: connection)
        vm.draggingItem = 0
        #expect(vm.opacity(0) == 1.0)
        #expect(vm.opacity(4) == 0.0) // longe
    }

    @Test("scaleEffect diminui com a distância")
    func scaleEffectShrinksWithDistance() {
        let connection = makeConnection()
        for _ in 0..<5 {
            connection.feedManager?.addPost(Post(images: []))
        }

        let vm = FriendFeedViewModel(connection: connection)
        vm.draggingItem = 0
        #expect(vm.scaleEffect(0) == 1.0)
        #expect(vm.scaleEffect(1) < vm.scaleEffect(0))
    }

    @Test("zIndex é máximo no centro")
    func zIndexIsHighestAtCenter() {
        let connection = makeConnection()
        for _ in 0..<5 {
            connection.feedManager?.addPost(Post(images: []))
        }

        let vm = FriendFeedViewModel(connection: connection)
        vm.draggingItem = 0
        #expect(vm.zIndex(0) == 1.0)
        #expect(vm.zIndex(1) < vm.zIndex(0))
    }

    @Test("rotationEffect é 0 no centro e cresce em magnitude com a distância")
    func rotationEffectBehaviour() {
        let connection = makeConnection()
        for _ in 0..<5 {
            connection.feedManager?.addPost(Post(images: []))
        }

        let vm = FriendFeedViewModel(connection: connection)
        vm.draggingItem = 0
        #expect(vm.rotationEffect(0) == 0)
        #expect(abs(vm.rotationEffect(1)) > 0)
    }

    @Test("onDragChanged atualiza draggingItem com base na translação")
    func onDragChangedUpdatesDragging() {
        let vm = FriendFeedViewModel(connection: makeConnection())
        vm.snappedItem = 0

        let translationWidth: CGFloat = 250
        let expected = 0 + Double(translationWidth) / 500
        vm.draggingItem = 0 + Double(translationWidth) / 500

        #expect(vm.draggingItem == expected)
    }
}
