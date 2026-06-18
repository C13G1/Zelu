//
//  EditFroupsViewModel.swift
//  ConexoesAmizaticas
//
//  Created by Jonas Fernando Nascimento Melo on 17/06/26.
//

import Foundation
import SwiftUI
import PhotosUI
import SwiftData

/// Backs `EditGroupView`: edits an existing `FriendGroup`'s name, photo and members, persisting changes.
@Observable
class EditGroupViewModel {
    var group: FriendGroup
    var name: String
    let characterLimit: Int = 10
    var selectedPhoto: PhotosPickerItem?
    private let modelContext: ModelContext
    init(group: FriendGroup, modelContext: ModelContext) {
        self.group = group
        self.modelContext = modelContext
        self.name = group.name
    }
    
    func removeConnection(_ connection: Connection) {
        group.connections.removeAll { $0.id == connection.id }
        try? modelContext.save()
    }
    
    func commitName() {
        if name.count > characterLimit {
            name = String(name.prefix(characterLimit))
            return
        }
        group.name = name
        try? modelContext.save()
        NotificationCenter.default.post(name: .GroupUpdated, object: nil)
    }
    
    func commitSelectedPhoto() async {
        guard let item = selectedPhoto,
              let data = try? await item.loadTransferable(type: Data.self) else { return }
        // Square-crop so the new cover matches the circular containers without stretching.
        group.image = UIImage(data: data)?.squareThumbnail(side: 512).jpegData(compressionQuality: 0.9) ?? data
        try? modelContext.save()
        NotificationCenter.default.post(name: .GroupUpdated, object: nil)
    }
    /// Deletes the group from the live `ModelContext` passed by the view. The context captured at init
    /// is the environment's default (resolved before the view is in the hierarchy) and does not persist,
    /// so deletion must use the context read from the view's body.
    func deletGroup(context: ModelContext) {
        context.delete(group)
        do {
            try context.save()
            NotificationCenter.default.post(name: .GroupUpdated, object: nil)
        } catch {
            print("Erro ao deletar: \(error)")
        }
    }
}
