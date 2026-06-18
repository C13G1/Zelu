//
//  EditGroupsView.swift
//  ConexoesAmizaticas
//
//  Created by Jonas Fernando Nascimento Melo on 17/06/26.
//

import SwiftUI
import PhotosUI
import SwiftData

/// Screen to edit an existing group — change its photo, name and members, or delete it.
struct EditGroupView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var navigation: NavigationPath
    @State var viewModel: EditGroupViewModel?
    @FocusState private var isNameFocused: Bool
    @State var isSheetShowing = false
    @State private var showDeleteConfirm = false
    @State var selectedConecctions: [Connection]
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height

    init(group: FriendGroup, navigation: Binding<NavigationPath>) {
        _navigation = navigation
        _selectedConecctions = State(initialValue: group.connections)

        _viewModel = State(initialValue:EditGroupViewModel(group: group,modelContext: modelContext))
    }
    var body: some View {
        if let viewModel {
            @Bindable var bindable = viewModel
            VStack(spacing: 22) {
                ZStack(alignment: .bottomTrailing){
                    if let uiImage = UIImage(data: viewModel.group.image) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: width * 0.508, height: width * 0.508)
                            .clipShape(Circle())
                        
                        PhotosPicker(selection: $bindable.selectedPhoto, matching: .images, photoLibrary: .shared()) {
                            Image(systemName: "pencil")
                                .foregroundStyle(.lightBackground)
                                .font(.system(size: 18))
                                .bold()
                                .padding(8)
                                .background(Color.orange)
                                .cornerRadius(100)
                            
                        }
                        .padding(.trailing, width * 0.045)
                        
                    }
                }
                .onChange(of: viewModel.selectedPhoto) { _, _ in
                    Task { await viewModel.commitSelectedPhoto() }
                }
                
                VStack() {
                    TextField("Amigo", text: $bindable.name)
                        .font(.custom("Bolota", size: 24))
                        .multilineTextAlignment(.center)
                        .focused($isNameFocused)
                        .onChange(of: viewModel.name) { _, _ in
                            viewModel.commitName()
                        }
                        .onSubmit { isNameFocused = false }
                    
                    Capsule()
                        .frame(width: width * 0.768, height: 2)
                }
                .foregroundStyle(.black)
                .onTapGesture { isNameFocused = false }
                
                Text("integrantes do grupo")
                    .font(.custom("Sora", size: 16))
                    .padding(.top, height * 0.05)
                
                VStack(spacing: height * 0.014){
                    Button {
                        isSheetShowing.toggle()
                    } label: {
                        HStack{
                            Image(systemName: "plus")
                                .foregroundStyle(.black)
                                .font(.system(size: 16))
                                .padding(8)
                                .background(.addButtonBackground)
                                .cornerRadius(100)
                            
                            Text("adicionar membros")
                                .font(.custom("Sora", size: 14))
                                .foregroundStyle(.black)
                            Spacer()
                        }
                    }
                    
                    Capsule()
                        .frame(width: width * 0.773, height: 1)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: width * 0.04) {
                        ForEach(viewModel.group.connections) { connection in
                            GroupMemberCell(connection: connection) {
                                viewModel.removeConnection(connection)
                            }
                        }
                    }

                }
                .padding( height * 0.014)
                .background {
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(Color.black, lineWidth: 1)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, UIScreen.main.bounds.width * 0.08)
                
                Button {
                    showDeleteConfirm = true
                } label: {
                    Text("apagar grupo")
                        .foregroundStyle(.red)
                        .font(.custom("Sora", size: 15))
                }
                .padding(.top, height * 0.049)
            }
            .alert("Apagar grupo?", isPresented: $showDeleteConfirm) {
                Button("Apagar", role: .destructive) {
                    viewModel.deletGroup(context: modelContext)
                    // Pop straight back to the groups list — the `GroupDetails` screen below in the
                    // stack still points at the now-deleted group and would crash if shown.
                    navigation = NavigationPath()
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Criar um novo grupo exigirá uma nova compra.")
            }
            .sheet(isPresented: $isSheetShowing) {
                NavigationStack{
                    ChooseGroupMembersView(isChoosingGroupMembers: $isSheetShowing, selectedConecctions: $selectedConecctions)
                }
            }
            .onChange(of: isSheetShowing) {
                viewModel.group.connections = selectedConecctions
            }
            .dismissKeyboardOnTap()
        }
    }
}

#Preview {
    let mockImage = UIImage(named: "defaultPicture")!
    let mockData = mockImage.pngData() ?? Data()
    let friendsGroup = FriendGroup(name: "Grupo Preview", image: mockData, connections: [
        Connection(friend: User()),
        Connection(friend: User()),
        Connection(friend: User()),
        Connection(friend: User()),
        Connection(friend: User()),
        Connection(friend: User()),
        Connection(friend: User()),
        Connection(friend: User()),
    ])
    EditGroupView(group: friendsGroup, navigation: .constant(NavigationPath()))
}
