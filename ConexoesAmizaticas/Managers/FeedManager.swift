//
//  FeedManager.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 18/05/26.
//

import Foundation
import SwiftData

/// Manages a collection of shared moments (`Post` objects) for a specific `Connection`.
@Model
class FeedManager {
    // CloudKit needs to-many relationships optional with an inverse.
    @Relationship(deleteRule: .cascade, inverse: \Post.feedManager) private(set) var posts: [Post]?

    /// Inverse of `Connection.feedManager`, required by CloudKit.
    var connection: Connection?

    init(){}

    /// Inserts a new post into the feed.
    /// - Parameter post: The `Post` object to be added.
    func addPost(_ post: Post) {
        posts = (posts ?? []) + [post]
    }

    /// Removes a post from the feed matching the given identifier.
    /// - Parameter id: The unique UUID of the post to remove.
    func deletePost(id: UUID) {
        posts = (posts ?? []).filter { $0.id != id }
    }
}
