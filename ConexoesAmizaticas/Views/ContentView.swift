//
//  ContentView.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 14/05/26.
//

import SwiftUI
import SwiftData

/// The root routing component of the application.
///
/// `ContentView` determines the initial presentation state based on the existence of a user profile
/// in the local SwiftData container. It seamlessly bridges the user into the `OnboardingView` on first launch
/// or directs them to the main `InitialView` dashboard on subsequent sessions.
struct ContentView: View {
    @Query private var users: [User]
    
    var body: some View {
        ZStack{
            InitialView()
            if users.isEmpty {
                Rectangle()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(0.9)
                    .ignoresSafeArea(.all)
                OnboardingView()
            }
        }
    }
}
