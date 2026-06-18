//
//  FriendFeedViewModel.swift
//  ConexoesAmizaticas
//
//  Created by Dayô Araújo on 23/05/26.
//

import SwiftUI
import SwiftData
import PhotosUI

/// Controls the state and mathematical rendering of the memory carousel for a specific connection.
///
/// `FriendFeedViewModel` acts as the engine behind the `PictureScroll` UI component. It is responsible for bridging
/// user interactions (drag gestures) with the complex trigonometric functions (`sin`, `cos`) that simulate a
/// 3D cylindrical scrolling effect. It also orchestrates the persistence of new photos via SwiftData.
@Observable
class FriendFeedViewModel {
    private(set) var connection: Connection
    private(set) var posts: [Post] = []
    
    /// Holds the raw items currently selected by the user in the native PhotosPicker.
    var selectedItems: [PhotosPickerItem] = []
    var isPickerPresented: Bool = false
    
    /// Temporarily stores the post that the user intends to delete, driving the overlay alert.
    var postToDelete: Post? = nil
    
    var snappedItem: Double = 0
    var draggingItem: Double = 0
    var activeIndex: Int = 0
    
    init(connection: Connection) {
        self.connection = connection
        refreshPosts()
    }
    
    /// Syncs the local memory array with the database, ensuring newest posts appear first.
    func refreshPosts() {
        self.posts = connection.feedManager.posts.sorted(by: { $0.date > $1.date })
    }
    
    /// Converts async PhotosPicker selections into database `Post` entities.
    func addPostFromSelection(modelContext: ModelContext) async {
        if !selectedItems.isEmpty {
            for item in selectedItems {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let newPost = Post(images: [data])
                    connection.feedManager.addPost(newPost)
                    modelContext.insert(newPost)
                }
            }
            try? modelContext.save()
            refreshPosts()
            selectedItems = []
        }
    }
    
    /// Purges a specific memory from both the active array and the SwiftData store.
    func deletePost(id: UUID, modelContext: ModelContext) {
        connection.feedManager.deletePost(id: id)
        posts.removeAll(where: { $0.id == id })
        try? modelContext.save()
        refreshPosts()
        
        snappedItem = 0
        draggingItem = 0
        activeIndex = 0
    }
    
    // MARK: - Carousel Geometry Math
    
    /// Determines how far away an item is from the current focal point of the carousel.
    func distance(_ index: Int) -> Double {
        if !posts.isEmpty {
            return (draggingItem - Double(index)).remainder(dividingBy: Double(posts.count))
        } else {
            return 0
        }
    }
    
    /// Calculates the horizontal displacement of the image to simulate a curved cylinder.
    func xOffset(_ index: Int) -> Double {
        let count = Double(max(posts.count, 3))
        let angle = Double.pi * 2 / count * distance(index)
        // Raio cresce com o número de cards para manter espaçamento visual
        let radius = max(245, count * 40)
        return sin(angle) * radius
    }
    
    /// Creates the subtle vertical dip at the edges to enhance the 3D depth effect.
    func yOffset(_ index: Int) -> Double {
        let dist = abs(distance(index))
        let hideThreshold = hideThreshold()
        if dist > hideThreshold { return -1000 }
        return -pow(dist * 30, 2) / 10
    }
    
    /// Tilts the cards leaning away from the center based on their distance.
    func rotationEffect(_ index: Int) -> Double {
        let dist = distance(index)
        return -dist * 30
    }
    
    /// Ensures the center card is always rendered strictly on top of the peripheral cards.
    func zIndex(_ index: Int) -> Double {
        1.0 - abs(distance(index)) * 0.1
    }
    
    /// Scales down cards that are moving towards the edges to simulate distance.
    func scaleEffect(_ index: Int) -> Double {
        1.0 - abs(distance(index)) * 0.2
    }
    
    /// Hides cards that have rotated around to the "back" side of the virtual cylinder.
    func opacity(_ index: Int) -> Double {
        let dist = abs(distance(index))
        return dist > hideThreshold() ? 0.0 : 1.0
    }
    
    // Threshold dinâmico: esconde cards que passaram do "fundo" do cilindro
    private func hideThreshold() -> Double {
        let count = Double(max(posts.count, 3))
        return count / 4.0
    }
    
    // MARK: - Gesture Tracking
    
    // MARK: - Gesture Tracking

    func onDragChanged(value: DragGesture.Value) {
        draggingItem = snappedItem + value.translation.width / 500
    }

    func onDragEnded(value: DragGesture.Value) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            let velocity = value.predictedEndTranslation.width - value.translation.width
            let sensitivity: Double = 200
            
            let delta = (velocity / sensitivity).clamped(to: -1...1)
            
            let postsCount = Double(max(posts.count, 1))
            draggingItem = (snappedItem + delta)
                .rounded()
                .remainder(dividingBy: postsCount)
            snappedItem = draggingItem
            
            let count = posts.count
            activeIndex = count + Int(draggingItem)
            if activeIndex >= count || Int(draggingItem) >= 0 {
                activeIndex = Int(draggingItem)
            }
        }
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
