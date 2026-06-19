//
//  SetMetaViewTests.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 28/05/26.
//

import Testing
import Foundation
import SwiftData
@testable import ConexoesAmizaticas

@MainActor
struct SetMetaViewLogicTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: config
        )
        return ModelContext(container)
    }

    @Test("possibleMetas contém todos os casos do enum Meta")
    func possibleMetasCoverAllCases() {
        let possibleMetas: [Meta] = [.nenhuma, .semanal, .quinzenal, .mensal, .bimestral, .semestral, .anual]

        #expect(possibleMetas.count == 7)
        #expect(Set(possibleMetas) == Set([
            .nenhuma, .semanal, .quinzenal, .mensal, .bimestral, .semestral, .anual
        ]))
    }

    @Test("Cada item de possibleMetas tem texto de display não vazio")
    func eachMetaHasDisplayText() {
        let possibleMetas: [Meta] = [.nenhuma, .semanal, .quinzenal, .mensal, .bimestral, .semestral, .anual]
        for meta in possibleMetas {
            #expect(meta.displayText.isEmpty == false)
        }
    }

    @Test("Alterar a meta no view chama defineMeta no ViewModel")
    func changingMetaCallsDefineMeta() {
        let connection = Connection(friend: User(name: "Teste", profilePicture: Data()))
        let vm = FriendProfileViewModel(connection: connection)

        #expect(vm.getMeta() == .mensal)

        vm.defineMeta(meta: .semanal)
        #expect(vm.getMeta() == .semanal)
        #expect(connection.metaManager?.meta == .semanal)
    }

    @Test("Alteração de meta é persistida após save")
    func metaChangeIsPersisted() throws {
        let context = try makeContext()
        let friend = User(name: "X", profilePicture: Data())
        let connection = Connection(friend: friend)
        context.insert(friend)
        context.insert(connection)
        try context.save()

        let vm = FriendProfileViewModel(connection: connection)
        vm.defineMeta(meta: .anual)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Connection>()).first
        #expect(fetched?.metaManager?.meta == .anual)
    }

    private func performDelete(connection: Connection, in context: ModelContext) {
        if let metaManager = connection.metaManager { context.delete(metaManager) }
        if let feedManager = connection.feedManager { context.delete(feedManager) }
        if let friend = connection.friend { context.delete(friend) }
        context.delete(connection)
    }

    @Test("deletarContato remove a Connection e seus objetos relacionados do contexto")
    func deleteRemovesConnection() throws {
        let context = try makeContext()
        let friend = User(name: "Apagar", profilePicture: Data())
        let connection = Connection(friend: friend)
        context.insert(friend)
        context.insert(connection)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Connection>()).count == 1)

        performDelete(connection: connection, in: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Connection>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<User>()).isEmpty)
    }

    @Test("deletarContato com múltiplas conexões remove apenas a alvo")
    func deleteOnlyTarget() throws {
        let context = try makeContext()
        let keepFriend = User(name: "Mantém", profilePicture: Data())
        let dropFriend = User(name: "Remove", profilePicture: Data())
        let keep = Connection(friend: keepFriend)
        let drop = Connection(friend: dropFriend)
        context.insert(keepFriend); context.insert(dropFriend)
        context.insert(keep); context.insert(drop)
        try context.save()

        performDelete(connection: drop, in: context)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<Connection>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.friend?.getName() == "Mantém")
    }
}
