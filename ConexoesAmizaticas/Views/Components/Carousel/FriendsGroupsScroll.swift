//
//  FriendsGroupsScroll.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 12/06/26.
//

import SwiftUI
import SwiftData

/// A 3D-styled, interactive carousel for browsing a connection's memory feed.
///
/// `PictureScroll` listens to horizontal drag gestures and uses trigonometric functions provided by `FriendFeedViewModel`
/// to calculate depth (`zIndex`), scale, and opacity for each `GalleryFrame`. This creates the illusion of
/// photos wrapped around a rotating virtual cylinder.
struct FriendsGroupsScroll: View {
    var viewModel: FriendsGroupsViewModel
    var arrowWidth = UIScreen.main.bounds.width * 0.09
    var arrowHeight = UIScreen.main.bounds.height * 0.03
    var frameWidth = UIScreen.main.bounds.width * 0.45
    var frameHeight = UIScreen.main.bounds.height * 0.25
    
    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
            
            if viewModel.friendsGroups.isEmpty {
                // Empty state indicating where photos will appear once uploaded.
                RoundedRectangle(cornerRadius: 16)
                    .stroke(style: StrokeStyle(lineWidth: 5, dash: [8]))
                    .foregroundStyle(.gray.opacity(0.5))
                    .frame(width: frameWidth, height: frameHeight)
            } else {
                ForEach(Array(viewModel.friendsGroups.enumerated()), id: \.element.id) { index, group in
                    let imageData = group.image
                    FriendsGroupsFrame(imageData: imageData)
                        .scaleEffect(viewModel.scaleEffect(index))
                        .zIndex(viewModel.zIndex(index))
                        .rotationEffect(.degrees(viewModel.rotationEffect(index)))
                        .offset(
                            x: viewModel.xOffset(index),
                            y: viewModel.yOffset(index)
                        )
                        .opacity(viewModel.opacity(index))
                        .onTapGesture {
                            // Triggers the deletion confirmation overlay located in the parent view.
                            withAnimation {
                                viewModel.friendsGroupToDelete = group
                            }
                        }
                    Text("\(group.name)")
                }
            }
            
            // Visual indicators guiding the user to scroll horizontally.
            HStack {
                Image("galleryArrow")
                    .resizable()
                    .frame(width: arrowWidth, height: arrowHeight)
                
                Spacer()
                
                Image("galleryArrow")
                    .resizable()
                    .scaleEffect(x: -1, y: 1)
                    .frame(width: arrowWidth, height: arrowHeight)
            }
            .frame(width: UIScreen.main.bounds.width * 0.78)
        }
        // Attaches the physics-based drag tracking to the entire scroll area.
        .gesture(
            DragGesture()
                .onChanged { value in
                    viewModel.onDragChanged(value: value)
                }
                .onEnded { value in
                    viewModel.onDragEnded(value: value)
                }
        )
    }
}
