//
//  FriendsGroupsViewModel.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 12/06/26.
//

import SwiftUI
import SwiftData
import PhotosUI

/// Controls the state and mathematical rendering of the memory carousel for a specific connection.
///
/// `FriendsGroupsViewModel` acts as the engine behind the `PictureScroll` UI component. It is responsible for bridging
/// user interactions (drag gestures) with the complex trigonometric functions (`sin`, `cos`) that simulate a
/// 3D cylindrical scrolling effect. It also orchestrates the persistence of new photos via SwiftData.
@Observable
class FriendsGroupsViewModel {
    private(set) var modelContext : ModelContext!
    var friendsGroups: [FriendGroup] = []

    var snappedItem:  Double = 0
    var draggingItem: Double = 0
    var activeIndex:  Int    = 0
    
    func fetchData() {
        do {
            let friendsGroupsDescriptor = FetchDescriptor<FriendGroup>()
            let friendsGroups = try modelContext.fetch(friendsGroupsDescriptor)
            self.friendsGroups = friendsGroups
        }
        catch {
            print("fetch failed")
        }
        refreshFriendsGroups()
    }
    
    /// Syncs the local memory array with the database, ensuring newest posts appear first.
    func refreshFriendsGroups() {
        self.friendsGroups = getFriendsGroups().sorted(by: { $0.id > $1.id })
    }
    
    /// Extracts a flat array of `FriendsGroup`
    func getFriendsGroups() -> [FriendGroup] {
        var friendsGroups: [FriendGroup] = []
        
        for friendsGroup in self.friendsGroups {
            friendsGroups.append(friendsGroup)
        }
        return friendsGroups
    }
    
    func addFriendsGroup() {
        guard let image = UIImage(named: "defaultPicture") else {
            print("erro carregando imagem")
            return
        }
        guard let data = image.jpegData(compressionQuality: 0.5) else {
            print("erro transformando imagem em dados")
            return
        }
        let group = FriendGroup(name: "Group \(friendsGroups.count + 1)", image: data, connections: [])
        self.modelContext.insert(group)
        self.friendsGroups.append(group)
        do {
            try self.modelContext.save()
        }
        catch {
            print("Erro ao salvar grupo")
        }
    }
    
    func setModelContext(modelContext: ModelContext){
        self.modelContext = modelContext
    }
    
    // MARK: - Carousel Geometry Math
    
    /// Determines how far away an item is from the current focal point of the carousel.
    func distance(_ index: Int) -> Double {
        if !friendsGroups.isEmpty {
            return (draggingItem - Double(index)).remainder(dividingBy: Double(friendsGroups.count))
        } else {
            return 0
        }
    }
    
    /// Calculates the horizontal displacement.
    func xOffset(_ index: Int) -> Double {
        let fixedVisualCount: Double = 5.0
        let angle = (Double.pi * 2 / fixedVisualCount) * distance(index)
        
        let fixedRadius: Double = 230.0
        
        return sin(angle) * fixedRadius
    }
    
    /// Creates the subtle vertical dip at the edges.
    func yOffset(_ index: Int) -> Double {
        let dist = abs(distance(index))
        let hideThreshold = hideThreshold()
        if dist > hideThreshold { return 1000 }
        
        return pow(dist * 30, 2) / 10
    }
    
    /// Ensures the center card is always rendered strictly on top.
    func zIndex(_ index: Int) -> Double {
        1.0 - abs(distance(index)) * 0.1
    }
    
    /// Hides cards that have rotated around to the "back".
    func opacity(_ index: Int) -> Double {
        let dist = abs(distance(index))
        return dist > hideThreshold() ? 0.0 : 1.0
    }
    
    private func hideThreshold() -> Double {
        return 1.5
    }
    
    // MARK: - Gesture Tracking
    
    func onDragChanged(value: DragGesture.Value) {
        draggingItem = snappedItem + value.translation.width / 150
    }

    func onDragEnded(value: DragGesture.Value) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            let velocity = value.predictedEndTranslation.width - value.translation.width
            let nudge = (velocity / 200).clamped(to: -1...1)

            // Snap from where the finger actually left the carousel (`draggingItem` already
            // includes the drag translation) plus a small velocity nudge for quick flicks.
            // The old code snapped from `snappedItem` using velocity alone, so a slow drag
            // released with little speed went nowhere.
            let postsCount = Double(max(friendsGroups.count, 1))
            draggingItem = (draggingItem + nudge)
                .rounded()
                .remainder(dividingBy: postsCount)
            snappedItem = draggingItem
            
            let count = friendsGroups.count
            activeIndex = count + Int(draggingItem)
            if activeIndex >= count || Int(draggingItem) >= 0 {
                activeIndex = Int(draggingItem)
            }
        }
    }
}
