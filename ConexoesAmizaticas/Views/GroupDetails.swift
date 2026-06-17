//
//  GroupDetails.swift
//  ConexoesAmizaticas
//
//  Created by Dayô Araújo on 17/06/26.
//

import SwiftUI
import SpriteKit

struct GroupDetails: View {
    var group: FriendGroup
    var height = UIScreen.main.bounds.height
    var width = UIScreen.main.bounds.width
    
    @State private var scene: FriendsScene
    
    init(group: FriendGroup) {
        self.group = group
        
        let initialScene = FriendsScene(
            size: UIScreen.main.bounds.size,
            connections: Set(group.connections),
            sceneType: .search
        )
        initialScene.scaleMode = .aspectFill
        
        self._scene = State(initialValue: initialScene)
    }
    
    var body: some View {
        ZStack {
            SpriteView(scene: scene)
                .clipShape(Circle())
                .frame(width: width * 1.91, height: height)
                .padding(.bottom)
            
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
                    
                    NavigationLink(value: AppRoute.search) {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.themeBackground)
    }
}

#Preview {
    GroupDetails(group: FriendGroup())
}
