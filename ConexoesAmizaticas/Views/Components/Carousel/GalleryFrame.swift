//
//  GalleryFrame.swift
//  ConexoesAmizaticas
//
//  Created by Dayô Araújo on 22/05/26.
//

import SwiftUI

/// A standardized display container for user-uploaded images in the feed.
///
/// `GalleryFrame` ensures all images (regardless of their original aspect ratio) conform to the app's aesthetic
/// by cropping them into a uniform rounded rectangle with a prominent white stroke border.
struct GalleryFrame: View {
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
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white, lineWidth: 4)
                )
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
