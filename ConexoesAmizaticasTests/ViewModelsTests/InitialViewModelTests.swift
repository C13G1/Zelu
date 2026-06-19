//
//  InitialViewModelTests.swift
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
struct InitialViewModelTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: config
        )
        return ModelContext(container)
    }

    // MARK: - setModelContext

    @Test("setModelContext armazena o contexto fornecido")
    func setModelContextStores() throws {
        let context = try makeContext()
        let vm = InitialViewModel()
        vm.setModelContext(modelContext: context)
        #expect(vm.modelContext === context)
    }

    // MARK: - fetchData

    @Test("fetchData não atualiza estado quando não há usuários no store")
    func fetchDataNoOpWithEmptyStore() throws {
        let context = try makeContext()
        let vm = InitialViewModel()
        vm.setModelContext(modelContext: context)

        let originalId = vm.profile.id
        vm.fetchData()

        // Como não há usuários, profile permanece o User() padrão criado no init
        #expect(vm.profile.id == originalId)
        #expect(vm.connectionsWithFriends.isEmpty)
    }

    @Test("fetchData carrega o primeiro usuário e suas conexões")
    func fetchDataLoadsUserAndConnections() throws {
        let context = try makeContext()

        let mainUser = User(name: "Eu", profilePicture: Data(), id: UUID())
        let friend = User(name: "Amigo", profilePicture: Data(), id: UUID())
        let connection = Connection(friend: friend)

        context.insert(mainUser)
        context.insert(friend)
        context.insert(connection)
        try context.save()

        let vm = InitialViewModel()
        vm.setModelContext(modelContext: context)
        vm.fetchData()

        #expect(vm.profile.getName() == "Eu" || vm.profile.getName() == "Amigo") // depende da ordem de inserção
        #expect(vm.connectionsWithFriends.count == 1)
        #expect(vm.connectionsWithFriends.first?.friend?.getName() == "Amigo")
    }

    // MARK: - getFriends

    @Test("getFriends retorna vazio quando não há conexões")
    func getFriendsEmpty() throws {
        let vm = InitialViewModel()
        let context = try makeContext()
        vm.setModelContext(modelContext: context)
        #expect(vm.getFriends().isEmpty)
    }

    @Test("getFriends retorna os amigos de cada conexão")
    func getFriendsReturnsAllConnectedUsers() throws {
        let context = try makeContext()
        let friend1 = User(name: "A", profilePicture: Data(), id: UUID())
        let friend2 = User(name: "B", profilePicture: Data(), id: UUID())
        let mainUser = User(name: "Eu", profilePicture: Data(), id: UUID())
        context.insert(mainUser)
        context.insert(friend1)
        context.insert(friend2)
        context.insert(Connection(friend: friend1))
        context.insert(Connection(friend: friend2))
        try context.save()

        let vm = InitialViewModel()
        vm.setModelContext(modelContext: context)
        vm.fetchData()

        let names = Set(vm.getFriends().map { $0.getName() })
        #expect(names == Set(["A", "B"]))
    }

    // MARK: - convertDataToImage

    @Test("convertDataToImage retorna nil para Data vazio")
    func convertDataToImageNilForEmpty() {
        let vm = InitialViewModel()
        #expect(vm.convertDataToImage(data: Data()) == nil)
    }

    @Test("convertDataToImage retorna UIImage válido para PNG real")
    func convertDataToImageValidPNG() {
        let vm = InitialViewModel()
        // gera um PNG mínimo válido (1x1 transparente)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let pngData = renderer.image { _ in }.pngData()!

        let image = vm.convertDataToImage(data: pngData)
        #expect(image != nil)
    }

    // MARK: - getConnectionByFriend

    @Test("getConnectionByFriend retorna a connection correspondente")
    func getConnectionByFriendFound() throws {
        let context = try makeContext()
        let friend = User(name: "A", profilePicture: Data(), id: UUID())
        let connection = Connection(friend: friend)
        let main = User(name: "Eu", profilePicture: Data(), id: UUID())
        context.insert(main)
        context.insert(friend)
        context.insert(connection)
        try context.save()

        let vm = InitialViewModel()
        vm.setModelContext(modelContext: context)
        vm.fetchData()

        let found = vm.getConnectionByFriend(friend: friend)
        #expect(found?.id == connection.id)
    }

    @Test("getConnectionByFriend retorna nil quando o amigo não existe")
    func getConnectionByFriendNotFound() throws {
        let context = try makeContext()
        let main = User(name: "Eu", profilePicture: Data(), id: UUID())
        context.insert(main)
        try context.save()

        let vm = InitialViewModel()
        vm.setModelContext(modelContext: context)
        vm.fetchData()

        let stranger = User(name: "?", profilePicture: Data(), id: UUID())
        #expect(vm.getConnectionByFriend(friend: stranger) == nil)
    }
}
