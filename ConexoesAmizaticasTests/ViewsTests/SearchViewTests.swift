//
//  SearchViewTests.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 28/05/26.
//

import Testing
import SwiftUI
import SwiftData
@testable import ConexoesAmizaticas

@MainActor
struct SearchViewFilterTests {

    private func make(_ name: String) -> Connection {
        Connection(friend: User(name: name, profilePicture: Data(), id: UUID()))
    }

    private func filterConnections(_ connections: [Connection], searchText: String) -> [Connection] {
        if searchText.isEmpty { return [] }
        return connections.filter { $0.friend?.name.localizedStandardContains(searchText) ?? false }
    }

    @Test("Texto vazio retorna lista vazia")
    func emptySearchReturnsEmpty() {
        let all = [make("Ana"), make("Bia"), make("Carla")]
        #expect(filterConnections(all, searchText: "").isEmpty)
    }

    @Test("Encontra correspondência parcial")
    func partialMatch() {
        let all = [make("Ana"), make("Antonio"), make("Bia")]
        let result = filterConnections(all, searchText: "an")
        #expect(result.count == 2)
        #expect(Set(result.compactMap(\.friend?.name)) == Set(["Ana", "Antonio"]))
    }

    @Test("Busca é case-insensitive")
    func caseInsensitive() {
        let all = [make("Ricardo")]
        #expect(filterConnections(all, searchText: "RICARDO").count == 1)
        #expect(filterConnections(all, searchText: "ricardo").count == 1)
        #expect(filterConnections(all, searchText: "RiCaRdO").count == 1)
    }

    @Test("Busca é diacritic-insensitive (localizedStandardContains)")
    func diacriticInsensitive() {
        let all = [make("João")]
        let result = filterConnections(all, searchText: "joao")
        #expect(result.count == 1)
    }

    @Test("Sem matches retorna vazio")
    func noMatchesReturnsEmpty() {
        let all = [make("Ana"), make("Bia")]
        #expect(filterConnections(all, searchText: "xyz").isEmpty)
    }
}
