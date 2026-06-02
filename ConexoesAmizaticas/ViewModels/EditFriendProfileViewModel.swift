//
//  EditFriendProfileViewModel.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 27/05/26.
//

import Foundation
import SwiftUI
import PhotosUI
import SwiftData

/// Holds the editable form state for a friend's profile and persists the result when the user saves.
///
/// `EditFriendProfileViewModel` operates on a single `Connection`: it lets the view edit name and avatar locally,
/// loads picked photos asynchronously and commits the changes through `ModelContext` while broadcasting a
/// `.friendProfileUpdated` notification so dependent views refresh.
@Observable
class EditFriendProfileViewModel {
    var name: String
    var selectedPhoto: PhotosPickerItem?
    var profileImageData: Data?

    /// Maximum character length enforced on the friend name field.
    let characterLimit: Int = 10

    let connection: Connection

    init(connection: Connection) {
        self.connection = connection
        self.name = connection.friend.name
        self.profileImageData = connection.friend.profilePicture
    }

    /// Returns `true` while the name field holds at least one non-whitespace character.
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Trims `name` down to `characterLimit` whenever the user types past the limit.
    func enforceCharacterLimit() {
        if name.count > characterLimit {
            name = String(name.prefix(characterLimit))
        }
    }

    /// Loads the newly picked photo data asynchronously into the local buffer.
    func loadSelectedPhoto() async {
        guard let item = selectedPhoto,
              let data = try? await item.loadTransferable(type: Data.self) else { return }
        profileImageData = data
    }

    /// Persists name and photo back to the friend, saves the context and broadcasts the update.
    func saveChanges(modelContext: ModelContext) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        connection.friend.editName(trimmed)
        if let data = profileImageData {
            connection.friend.editProfileImageData(data)
        }
        try? modelContext.save()
        NotificationCenter.default.post(name: .friendProfileUpdated, object: nil)
    }
}
