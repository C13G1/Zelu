//
//  CreatProfileView.swift
//  ConexoesAmizaticas
//
//  Created by Jonas Fernando Nascimento Melo on 02/06/26.
//
import SwiftUI
import PhotosUI
import SwiftData

/// The initial setup flow for new users.
///
/// `CreatProfileView` is the presentational shell on top of `CreatProfileModel`. It collects the user's
/// base identity (name and avatar) and delegates form state, validation and persistence to the view model.
struct CreatProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = CreatProfileViewModel()
    
    /// Optional override invoked when the user taps "advance" instead of the default `createProfile`.
    /// Receives the trimmed name and the picked image data (nil if the user did not pick one).
    var onComplete: ((String, Data?) -> Void)?
    
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var body: some View {
        ZStack(alignment: .top) {
            
            VStack(spacing: height * 0.076) {
                
                PhotosPicker(selection: $viewModel.selectedPhoto, matching: .images) {
                    ZStack(alignment: .bottomTrailing){
                        Circle()
                            .frame(width: width * 0.545, height: width * 0.545)
                            .foregroundStyle(.themeYellow.opacity(0.4))
                            .overlay {
                                if let data = viewModel.profileImageData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .clipShape(Circle())
                                        .frame(width: width * 0.545, height: width * 0.545)
                                } else {
                                    Image("defaultPicture")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: width * 0.545, height: width * 0.545)
                                    HStack{
                                        
                                    }
                                }
                            }
                        ZStack{
                            Circle()
                                .frame(width: width * 0.102)
                                .foregroundStyle(.themeEstaveis)
                            Image(systemName: "pencil")
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                                .bold()
                        }
                        .padding(.trailing, width * 0.048)
                    }
                }
                .onChange(of: viewModel.selectedPhoto) { _, _ in
                    Task { await viewModel.loadSelectedPhoto() }
                }
                
                VStack(spacing: 2) {
                    TextField("" ,text: $viewModel.name,
                              prompt: Text("Seu Nome").foregroundStyle(.white))
                        .font(.custom("Bolota", size: 48))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.white)
                    Capsule()
                        .frame(width: width * 0.75, height: 5)
                        .foregroundStyle(.white)
                }
                .foregroundStyle(.white)
                
                Button {
                    if let onComplete {
                        onComplete(
                            viewModel.name.trimmingCharacters(in: .whitespaces),
                            viewModel.profileImageData
                        )
                    } else {
                        viewModel.createProfile(modelContext: modelContext)
                    }
                } label: {
                    Circle()
                        .frame(width: 88)
                        .foregroundStyle(.addFriendsCard)
                        .overlay {
                            Text("OK")
                                .font(.custom("Bolota", size: 36))
                                .foregroundStyle(.black)
                                .padding(.top, 6)
                        }
                    
                }
                .disabled(!viewModel.canProceed)
                .padding(.top, 40)
            }
        }
    }
}

#Preview {
    CreatProfileView()
        .modelContainer(for: AppSchema.models, inMemory: true)
}
