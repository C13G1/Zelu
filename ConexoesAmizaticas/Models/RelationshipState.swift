//
//  RelationshipState.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 18/05/26.
//

import Foundation
import UIKit

/// Defines the current health and status of a friendship based on the connection score.
///
/// The state directly influences the visual representation of the connection in the SpriteKit scene,
/// determining its orbital radius, movement speed, and color.
enum RelationshipState: String, Codable, CaseIterable {
    case afastados    = "afastados"
    case distantes    = "distantes"
    case estaveis     = "estaveis"
    case proximos     = "proximos"
    case inseparaveis = "inseparaveis"

    /// The distance from the center node in the graphical visualizer.
    var orbitRadius: Double {
        switch self {
        case .afastados: return 100
        case .distantes: return 200
        case .estaveis: return 300
        case .proximos: return 400
        case .inseparaveis: return 500
        }
    }

    /// The velocity at which the node travels along its orbit.
    var orbitSpeed: Double {
        switch self {
        case .afastados: return 1
        case .distantes: return 2
        case .estaveis: return 3
        case .proximos: return 4
        case .inseparaveis: return 5
        }
    }

    /// The thematic color identifying this specific relationship state.
    var color: UIColor {
        switch self {
        case .afastados: return UIColor.themeAfastados
        case .distantes: return UIColor.themeDistantes
        case .estaveis: return UIColor.themeEstaveis
        case .proximos: return UIColor.themeProximos
        case .inseparaveis: return UIColor.themeInseparaveis
        }
    }

    var nodeSize: CGFloat {
        switch self {
        case .afastados:    return 64
        case .distantes:    return 80
        case .estaveis:     return 96
        case .proximos:     return 112
        case .inseparaveis: return 126
        }
    }

    var displayName: String {
        switch self {
        case .afastados:    return "Afastados"
        case .distantes:    return "Distantes"
        case .estaveis:     return "Estáveis"
        case .proximos:     return "Próximos"
        case .inseparaveis: return "Inseparáveis"
        }
    }
}
