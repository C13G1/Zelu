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
    @State private var isHidden = true
    @Binding var viewModel: InitialViewModel
    @Binding var navigation: NavigationPath
    var user: User
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var body: some View {
        VStack (spacing: -47){
                SemiCircle()
                    .fill(Color.themeBackground)
                    .frame(width: width * 1.05, height: 100)
                    .overlay() {
                        ZStack {
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
                                
                                Spacer()
                                
                                // Central App Logo
                                Image("zELu")
                                    .padding(.bottom, height * 0.07)
                                
                                Spacer()
                                
                                NavigationLink(destination: NearbyPeopleView(profile: user)) {
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
                                    .cornerRadius(100)
                                }
                            }
                        }
                        .padding(.horizontal, 25)
                        .padding(.bottom, width * 0.38)
                        
                    }
            
            FriendsGroupsView()
                .frame(width: width)
            
        }
        .navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .search:
                SearchView(viewModel: $viewModel, navigation: $navigation)
            case .ble:
                BLEView(profile: viewModel.profile)
            case .setMeta(let friendVM):
                SetMetaView(viewModel: friendVM)
            case .groupDetails(let group):
                GroupDetails(navigation: $navigation, group: group)
            case .editGroup(let group):
                EditGroupView(group: group)
            }
        }
        .offset(y: isHidden ? UIScreen.main.bounds.height * 0.19 : -UIScreen.main.bounds.height * 0.25)
        .animation(.spring(), value: isHidden)
        .gesture(SwipeUpGesture)
    }
    
    var SwipeUpGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onEnded { value in
                if value.translation.height < -20 {
                    isHidden = false
                } else if value.translation.height > 20 {
                    isHidden = true
                }
            }
    }
}


#Preview {
    InitialView()
}
