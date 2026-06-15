//
//  FriendsGroupsView.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 12/06/26.
//
import SwiftUI

struct FriendsGroupsFrame: View {
    /// The raw byte data of the image to be displayed.
    let imageData: Data
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var body: some View {
        if let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: width * 0.45,
                       height: height * 0.27)
                .clipShape(Circle())
        } else {
            // Fallback placeholder if the image data is corrupted or missing.
            RoundedRectangle(cornerRadius: 16)
                .frame(width: width * 0.45, height: height * 0.25)
                .foregroundColor(.gray)
        }
    }
}

#Preview {
    let mockImage = UIImage(named: "gallery")!
    let mockData = mockImage.pngData() ?? Data()
    return GalleryFrame(imageData: mockData)
        .preferredColorScheme(.dark)
}
