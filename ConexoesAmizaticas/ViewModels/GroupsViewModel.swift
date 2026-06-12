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
    private(set) var initialViewModel: InitialViewModel
    private(set) var friendsGroups: [FriendsGroup] = []
    
    /// Temporarily stores the post that the user intends to delete, driving the overlay alert.
    var postToDelete: Post? = nil
    
    var snappedItem: Double = 0
    var draggingItem: Double = 0
    var activeIndex: Int = 0
    
    init(initialViewModel: InitialViewModel) {
        self.initialViewModel = initialViewModel
        refreshFriendsGroups()
    }
    
    /// Syncs the local memory array with the database, ensuring newest posts appear first.
    func refreshFriendsGroups() {
        self.friendsGroups = initialViewModel.getFriendsGroups().sorted(by: { $0.id > $1.id })
    }
    
    /// Purges a specific memory from both the active array and the SwiftData store.
    func deleteFriendsGroup(withId: UUID, context: ModelContext) {
        let predicate = #Predicate<FriendsGroup> { friendsGroup in
            friendsGroup.id == withId
        }
        
        var fetchDescriptor = FetchDescriptor<FriendsGroup>(predicate: predicate)
        fetchDescriptor.fetchLimit = 1
        
        do {
            let fetchedFriendsGroup = try context.fetch(fetchDescriptor)
            if let friendsGroupToDelete = fetchedFriendsGroup.first {
                context.delete(friendsGroupToDelete)
                try context.save()
            }
        } catch {
            print("Failed to fetch or delete the friendsGroup: \(error.localizedDescription)")
        }
        refreshFriendsGroups()
        
        snappedItem = 0
        draggingItem = 0
        activeIndex = 0
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
        let count = Double(max(friendsGroups.count, 3))
        let angle = Double.pi * 2 / count * distance(index)
        let radius = max(140, count * 30)
        return sin(angle) * radius
    }
    
    /// Creates the subtle vertical dip at the edges.
    func yOffset(_ index: Int) -> Double {
        return 0
    }
    
    /// Tilts the cards leaning away from the center.
    func rotationEffect(_ index: Int) -> Double {
        return 0
    }
    
    /// Ensures the center card is always rendered strictly on top.
    func zIndex(_ index: Int) -> Double {
        1.0 - abs(distance(index)) * 0.1
    }
    
    /// Scales down cards that are moving towards the edges.
    func scaleEffect(_ index: Int) -> Double {
        1.0 - abs(distance(index)) * 0.15
    }
    
    /// Hides cards that have rotated around to the "back".
    func opacity(_ index: Int) -> Double {
        let dist = abs(distance(index))
        return dist > hideThreshold() ? 0.0 : 1.0
    }
    
    // Threshold dinâmico: esconde cards que passaram do "fundo" do cilindro
    private func hideThreshold() -> Double {
        let count = Double(max(friendsGroups.count, 3))
        return count / 4.0
    }
    
    // MARK: - Gesture Tracking
    
    func onDragChanged(value: DragGesture.Value) {
        draggingItem = snappedItem + value.translation.width / 500
    }
    
    func onDragEnded(value: DragGesture.Value) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            let velocity = value.predictedEndTranslation.width - value.translation.width
            let sensitivity: Double = 200
            
            let delta = (velocity / sensitivity).clamped(to: -1...1)
            
            let postsCount = Double(max(friendsGroups.count, 1))
            draggingItem = (snappedItem + delta)
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
