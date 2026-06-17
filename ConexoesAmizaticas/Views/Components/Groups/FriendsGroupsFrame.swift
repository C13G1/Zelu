//
//  FriendsGroupsView.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 12/06/26.
//
import SwiftUI

struct FriendsGroupsFrame: View {
    var group: FriendsGroup
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var body: some View {
        if let uiImage = UIImage(data: group.image) {
            VStack {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width * 0.45,
                           height: height * 0.27)
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
            // Fallback placeholder if the image data is corrupted or missing.
            Circle()
                .frame(width: width * 0.45, height: width * 0.45)
                .foregroundColor(.gray)
        }
    }
}

#Preview {
    let mockImage = UIImage(named: "defaultPicture")!
    let mockData = mockImage.pngData() ?? Data()
    var connections: [Connection] = []
    
    var group = FriendsGroup(name: "grupo 1", image: mockData, connections: connections)
    
    FriendsGroupsFrame(group: group)
        .preferredColorScheme(.dark)
}
