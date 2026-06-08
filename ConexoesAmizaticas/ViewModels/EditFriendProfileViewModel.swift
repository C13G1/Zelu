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
    private let modelContext: ModelContext

    init(connection: Connection, modelContext: ModelContext) {
        self.connection = connection
        self.name = connection.friend.name
        self.profileImageData = connection.friend.profilePicture
        self.modelContext = modelContext
    }

//    /// Persists name and photo back to the friend, saves the context and broadcasts the update.
//    func saveChanges(modelContext: ModelContext) {
//        let trimmed = name.trimmingCharacters(in: .whitespaces)
//        connection.friend.editName(trimmed)
//        if let data = profileImageData {
//            connection.friend.editProfileImageData(data)
//        }
//        try? modelContext.save()
//        NotificationCenter.default.post(name: .friendProfileUpdated, object: nil)
//    }
    
    /// Saves the typed name to the profile or clamps it back to the character limit when needed.
    func commitName() {
        if name.count > characterLimit {
            name = String(name.prefix(characterLimit))
            return
        }
        connection.friend.editName(name)
        try? modelContext.save()
    }
    
    /// Loads the newly picked photo asynchronously and persists it on the profile.
    func commitSelectedPhoto() async {
        guard let item = selectedPhoto,
              let data = try? await item.loadTransferable(type: Data.self) else { return }
        connection.friend.editProfileImageData(data)
        try? modelContext.save()
    }
}
