//
//  SetGroupViewModel.swift
//  ConexoesAmizaticas
//
//  Created by Jonas Fernando Nascimento Melo on 17/06/26.
//

import Foundation
import SwiftUI
import PhotosUI
import SwiftData
import Aptabase

/// Backs the group-creation flow: holds the chosen name, photo and members, and persists the new
/// `FriendGroup` to SwiftData.
@Observable
class CreatGroupViewModel{
    var name: String
    let characterLimit: Int
    var selectedPhoto: PhotosPickerItem?
    var profileImageData: Data?
    var selectedConnections: [Connection]
    
    init(name: String = "", selectedPhoto: PhotosPickerItem? = nil, profileImageData: Data? = nil, selectedConnections: [Connection], group: FriendGroup = FriendGroup(name: "", image: Data(), connections: [Connection(friend: User())])) {
        self.name = name
        self.characterLimit = 10
        self.selectedPhoto = selectedPhoto
        self.profileImageData = profileImageData
        self.selectedConnections = selectedConnections
    }
    
    /// Trims `name` down to `characterLimit` whenever the user types past the limit.
    func enforceCharacterLimit() {
        if name.count > characterLimit {
            name = String(name.prefix(characterLimit))
        }
    }
    
    func removeConnection(_ connection: Connection) {
        selectedConnections.removeAll { $0.id == connection.id }
    }
    
    /// Loads the picked photo data asynchronously after the user selects an item from the picker.
    func loadSelectedPhoto() async {
        guard let item = selectedPhoto,
              let data = try? await item.loadTransferable(type: Data.self) else { return }
        profileImageData = data
    }
    
    /// Finalizes the onboarding by packaging the collected data into a `User` model and inserting it.
    /// - Parameter modelContext: The SwiftData context that will receive the new profile.
    func createGroup(modelContext: ModelContext) {
        let finalName = name == "" ? "Grupo" : name
        // Square-crop the cover so it never stretches in the circular group containers.
        let sourceImage = profileImageData.flatMap { UIImage(data: $0) }
                          ?? UIImage(named: "defaultPicture")
        let finalImageData = sourceImage?.squareThumbnail(side: 512)
                                         .jpegData(compressionQuality: 0.9) ?? Data()
        let group = FriendGroup(
            name: finalName,
            image: finalImageData,
            connections: selectedConnections
        )
        do {
            modelContext.insert(group)
            try modelContext.save()
            Aptabase.shared.trackEvent("group_created")
            NotificationCenter.default.post(name: .GroupUpdated, object: nil)
        }
        catch{
            print("erro ao criar grupo")
        }
    }
}
