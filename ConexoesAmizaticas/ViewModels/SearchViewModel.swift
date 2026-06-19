//
//  SearchViewModel.swift
//  ConexoesAmizaticas
//
//  Created by Dayô Araújo on 25/05/26.
//

import Foundation
import SwiftUI

/// Coordinates the live text-based filter applied over the user's connections.
///
/// `SearchViewModel` holds the typed query and exposes the filtered subset that the `SearchView` renders
/// alongside the SpriteKit scene. The view mirrors SwiftData query results into `connections` on change.
@Observable
class SearchViewModel {
    /// Mirror of the SwiftData query result. Update from the view whenever connections change.
    var connections: [Connection] = []

    var searchText: String = ""
    var navPath: NavigationPath = NavigationPath()

    /// Computes the subset of connections matching the active search query, case- and diacritic-insensitive.
    var searchResults: [Connection] {
        guard !searchText.isEmpty else { return [] }
        return connections.filter { c in
            c.friend?.name.localizedStandardContains(searchText) ?? false
        }
    }

    /// Whether the user typed something but no friend matches.
    var hasEmptyResults: Bool {
        !searchText.isEmpty && searchResults.isEmpty
    }
}
