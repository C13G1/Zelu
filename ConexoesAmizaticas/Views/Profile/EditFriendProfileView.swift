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
                ZStack {
                    if let uiImage = UIImage(data: viewModel.connection.friend.profilePicture) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: width * 0.75, height: width * 0.75)
                            .clipShape(Circle())
                    }

                    PhotosPicker(selection: $bindable.selectedPhoto, matching: .images, photoLibrary: .shared()) {
                        Image(systemName: "pencil")
                            .foregroundStyle(.lightBackground)
                            .font(.title)
                            .padding(8)
                            .background(Color.green)
                            .cornerRadius(100)
                    }
                    .padding(.leading, width * 0.45)
                    .padding(.top, height * 0.28)
                }
                .onChange(of: viewModel.selectedPhoto) { _, _ in
                    Task { await viewModel.commitSelectedPhoto() }
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
            c.feedManager.addPost(post)
        }
        
        return c
    }()
    
    EditFriendProfileView(connection: mockConnection)
}
