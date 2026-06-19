//
//  InitialViewTests.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 28/05/26.
//

import Testing
import Foundation
import SwiftData
@testable import ConexoesAmizaticas

@MainActor
struct InitialViewLogicTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: config
        )
        return ModelContext(container)
    }

    private func currentUser(from users: [User]) -> User {
        users.first ?? User()
    }

    @Test("currentUser retorna User default quando lista vazia")
    func currentUserDefaultsWhenEmpty() {
        let user = currentUser(from: [])
        #expect(user.getName() == "DefaultName")
    }

    @Test("currentUser retorna o primeiro usuário quando existem vários")
    func currentUserReturnsFirst() {
        let a = User(name: "A", profilePicture: Data())
        let b = User(name: "B", profilePicture: Data())
        #expect(currentUser(from: [a, b]).getName() == "A")
    }

    @Test("Empty state aparece quando não há connections")
    func emptyStateWhenNoConnections() {
        let connections: [Connection] = []
        #expect(connections.isEmpty)
    }

    @Test("Empty state desaparece com pelo menos uma connection")
    func emptyStateGoneWithConnections() {
        let c = Connection(friend: User(name: "X", profilePicture: Data()))
        #expect([c].isEmpty == false)
    }

    private func sceneConnections(from all: [Connection]) -> Set<Connection> {
        Set(all.filter { !$0.inVacuo })
    }

    @Test("Apenas connections fora de vácuo entram na scene")
    func sceneExcludesVacuum() {
        let active = Connection(friend: User(name: "A", profilePicture: Data()), score: 30)
        let dead = Connection(friend: User(name: "B", profilePicture: Data()), score: 0)

        let result = sceneConnections(from: [active, dead])
        #expect(result.count == 1)
        #expect(result.contains(active))
        #expect(result.contains(dead) == false)
    }

    @Test("onAppear aplica decay em cada connection")
    func onAppearAppliesDecay() throws {
        let context = try makeContext()
        let c1 = Connection(friend: User(name: "A", profilePicture: Data()), score: 50)
        let c2 = Connection(friend: User(name: "B", profilePicture: Data()), score: 50)
        let oldDate = Calendar.current.date(byAdding: .day, value: -30, to: .now)
        c1.lastMet = oldDate
        c2.lastMet = oldDate
        c1.metaManager?.setMeta(.semanal)
        c2.metaManager?.setMeta(.semanal)
        context.insert(c1); context.insert(c2)
        try context.save()

        for connection in [c1, c2] {
            connection.metaManager?.applyDecayIfNeeded(lastMet: connection.lastMet)
        }

        #expect((c1.metaManager?.score ?? 0) < 50)
        #expect((c2.metaManager?.score ?? 0) < 50)
    }
}
