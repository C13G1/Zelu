//
//  EditableAvatar.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 18/06/26.
//

import SwiftUI
import PhotosUI

/// A circular avatar with a pencil photo-picker badge, shared by the profile edit screens.
/// Shows `imageData` when valid and reports a new pick through `onSelect`.
struct EditableAvatar: View {
    let imageData: Data
    @Binding var selection: PhotosPickerItem?
    let onSelect: () async -> Void

    private let side = UIScreen.main.bounds.width * 0.75

    var body: some View {
        ZStack {
            if let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: side, height: side)
                    .clipShape(Circle())
            }

            PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
                Image(systemName: "pencil")
                    .foregroundStyle(.lightBackground)
                    .font(.title)
                    .padding(8)
                    .background(Color.green)
                    .cornerRadius(100)
            }
            .padding(.leading, UIScreen.main.bounds.width * 0.45)
            .padding(.top, UIScreen.main.bounds.height * 0.28)
        }
        .onChange(of: selection) { _, _ in
            Task { await onSelect() }
        }
    }
}
