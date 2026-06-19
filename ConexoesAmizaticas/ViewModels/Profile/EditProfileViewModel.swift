//
//  EditProfileViewModel.swift
//  ConexoesAmizaticas
//
//  Created by Dayô Araújo on 27/05/26.
//

import Foundation
import SwiftUI
import PhotosUI
import SwiftData

/// Coordinates the live editing of the current user's identity inside `EditProfileView`.
///
/// `EditProfileViewModel` owns the form state (`editableName`, `selectedPhoto`) and forwards every change
/// to the underlying `User` referenced by `InitialViewModel`, persisting through `ModelContext`.
@Observable
class EditProfileViewModel {
    var editableName: String
    var selectedPhoto: PhotosPickerItem?

    /// Maximum character length enforced on the user name field.
    let characterLimit: Int = 10

    private let profile: User
    private let modelContext: ModelContext

    init(profile: User, modelContext: ModelContext) {
        self.profile = profile
        self.modelContext = modelContext
        self.editableName = profile.name
    }

    /// Underlying image data shown by the view (read-only mirror of the profile).
    var profileImageData: Data {
        profile.profilePicture
    }

    /// Saves the typed name to the profile or clamps it back to the character limit when needed.
    func commitName() {
        if editableName.count > characterLimit {
            editableName = String(editableName.prefix(characterLimit))
            return
        }
        profile.editName(editableName)
        try? modelContext.save()
    }

    /// Loads the newly picked photo asynchronously and persists it on the profile.
    func commitSelectedPhoto() async {
        guard let item = selectedPhoto,
              let data = try? await item.loadTransferable(type: Data.self) else { return }
        profile.editProfileImageData(data)
        try? modelContext.save()
    }

    /// Permanently erases the account: the owner profile and every related record (friends, connections,
    /// groups, posts), locally and — through CloudKit mirroring — on iCloud and the user's other devices.
    /// Clearing `ownUserID` sends the app back to onboarding. Irreversible.
    func deleteAccount() {
        try? modelContext.delete(model: Post.self)
        try? modelContext.delete(model: FeedManager.self)
        try? modelContext.delete(model: MetaManager.self)
        try? modelContext.delete(model: Connection.self)
        try? modelContext.delete(model: FriendGroup.self)
        try? modelContext.delete(model: User.self)
        try? modelContext.save()
        UserDefaults.standard.removeObject(forKey: "ownUserID")
    }
}
