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
    @State private var viewModel: EditFriendProfileViewModel

    init(connection: Connection) {
        _viewModel = State(initialValue: EditFriendProfileViewModel(connection: connection))
    }

    var body: some View {
        @Bindable var bindable = viewModel

        VStack(spacing: 32) {
            PhotosPicker(selection: $bindable.selectedPhoto, matching: .images) {
                ZStack {
                    Circle()
                        .frame(width: 120, height: 120)
                        .foregroundStyle(.gray.opacity(0.15))
                    if let data = viewModel.profileImageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .clipShape(Circle())
                            .frame(width: 120, height: 120)
                    } else {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 44))
                            .foregroundStyle(.gray)
                    }
                    
                    ZStack {
                        Circle()
                            .frame(width: UIScreen.main.bounds.width * 0.09, height: UIScreen.main.bounds.width * 0.1)
                            .foregroundStyle(.gray)
                        
                        Image(systemName: "pencil")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                    .padding(.top, UIScreen.main.bounds.height * 0.1)
                    .padding(.leading, UIScreen.main.bounds.height * 0.1)
                }
            }
            .onChange(of: viewModel.selectedPhoto) { _, _ in
                Task { await viewModel.loadSelectedPhoto() }
            }

            TextField("Nome do amigo", text: $bindable.name)
                .font(.custom("Bolota", size: 24))
                .padding()
                .background(.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 40)
        }
        .padding(.top, 40)
        .background(.lightBackground)
        .navigationTitle("Editar Amigo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Salvar") {
                    viewModel.saveChanges(modelContext: modelContext)
                    dismiss()
                }
                .disabled(!viewModel.canSave)
            }
        }
    }
}

#Preview {
    NavigationStack {
        EditFriendProfileView(connection: Connection(friend: User(name: "Juliana")))
    }
    .modelContainer(for: AppSchema.models, inMemory: true)
}
