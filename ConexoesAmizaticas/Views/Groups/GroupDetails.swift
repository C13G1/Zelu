//
//  GroupDetails.swift
//  ConexoesAmizaticas
//
//  Created by Dayô Araújo on 17/06/26.
//

import SwiftUI
import SpriteKit

struct GroupDetails: View {
    @Binding var navigation: NavigationPath
    var group: FriendGroup
    var height = UIScreen.main.bounds.height
    var width = UIScreen.main.bounds.width
    let clipCircle: Circle = {
        let circle = Circle()
        circle.frame(width: UIScreen.main.bounds.width * 1.91, height: UIScreen.main.bounds.height)

        return circle
    }()
    @State private var scene: FriendsScene = FriendsScene(size: UIScreen.main.bounds.size,
                                                          connections: Set(),
                                                          sceneType: .search
    )
    
    var body: some View {
        ZStack {
            SpriteView(scene: scene)
                .frame(width: width, height: height)
                .padding(.bottom)
                .mask{
                    Circle()
                        .frame(width: width * 1.91, height: height)
                        .foregroundStyle(.white)
                }
           
            VStack {
                Text(group.name)
                    .font(.custom("Bolota", size: 32))
                
                Text(group.averageConnectionStrength.displayName)
                    .font(.custom("Sora-ExtraBold", size: 24))
                    .foregroundStyle(Color(group.averageConnectionStrength.color))
                
                Spacer()
                
                HStack (spacing: width * 0.52){
                    NavigationLink(value: AppRoute.search) {
                        ZStack {
                            Circle()
                                .frame(width: width * 0.15)
                                .foregroundStyle(.lightBackground)
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.themeBackground)
                                .font(.title)
                                .bold()
                        }
                        .frame(width: width * 0.19, height: width * 0.19)
                        .background(.themeBackground)
                        .cornerRadius(100)
                    }
                    
                    NavigationLink(value: AppRoute.editGroup(group)) {
                        ZStack {
                            Circle()
                                .frame(width: width * 0.15)
                                .foregroundStyle(.lightBackground)
                            Image(systemName: "gear")
                                .foregroundStyle(.themeBackground)
                                .font(.largeTitle)
                                .fontWeight(.semibold)
                        }
                        .frame(width: width * 0.19, height: width * 0.19)
                        .background(.themeBackground)
                        .cornerRadius(100)
                    }
                }
            }
            .padding(.top, 45)
            .padding(.vertical, 50)
        }
        .onAppear {
            scene.updateConnections(receivedConnections: Set(group.connections))
            scene.onFriendTapped = { connection in
                DispatchQueue.main.async {
                    navigation.append(connection)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.themeBackground)
    }
}

#Preview {
    @Previewable @State var navigation: NavigationPath = NavigationPath()
    let mockImage = UIImage(named: "defaultPicture")!
    let mockData = mockImage.pngData() ?? Data()

    GroupDetails(navigation: $navigation, group: FriendGroup(name: "Preview", image: mockData, connections: [
        Connection(friend: User(name: "Jones")),
        Connection(friend: User(name: "Dayo")),
        Connection(friend: User(name: "Mathias")),
        Connection(friend: User(name: "Camis")),
        Connection(friend: User(name: "Thomas")),
        Connection(friend: User(name: "Bullet")),
    ]))
}
