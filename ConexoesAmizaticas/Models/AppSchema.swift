//
//  AppSchema.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 30/05/26.
//

import Foundation
import SwiftData

/// The single source of truth for the SwiftData schema used across the app, previews and tests.
///
/// Whenever a new persistent type is introduced, add it once to `AppSchema.models` and every
/// `modelContainer(...)` call across the codebase picks it up automatically.
enum AppSchema {
    /// Every persistent type that participates in the application's `ModelContainer`.
    static let models: [any PersistentModel.Type] = [
        User.self,
        Post.self,
        FeedManager.self,
        Connection.self,
        MetaManager.self,
        FriendGroup.self   
    ]

    /// Convenience wrapper that builds a `Schema` from `models`, ready to be passed to `ModelContainer`.
    static var schema: Schema { Schema(models) }
}
