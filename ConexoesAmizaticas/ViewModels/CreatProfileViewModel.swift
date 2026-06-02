//
//  OnboardingViewModel.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 20/05/26.
//

import Foundation
import SwiftUI
import PhotosUI
import SwiftData
import Aptabase

/// Drives the new-user onboarding flow that collects the primary profile (name + avatar)
/// and bootstraps the `User` entity into the persistent store.
///
/// `OnboardingViewModel` owns the form state, validates input, asynchronously loads the picked photo
/// and finalizes the flow by inserting the freshly built profile through the supplied `ModelContext`.
@Observable
class CreatProfileViewModel {
    var name: String = ""
    var selectedPhoto: PhotosPickerItem?
    var profileImageData: Data?

    /// Maximum character length enforced on the user name field.
    let characterLimit: Int = 10

    /// Returns `true` while the name field holds at least one non-whitespace character.
    var canProceed: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Trims `name` down to `characterLimit` whenever the user types past the limit.
    func enforceCharacterLimit() {
        if name.count > characterLimit {
            name = String(name.prefix(characterLimit))
        }
    }

    /// Loads the picked photo data asynchronously after the user selects an item from the picker.
    func loadSelectedPhoto() async {
        guard let item = selectedPhoto,
              let data = try? await item.loadTransferable(type: Data.self) else { return }
        profileImageData = data
    }

    /// Finalizes the onboarding by packaging the collected data into a `User` model and inserting it.
    /// - Parameter modelContext: The SwiftData context that will receive the new profile.
    func createProfile(modelContext: ModelContext) {
        let finalImageData = profileImageData
        ?? UIImage(named: "defaultPicture")?.jpegData(compressionQuality: 0.99)
            ?? Data()
        let user = User(
            name: name.trimmingCharacters(in: .whitespaces),
            profilePicture: finalImageData
        )
        modelContext.insert(user)
        Aptabase.shared.trackEvent("onboarding_completed")
    }
}
