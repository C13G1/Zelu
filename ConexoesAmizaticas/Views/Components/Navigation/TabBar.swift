//
//  TabBar.swift
//  ConexoesAmizaticas
//
//  Created by Dayô Araújo on 26/05/26.
//

import SwiftUI

/// The custom bottom navigation bar for the main interface.
///
/// `TabBar` utilizes a `SemiCircle` shape to create a distinct, arched bottom edge. It holds the primary navigation
/// routes branching out from the `InitialView`, specifically the `SearchView` and the `BLEView`.
struct TabBar: View {
    @Binding var viewModel: InitialViewModel
    @Binding var navigation: NavigationPath
    var user: User
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var body: some View {
        ZStack {
            SemiCircle()
                .fill(Color.themeBackground)
                .frame(width: width, height: 100)
            
            HStack {
                NavigationLink(value: AppRoute.search) {
                    ZStack {
                        Circle()
                            .frame(width: width * 0.15)
                            .foregroundStyle(.lightBackground)
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.black)
                            .font(.title2)
                            .bold()
                    }
                    .frame(width: width * 0.19, height: width * 0.19)
                    .background(.themeBackground)
                    .cornerRadius(100)                }
                
//                NavigationLink {
//                    SearchView(viewModel: $viewModel)
//                } label: {
// 
//                }
                
                Spacer()
                
                // Central App Logo
                Image("zELu")
                    .padding(.bottom, height * 0.07)
                
                Spacer()
                
                NavigationLink (destination: NearbyPeopleView(profile: user)) {
                    ZStack {
                        Circle()
                            .frame(width: width * 0.15)
                            .foregroundStyle(.lightBackground)
                        Image(systemName: "person.2.badge.plus.fill")
                            .foregroundStyle(.black)
                            .font(.title2)
                    }
                    .frame(width: width * 0.19, height: width * 0.19)
                    .background(.themeBackground)
                    .cornerRadius(100)                }
                
//                NavigationLink (destination: BLEView(profile: user)) {
//                    ZStack {
//                        Circle()
//                            .frame(width: width * 0.15)
//                            .foregroundStyle(.lightBackground)
//                        Image(systemName: "person.2.badge.plus.fill")
//                            .foregroundStyle(.black)
//                            .font(.title2)
//                    }
//                    .frame(width: width * 0.19, height: width * 0.19)
//                    .background(.themeBackground)
//                    .cornerRadius(100)
//                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, width * 0.38) 
        }
        .navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .search:
                SearchView(viewModel: $viewModel, navigation: $navigation)
            case .ble:
                BLEView(profile: viewModel.profile)
            case .setMeta(_):
                EmptyView()
            }
        }
    }
}
