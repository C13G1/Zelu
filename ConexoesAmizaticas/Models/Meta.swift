//
//  Meta.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 18/05/26.
//

import Foundation

/// Represents the commitment goal set by the user to meet a specific friend.
enum Meta: String, Codable {
    case nenhuma   = "nenhuma"
    case semanal   = "semanal"
    case quinzenal = "quizenal"
    case mensal    = "mensal"
    case bimestral = "bimestral"
    case semestral = "semestral"
    case anual     = "anual"

    var displayText: String {
        switch self {
        case .nenhuma:   return "Nenhuma"
        case .semanal:   return "1 vez por semana"
        case .quinzenal: return "a cada 15 dias"
        case .mensal:    return "1 vez por mês"
        case .bimestral: return "a cada 3 meses"
        case .semestral: return "a cada 6 meses"
        case .anual:     return "1 vez por ano"
        }
    }

    /// The numeric equivalent of the goal in days.
    var days: Int {
        switch self {
        case .nenhuma:   return 0
        case .semanal:   return 7
        case .quinzenal: return 15
        case .mensal:    return 30
        case .bimestral: return 90
        case .semestral: return 180
        case .anual:     return 360
        }
    }
}


