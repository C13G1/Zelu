//
//  CreatGroupSheet.swift
//  ConexoesAmizaticas
//
//  Created by Jonas Fernando Nascimento Melo on 15/06/26.
//

// TODO: Bullet Plz componentiza e documenta este arquivo <3 
import SwiftUI
import SwiftData
struct ChooseGroupMembersView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isChoosingGroupMembers: Bool
    @State private var searchText = ""
    @State var numSelecteds = 0
//    @Query var connections: [Connection]
    @State var connections: [Connection] = [
        Connection(friend: User(name: "bullet")),
        Connection(friend: User(name: "camis")),
        Connection(friend: User(name: "jones")),
        Connection(friend: User(name: "mathias")),
        Connection(friend: User(name: "dayo")),
        Connection(friend: User(name: "thomas")),
    ]
    @Binding var selectedConecctions: [Connection]

    var grouped: [(key: String, value: [Connection])] {
        let filtered = searchText.isEmpty
        ? connections
        : connections.filter {
            $0.friend.getName().localizedStandardContains(searchText)
        }
        
        let sorted = filtered.sorted {
            $0.friend.getName() < $1.friend.getName()
        }
        
        let dict = Dictionary(grouping: sorted) { connection in
            String(connection.friend.getName().prefix(1)).uppercased()
        }
        
        return dict.sorted { $0.key < $1.key }
    }
    
    let columns = [GridItem(.adaptive(minimum: 80), spacing: 16)]
    
    var body: some View {
        VStack{
            ZStack{
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(Color.black, lineWidth: 1)
                    .foregroundStyle(.white)
                    .frame(width: UIScreen.main.bounds.width * 0.890, height: UIScreen.main.bounds.height * 0.152)
                    .overlay {
                        ScrollView(.horizontal,showsIndicators: false){
                            LazyHGrid(rows: [GridItem(.flexible())], spacing: 16){
                                ForEach(selectedConecctions){ connection in
                                    VStack{
                                        Image(uiImage: UIImage(data: connection.friend.profilePicture) ?? UIImage(named: "defaultPicture")!)
                                            .resizable()
                                            .frame(width: UIScreen.main.bounds.width * 0.16, height: UIScreen.main.bounds.width * 0.16)
                                            .clipShape(Circle())
                                            .overlay {
                                                Circle()
                                                    .stroke(Color(uiColor: connection.metaManager.currentRelationshipState.color), lineWidth: 3)
                                            }
                                        Text(connection.friend.name)
                                    }
                                }
                            }
                            .padding()
                        }
                    }
            }
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(grouped, id: \.key) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(section.key)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                            
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(section.value) { connection in
                                    VStack{
                                        Image(uiImage: UIImage(data: connection.friend.profilePicture) ?? UIImage(named: "defaultPicture")!)
                                            .resizable()
                                            .frame(width: UIScreen.main.bounds.width * 0.16, height: UIScreen.main.bounds.width * 0.16)
                                            .clipShape(Circle())
                                            .overlay {
                                                Circle()
                                                    .stroke(Color(uiColor: connection.metaManager.currentRelationshipState.color), lineWidth: 3)
                                            }
                                        Text(connection.friend.name)
                                    }
                                    .onTapGesture {
                                        if let index = selectedConecctions.firstIndex(where: { $0.id == connection.id }) {
                                            selectedConecctions.remove(at: index)
                                        } else {
                                            let insertIndex = selectedConecctions.firstIndex(where: {
                                                $0.friend.getName() > connection.friend.getName()
                                            }) ?? selectedConecctions.endIndex
                                            selectedConecctions.insert(connection, at: insertIndex)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        }
        .navigationTitle("novo grupo")
        .toolbar{
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .resizable()
                }
            }
            ToolbarItem{
                Button {
                    isChoosingGroupMembers = false
                } label: {
                    Image(systemName: "arrow.right")
                        .resizable()
                    
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview {
    @Previewable @State var isChoosingGroupMembers = false
    @Previewable @State var selectedConecctions: [Connection] = []
    ChooseGroupMembersView(isChoosingGroupMembers: $isChoosingGroupMembers, selectedConecctions: $selectedConecctions)
}
