//
//  UserProfileView.swift
//  ConexoesAmizaticas
//
//  Created by Dayô Araújo on 26/05/26.
//

import SwiftUI
import SwiftData

/// A macroscopic overview of the user's entire social network.
///
/// `UserProfileView` is the presentational layer on top of `UserProfileViewModel`. It composes the header,
/// the summary stats and the `RelationshipChart`, mirroring SwiftData query results into the view model.
struct UserProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var vm: InitialViewModel
    @Query private var connections: [Connection]

    @State private var viewModel = UserProfileViewModel()
    @State private var showOnboardingTest = false

    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height

    var body: some View {
        ZStack {
            Circle()
                .foregroundStyle(.themeBackground)
                .frame(width: width * 2.17)
                .padding(.bottom, height * -0.18)

            VStack(spacing: 60) {
                VStack(spacing: 20) {
                    ProfileHeader(vm: $vm)
                    summaryStats
                }

                if viewModel.friendsByState.isEmpty {
                    Text("Sem amigos ainda")
                        .font(.custom("Bolota", size: 32))
                        .foregroundStyle(.lightBackground)
                        .frame(height: height * 0.35)
                } else {
                    RelationshipChart(
                        viewModel: viewModel,
                        size: CGSize(width: width * 0.8, height: height * 0.35)
                    )
                }

                #if DEBUG
                Button("Testar onboarding") {
                    showOnboardingTest = true
                }
                #endif
            }
            .padding(.top, height * 0.05)
        }
        .background(.lightBackground)
        .toolbar {
            ToolbarItem {
                NavigationLink {
                    EditProfileView(vm: $vm)
                } label: {
                    Image(systemName: "gear")
                        .font(.system(size: 24))
                        .foregroundColor(.black)
                }
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onChange(of: connections, initial: true) { _, newValue in
            viewModel.connections = newValue
        }
        #if DEBUG
        .fullScreenCover(isPresented: $showOnboardingTest) {
            CreatProfileView { newName, newImageData in
                vm.profile.editName(newName)
                if let newImageData {
                    vm.profile.editProfileImageData(newImageData)
                }
                try? modelContext.save()
                showOnboardingTest = false
            }
        }
        #endif
    }

    private var summaryStats: some View {
        HStack(spacing: 70) {
            VStack(alignment: .center) {
                Text("VOCÊ TEM")
                    .font(.custom("Sora-Regular", size: 12))
                Text("\(viewModel.friendCount) \(viewModel.friendCount == 1 ? "amigo" : "amigos")")
                    .font(.custom("Bolota", size: 24))
            }

            VStack(alignment: .center) {
                Text("ÚLTIMO ENCONTRO")
                    .font(.custom("Sora-Regular", size: 12))
                Text(viewModel.lastMeetingText)
                    .font(.custom("Bolota", size: 24))
            }
        }
        .foregroundStyle(.lightBackground)
    }

}

#Preview {
    @Previewable @State var viewModel = InitialViewModel()
    UserProfileView(vm: $viewModel)
        .modelContainer(for: AppSchema.models)
}
