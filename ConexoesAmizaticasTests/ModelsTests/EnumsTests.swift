//
//  EnumsTests.swift
//  ConexoesAmizaticas
//
//  Created by Jonas Fernando Nascimento Melo on 28/05/26.
//


import Testing
import Foundation
import UIKit
@testable import ConexoesAmizaticas

struct RelationshipStateTests {

    @Test("orbitRadius retorna valor correspondente",
          arguments: [
            (RelationshipState.afastados,    100.0),
            (RelationshipState.distantes,    200.0),
            (RelationshipState.estaveis,     300.0),
            (RelationshipState.proximos,     400.0),
            (RelationshipState.inseparaveis, 500.0)
          ])
    func orbitRadiusMapping(state: RelationshipState, expected: Double) {
        #expect(state.orbitRadius == expected)
    }

    @Test("orbitSpeed retorna valor correspondente",
          arguments: [
            (RelationshipState.afastados,    1.0),
            (RelationshipState.distantes,    2.0),
            (RelationshipState.estaveis,     3.0),
            (RelationshipState.proximos,     4.0),
            (RelationshipState.inseparaveis, 5.0)
          ])
    func orbitSpeedMapping(state: RelationshipState, expected: Double) {
        #expect(state.orbitSpeed == expected)
    }

    @Test("nodeSize retorna valor correspondente",
          arguments: [
            (RelationshipState.afastados,    CGFloat(64)),
            (RelationshipState.distantes,    CGFloat(80)),
            (RelationshipState.estaveis,     CGFloat(96)),
            (RelationshipState.proximos,     CGFloat(112)),
            (RelationshipState.inseparaveis, CGFloat(126))
          ])
    func nodeSizeMapping(state: RelationshipState, expected: CGFloat) {
        #expect(state.nodeSize == expected)
    }

    @Test("rawValue corresponde ao nome em português")
    func rawValueMapping() {
        #expect(RelationshipState.afastados.rawValue    == "afastados")
        #expect(RelationshipState.distantes.rawValue    == "distantes")
        #expect(RelationshipState.estaveis.rawValue     == "estaveis")
        #expect(RelationshipState.proximos.rawValue     == "proximos")
        #expect(RelationshipState.inseparaveis.rawValue == "inseparaveis")
    }

    @Test("É decodificável a partir do rawValue")
    func decodableFromRawValue() throws {
        let json = Data("\"proximos\"".utf8)
        let decoded = try JSONDecoder().decode(RelationshipState.self, from: json)
        #expect(decoded == .proximos)
    }
}

@Suite("Meta Enum")
struct MetaEnumTests {

    @Test("days retorna o número correto de dias",
          arguments: [
            (Meta.nenhuma,   0),
            (Meta.semanal,   7),
            (Meta.quinzenal, 15),
            (Meta.mensal,    30),
            (Meta.bimestral, 90),
            (Meta.semestral, 180),
            (Meta.anual,     360)
          ])
    func daysMapping(meta: Meta, expected: Int) {
        #expect(meta.days == expected)
    }

    @Test("displayText retorna texto em português")
    func displayTextMapping() {
        #expect(Meta.nenhuma.displayText   == "Nenhuma")
        #expect(Meta.semanal.displayText   == "1 vez por semana")
        #expect(Meta.quinzenal.displayText == "a cada 15 dias")
        #expect(Meta.mensal.displayText    == "1 vez por mês")
        #expect(Meta.bimestral.displayText == "a cada 3 meses")
        #expect(Meta.semestral.displayText == "a cada 6 meses")
        #expect(Meta.anual.displayText     == "1 vez por ano")
    }

    @Test("Round-trip codable preserva o valor")
    func metaCodableRoundTrip() throws {
        let original = Meta.bimestral
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Meta.self, from: data)
        #expect(decoded == original)
    }

    @Test("quinzenal usa o rawValue corrigido e ainda decodifica o typo legado")
    func quinzenalRawValueAndLegacyDecode() throws {
        // O typo "quizenal" foi corrigido para "quinzenal"; o decoder mantém compatibilidade lendo o
        // valor legado persistido por versões antigas, então dados já sincronizados não quebram.
        #expect(Meta.quinzenal.rawValue == "quinzenal")
        let legacy = try JSONDecoder().decode(Meta.self, from: Data("\"quizenal\"".utf8))
        #expect(legacy == .quinzenal)
    }
}


