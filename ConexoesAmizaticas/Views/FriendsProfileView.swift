//
//  FriendsProfileView.swift
//  ConexoesAmizaticas
//
//  Created by Jonas Fernando Nascimento Melo on 20/05/26.
//

import SwiftUI
import SwiftData
import Aptabase

/// A comprehensive dashboard detailing a specific metaManager.
///
/// `FriendsProfileView` aggregates the shared memory feed (via `PictureScroll`) and the analytical relationship metrics.
/// It operates as the central hub for interacting with a specific `Connection`, allowing the user to view goals,
/// register new memories, or navigate to settings (`SetMetaView`).
struct FriendsProfileView: View {
    @Environment(\.modelContext) private var modelContext

    /// Controls the initial "New Friend" tutorial overlay to establish goals right after pairing.
    @AppStorage("SetMetaOnboarding") var SetMetaOnboarding: Bool = false
    @Environment(\.dismiss) private var dismiss
    @State var blurLevel: CGFloat = 0.0
    var viewModel: FriendProfileViewModel
    private let connectionID: UUID

    @Query private var connections: [Connection]
    @Query private var allUsers: [User]
    @State private var refreshToken = 0

    /// The localized view model handling the complex swipe gestures and deletion states for the photo carousel.
    @State private var feedViewModel: FriendFeedViewModel

    private var ownUser: User? {
        let friendIDs = Set(connections.map { $0.friend.id })
        return allUsers.first { !friendIDs.contains($0.id) }
    }

    private var lastMeetDaysText: String {
        guard let lastMet = viewModel.getLastMeet() else { return "nunca" }
        let days = Calendar.current.dateComponents([.day], from: lastMet, to: .now).day ?? 0
        if days == 0 { return "hoje" }
        return "há \(days) dias"
    }

    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height

    init(connection: Connection) {
        self.viewModel = FriendProfileViewModel(connection: connection)
        self.connectionID = connection.id
        self._feedViewModel = State(initialValue: FriendFeedViewModel(connection: connection))
    }

    var body: some View {
        ZStack {
            ZStack {
                PictureScroll(viewModel: feedViewModel)
                    .padding(.top, height * 0.55)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Circle()
                    .frame(width: width * 1.6)
                    .foregroundStyle(.friendProfileBackground)
                    .padding(.top, (height * -0.6))

                VStack(spacing: 4) {
                    ZStack(alignment: .bottomTrailing) {
                        Image(uiImage: viewModel.getFriendImage() ??
                              UIImage(named: "defaultPicture")!)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 108, height: 108)
                            .clipShape(Circle())
                            .padding(.top)
                            .id(refreshToken)
                    }
                    .padding(.top, 10)

                    Text(viewModel.getFriendName().uppercased())
                        .font(.custom("Bolota", size: 48))
                        .padding(.top, 8)
                        .frame(width: width * 0.8)
                        .fontWeight(.semibold)

                    FriendStatsRow(viewModel: viewModel, lastMeetText: lastMeetDaysText)

                    RecordMomentButton(color: viewModel.getProfileColor()) {
                        BLEView(profile: ownUser ?? User())
                    }

                    AddPictureButton(viewModel: feedViewModel, color: viewModel.getProfileColor())
                        .padding(.top, 35)
                }
                .padding(.bottom, height * 0.3)

                if SetMetaOnboarding {
                    Rectangle()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(0.6)
                        .ignoresSafeArea(.all)
                }
            }
            .environment(\.colorScheme, .light)
            .onAppear {
                Aptabase.shared.trackEvent("screen_view", with: [
                    "name": "friend_profile",
                    "relationship_state": viewModel.connection.metaManager.currentRelationshipState.rawValue
                ])
            }
            .onReceive(NotificationCenter.default.publisher(for: .friendProfileUpdated)) { _ in
                refreshToken += 1
            }
            .onChange(of: connections) { _, newConnections in
                if !newConnections.contains(where: { $0.id == connectionID }) {
                    dismiss()
                }
            }
            .background(Color.black)
            .blur(radius: blurLevel + (feedViewModel.postToDelete != nil ? 10 : 0))
            .onAppear {
                blurLevel = SetMetaOnboarding ? 5 : 0
            }

            if SetMetaOnboarding {
                VStack {
                    Text("novo amigo\nadicionado!")
                        .font(.custom("Bolota", size: 32))
                        .foregroundStyle(.friendProfileBackground)
                    Text("altere a sua meta com\n\(viewModel.getFriendName()) aqui!")
                        .font(.custom("Sora", size: 20))
                        .foregroundStyle(.friendProfileBackground)
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)
                }
                .padding(.bottom, height * 0.0985)
            }

            if let post = feedViewModel.postToDelete {
                ConfirmationOverlay(
                    imageData: post.images.first,
                    title: "QUER MESMO DELETAR ESTE MOMENTO?",
                    description: "Esta ação é permanente e a foto será apagada da conexão.",
                    confirmIcon: "trash",
                    onCancel: { withAnimation { feedViewModel.postToDelete = nil } },
                    onConfirm: {
                        if let id = feedViewModel.postToDelete?.id {
                            feedViewModel.deletePost(id: id, modelContext: modelContext)
                        }
                        withAnimation { feedViewModel.postToDelete = nil }
                    }
                )
            }
        }
        .toolbar {
            ToolbarItem {
                NavigationLink(destination: SetMetaView(viewModel: viewModel)) {
                    ZStack {
                        if SetMetaOnboarding {
                            Circle()
                                .frame(height: UIScreen.main.bounds.height * 0.063)
                                .foregroundStyle(.white)
                        }
                        Image(systemName: "gear")
                            .font(.system(size: 24))
                            .foregroundColor(.black)
                    }
                }
            }
            .sharedBackgroundVisibility(.hidden)
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

    return FriendsProfileView(connection: mockConnection)
}
