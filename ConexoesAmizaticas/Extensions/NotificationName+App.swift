//
//  NotificationName+App.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 27/05/26.
//

import Foundation

extension Notification.Name {
    /// Broadcast right after a meeting is registered (either as a brand new connection or by
    /// updating an existing one). Views that mirror the connections list use this signal to
    /// refresh their derived state without waiting for the next SwiftUI pass.
    static let meetingConfirmed = Notification.Name("meetingConfirmed")

    /// Broadcast when the current user edits a friend's name or avatar so that downstream views
    /// (carousels, profiles) can invalidate any cached representation of the profile.
    static let friendProfileUpdated = Notification.Name("friendProfileUpdated")
    
    static let GroupUpdated = Notification.Name("GroupUpdated")
}
