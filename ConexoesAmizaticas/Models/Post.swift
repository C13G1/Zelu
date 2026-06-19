//
//  Post.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 18/05/26.
//

import Foundation
import SwiftData
import SwiftUI

/// Represents a distinct memory or interaction shared between the user and a friend.
@Model
class Post: Identifiable {
    /// An array containing raw image data associated with the post.
    var images: [Data] = []
    
    /// The creation date of the memory.
    var date: Date = Date.now
    
    var id: UUID = UUID()

    /// Inverse of `FeedManager.posts`, required by CloudKit.
    var feedManager: FeedManager?

    init(images: [Data], date: Date = Date.now) {
        self.images = images
        self.date = date
        self.id = UUID()
    }
    
    /// Appends new image data to the existing post.
    /// - Parameter image: Raw byte data representing the image.
    func appendImageData(_ image: Data) {
        images.append(image)
    }
    
    /// Removes specific image data from the post.
    /// - Parameter image: The exact raw byte data to remove.
    func deleteDataImage(_ image: Data) {
        images.removeAll(where: {$0 == image})
    }
}
