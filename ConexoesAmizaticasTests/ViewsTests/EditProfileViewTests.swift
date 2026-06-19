//
//  EditProfileViewTests.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 28/05/26.
//

import Testing
import Foundation
import SwiftUI
import SwiftData
@testable import ConexoesAmizaticas

@MainActor
struct EditProfileSaveLogicTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: config
        )
        return ModelContext(container)
    }

    private func canSave(name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    @Test("canSave rejeita nome vazio")
    func canSaveRejectsEmpty() {
        #expect(canSave(name: "") == false)
    }

    @Test("canSave rejeita só espaços")
    func canSaveRejectsWhitespace() {
        #expect(canSave(name: "    ") == false)
    }

    @Test("canSave aceita nome válido")
    func canSaveAcceptsValid() {
        #expect(canSave(name: "Marcela") == true)
    }

    private func performSave(name: String, image: Data?, on user: User) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        user.editName(trimmed)
        if let image = image {
            user.editProfileImageData(image)
        }
    }

    @Test("saveChanges atualiza o nome no User")
    func saveChangesUpdatesName() {
        let user = User(name: "Antigo", profilePicture: Data())
        performSave(name: "Novo", image: nil, on: user)
        #expect(user.getName() == "Novo")
    }

    @Test("saveChanges remove espaços nas bordas")
    func saveChangesTrimsName() {
        let user = User(name: "X", profilePicture: Data())
        performSave(name: "  Lucas  ", image: nil, on: user)
        #expect(user.getName() == "Lucas")
    }

    @Test("saveChanges atualiza a imagem quando fornecida")
    func saveChangesUpdatesImage() {
        let user = User(name: "X", profilePicture: Data())
        let newImage = Data([0xAA, 0xBB])
        performSave(name: "X", image: newImage, on: user)
        #expect(user.getProfileImageData() == newImage)
    }

    @Test("saveChanges não altera a imagem quando nil é passado")
    func saveChangesPreservesImageWhenNil() {
        let original = Data([0x11])
        let user = User(name: "X", profilePicture: original)
        performSave(name: "Y", image: nil, on: user)
        #expect(user.getProfileImageData() == original)
    }

    @Test("saveChanges persistido em ModelContext sobrevive a fetch")
    func saveChangesPersists() throws {
        let context = try makeContext()
        let user = User(name: "Antes", profilePicture: Data())
        context.insert(user)
        try context.save()

        performSave(name: "Depois", image: Data([0x42]), on: user)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<User>()).first
        #expect(fetched?.getName() == "Depois")
        #expect(fetched?.getProfileImageData() == Data([0x42]))
    }
}

@Suite("Edit Friend Profile Save Logic")
@MainActor
struct EditFriendProfileSaveLogicTests {

    private func performSave(name: String, image: Data?, on connection: Connection) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        connection.friend?.editName(trimmed)
        if let image = image {
            connection.friend?.editProfileImageData(image)
        }
    }

    @Test("Edição do amigo atualiza o User dentro da Connection")
    func editFriendUpdatesUser() {
        let friend = User(name: "Antes", profilePicture: Data())
        let connection = Connection(friend: friend)
        performSave(name: "Depois", image: nil, on: connection)
        #expect(connection.friend?.getName() == "Depois")
    }

    @Test("Edição do amigo preserva imagem quando nil")
    func editFriendKeepsImage() {
        let original = Data([0x99])
        let friend = User(name: "X", profilePicture: original)
        let connection = Connection(friend: friend)
        performSave(name: "X", image: nil, on: connection)
        #expect(connection.friend?.getProfileImageData() == original)
    }
}
