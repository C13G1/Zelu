//
//  FriendsGroupsFrame.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 12/06/26.
//
import SwiftUI


/// Tappable group tile — circular photo ringed by the group's `averageConnectionStrength` color, with
/// its name below. Navigates to `GroupDetails`.
struct FriendsGroupsFrame: View {
    var group: FriendGroup
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var body: some View {
        NavigationLink(value: AppRoute.groupDetails(group)) {
            Group {
                if let uiImage = UIImage(data: group.image) {
                    VStack (spacing: 15){
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: width * 0.37,
                                   height: height * 0.17)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color(group.averageConnectionStrength.color), lineWidth: 10)
                            )
                        
                        Text(group.name)
                            .font(.custom("Sora-Bold", size: 20))
                            .foregroundStyle(.backgoundGreen)
                    }
                } else {
                    Circle()
                        .frame(width: width * 0.45, height: width * 0.45)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}


#Preview {
    let mockImage = UIImage(named: "defaultPicture")!
    let mockData = mockImage.pngData() ?? Data()
    var connections: [Connection] = []
    
    var group = FriendGroup(name: "grupo 1", image: mockData, connections: connections)
    
    FriendsGroupsFrame(group: group)
        .preferredColorScheme(.dark)
}
