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
    /// Whether this card is the centered one. Only the centered card opens; a side card first rotates to
    /// the center so it can be seen before being accessed.
    var isCentered: Bool = true
    /// Brings this card to the center of the carousel (used when a side card is tapped).
    var onFocus: () -> Void = {}
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height

    var body: some View {
        if isCentered {
            NavigationLink(value: AppRoute.groupDetails(group)) {
                cardContent
            }
        } else {
            Button(action: onFocus) {
                cardContent
            }
            .buttonStyle(.plain)
        }
    }

    private var cardContent: some View {
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


#Preview {
    let mockImage = UIImage(named: "defaultPicture")!
    let mockData = mockImage.pngData() ?? Data()
    let connections: [Connection] = []

    let group = FriendGroup(name: "grupo 1", image: mockData, connections: connections)
    
    FriendsGroupsFrame(group: group)
        .preferredColorScheme(.dark)
}
