//
//  EditFriendProfileView.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 27/05/26.
//

import SwiftUI
import PhotosUI
import SwiftData

/// Form screen used to rename a friend or change their avatar.
///
/// `EditFriendProfileView` is the presentational layer on top of `EditFriendProfileViewModel`. It surfaces
/// a photo picker and a name field; the view model holds the editable state and commits changes on save.
struct EditFriendProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: EditFriendProfileViewModel?
    @FocusState private var isNameFocused: Bool
    
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height

    init(connection: Connection) {
        _viewModel = State(initialValue: EditFriendProfileViewModel(connection: connection, modelContext: modelContext))
    }

    var body: some View {
        if let viewModel {
            @Bindable var bindable = viewModel

            VStack(spacing: 32) {
                EditableAvatar(imageData: viewModel.connection.friend?.profilePicture ?? Data(),
                               selection: $bindable.selectedPhoto) {
                    await viewModel.commitSelectedPhoto()
                }

                VStack(spacing: 2) {
                    TextField("Amigo", text: $bindable.name)
                        .font(.custom("Bolota", size: 48))
                        .multilineTextAlignment(.center)
                        .focused($isNameFocused)
                        .onChange(of: viewModel.name) { _, _ in
                            viewModel.commitName()
                        }
                        .onSubmit { isNameFocused = false }

                    Capsule()
                        .frame(width: width * 0.75, height: 5)
                }
            }
            .foregroundStyle(.black)
            .onTapGesture { isNameFocused = false }
        } else {
            Color.clear
        }
    }
}

#Preview {
    let mockConnection: Connection = {
        let mockImage = UIImage(named: "gallery") ?? UIImage()
        let mockData = mockImage.pngData() ?? Data()
        let c = Connection(friend: User(name: "Juliana"))
        
        for _ in 0..<5 {
            let post = Post(images: [mockData])
            c.feedManager?.addPost(post)
        }
        
        return c
    }()
    
    EditFriendProfileView(connection: mockConnection)
}
