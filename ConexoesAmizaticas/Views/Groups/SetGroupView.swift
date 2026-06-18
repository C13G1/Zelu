//
//  SetGroupView.swift
//  ConexoesAmizaticas
//
//  Created by Jonas Fernando Nascimento Melo on 17/06/26.
//

import SwiftUI
import PhotosUI
import SwiftData

/// Final step of group creation — set the group's photo and name, review the members, and save it.
struct SetGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State var viewModel: CreatGroupViewModel
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    init(selectedConnections: [Connection]){
        self.viewModel = CreatGroupViewModel(selectedConnections: selectedConnections)
    }
    var body: some View {
        VStack(spacing: height * 0.0422) {
            
            PhotosPicker(selection: $viewModel.selectedPhoto, matching: .images) {
                ZStack(alignment: .bottomTrailing){
                    Circle()
                        .frame(width: width * 0.394, height: width * 0.394)
                        .foregroundStyle(.themeYellow.opacity(0.4))
                        .overlay {
                            if let data = viewModel.profileImageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: width * 0.394, height: width * 0.394)
                                    .clipShape(Circle())
                            } else {
                                Image("defaultPicture")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: width * 0.394, height: width * 0.394)
                                HStack{
                                    
                                }
                            }
                        }
                    //                    ZStack{
                    //                        Circle()
                    //                            .frame(width: width * 0.102)
                    //                            .foregroundStyle(.themeEstaveis)
                    //                        Image(systemName: "pencil")
                    //                            .font(.system(size: 22))
                    //                            .foregroundStyle(.white)
                    //                            .bold()
                    //                    }
                    //                    .padding(.trailing, width * 0.001)
                }
            }
            .onChange(of: viewModel.selectedPhoto) { _, _ in
                Task { await viewModel.loadSelectedPhoto() }
            }
            
            VStack(spacing: 2) {
                TextField("" ,text: $viewModel.name,
                          prompt: Text("Nome do Grupo").foregroundStyle(.black))
                .font(.custom("Bolota", size: 32))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.black)
                Capsule()
                    .frame(width: width * 0.75, height: 5)
                    .foregroundStyle(.black)
            }
            .foregroundStyle(.white)
            
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 24) {
                ForEach(viewModel.selectedConnections) { connection in
                    GroupMemberCell(connection: connection) {
                        viewModel.removeConnection(connection)
                    }
                }
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(Color.black, lineWidth: 1)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, UIScreen.main.bounds.width * 0.055)
            
        }
        .toolbar{
//            ToolbarItem(placement: .cancellationAction) {
//                Button {
//                    dismiss()
//                } label: {
//                    Image(systemName: "xmark")
//                        .resizable()
//                }
//            }
            ToolbarItem{
                Button {
                    viewModel.createGroup(modelContext: modelContext)
                    dismiss()
                } label: {
                    Image(systemName: "checkmark")
                        .resizable()
                    
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .dismissKeyboardOnTap()
    }
}

#Preview {
    @Previewable var selected: [Connection] = []
    SetGroupView(selectedConnections: selected)
}
