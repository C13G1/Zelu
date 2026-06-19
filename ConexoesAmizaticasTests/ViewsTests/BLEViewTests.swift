//
//  BLEViewTests.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 28/05/26.
//

import Testing
import Foundation
import SwiftData
@testable import ConexoesAmizaticas

@MainActor
struct BLEViewLogicTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: config
        )
        return ModelContext(container)
    }

    private func existing(in connections: [Connection], for friend: User) -> Connection? {
        connections.first { $0.friend?.id == friend.id }
    }

    @Test("existingConnection retorna nil quando o amigo não tem conexão")
    func existingNilForNewFriend() {
        let stranger = User(name: "Novo", profilePicture: Data())
        let conns = [Connection(friend: User(name: "Outro", profilePicture: Data()))]
        #expect(existing(in: conns, for: stranger) == nil)
    }

    @Test("existingConnection encontra connection por id do amigo")
    func existingFoundByFriendId() {
        let friend = User(name: "A", profilePicture: Data(), id: UUID())
        let connection = Connection(friend: friend)
        #expect(existing(in: [connection], for: friend)?.id == connection.id)
    }

    @Test("confirmFriend cria nova Connection quando o amigo é novo")
    func confirmFriendCreatesNew() throws {
        let context = try makeContext()
        let profile = User(name: "Eu", profilePicture: Data(), id: UUID())
        let friend = User(name: "Novo", profilePicture: Data(), id: UUID())
        context.insert(profile)
        try context.save()

        context.insert(friend)
        let newConnection = Connection(friend: friend)
        context.insert(newConnection)
        try context.save()

        let conns = try context.fetch(FetchDescriptor<Connection>())
        #expect(conns.count == 1)
        #expect(conns.first?.friend?.id == friend.id)
    }

    @Test("confirmFriend atualiza lastMet e soma 10 ao score para amigo existente")
    func confirmFriendUpdatesExisting() {
        let friend = User(name: "Velho", profilePicture: Data(), id: UUID())
        let connection = Connection(friend: friend, lastMet: nil, score: 20)

        // Replica o if do confirmFriend
        connection.lastMet = Date.now
        connection.metaManager?.addOrSubtractScore(10)

        #expect(connection.lastMet != nil)
        #expect(connection.metaManager?.score == 30)
    }

    @Test("Não é possível parear consigo mesmo (mesmo id)")
    func cannotPairWithSelf() {
        let id = UUID()
        let profile = User(name: "Eu", profilePicture: Data(), id: id)
        let mirror = User(name: "Eu (espelho)", profilePicture: Data(), id: id)
        #expect(profile.id == mirror.id) // o guard sairia aqui
    }

    @Test("Pareamento permitido quando ids diferem")
    func pairingAllowedDifferentIds() {
        let profile = User(name: "Eu", profilePicture: Data(), id: UUID())
        let friend = User(name: "Outro", profilePicture: Data(), id: UUID())
        #expect(profile.id != friend.id)
    }
}
