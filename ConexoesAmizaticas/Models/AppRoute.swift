//
//  AppRoute.swift
//  ConexoesAmizaticas
//
//  Created by Jonas Fernando Nascimento Melo on 09/06/26.
//

import Foundation
 
/// Enum centralizado de todas as rotas de navegação do app.
/// Todos os NavigationLink usam `NavigationLink(value:)` com esse enum —
/// o NavigationStack do InitialView é o único responsável por resolver os destinos.
enum AppRoute: Hashable {
    // Optional so general search (nil = all contacts) is distinct from a group's search (its members,
    // possibly empty). An empty array means "this group has no members", not "search everyone".
    case search([Connection]?)
    case ble
    case setMeta(FriendProfileViewModel)
    case groupDetails(FriendGroup)
    case editGroup(FriendGroup)

    static func == (lhs: AppRoute, rhs: AppRoute) -> Bool {
        switch (lhs, rhs) {
        case (.search(let a), .search(let b)): return a == b
        case (.ble, .ble): return true
        case (.setMeta(let a), .setMeta(let b)):
            // Compara pelo ID da connection para não depender do ViewModel ser Equatable
            return a.connection.id == b.connection.id
        case (.groupDetails(let a), .groupDetails(let b)): return a == b
        case (.editGroup(let a), .editGroup(let b)): return a == b
        default: return false
        }
    }
 
    func hash(into hasher: inout Hasher) {
        switch self {
        case .search(let filterConnections):
            hasher.combine(0)
            hasher.combine(filterConnections)
        case .ble:
            hasher.combine(1)
        case .setMeta(let vm):
            hasher.combine(2)
            hasher.combine(vm.connection.id)
        case .groupDetails(let group):
            hasher.combine(3)
            hasher.combine(group)
        case .editGroup(let group):
            hasher.combine(4)
            hasher.combine(group)
        }
    }
}
