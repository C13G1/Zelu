//
//  VacuoView.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 24/05/26.
//

import SwiftUI
import SwiftData
import SpriteKit
import Aptabase

/// A dedicated recovery environment for deeply decayed friendships.
///
/// `VacuoView` is the presentational shell over `VacuoViewModel`. It surfaces the SpriteKit "void" scene
/// alongside the `VacuoTutorialOverlay` and a rescue confirmation overlay, mirroring SwiftData query
/// results into the view model on every change.
struct VacuoView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allConnections: [Connection]

    @State private var viewModel = VacuoViewModel()

    @State private var voidScene: FriendsScene = {
        let s = FriendsScene(size: UIScreen.main.bounds.size, connections: Set(), sceneType: .search)
        s.scaleMode = .aspectFill
        s.backgroundColor = .clear
        return s
    }()

    private var tutorialSampleImage: UIImage {
        let data = viewModel.vacuumConnections.first?.friend?.profilePicture
            ?? allConnections.first?.friend?.profilePicture
        return data.flatMap(UIImage.init(data:)) ?? UIImage(named: "DefaultPicture") ?? UIImage()
    }

    var body: some View {
        @Bindable var bindable = viewModel

        ZStack {
            backgroundLayer
                .blur(radius: viewModel.focusedConnection != nil ? 10 : 0)

            if let connection = viewModel.focusedConnection {
                rescueOverlay(for: connection)
            }

            if viewModel.showTutorial {
                VacuoTutorialOverlay(
                    step: $bindable.tutorialStep,
                    sampleImage: tutorialSampleImage,
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.showTutorial = false
                            viewModel.tutorialStep = 0
                        }
                    }
                )
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
        .toolbar(viewModel.showTutorial ? .hidden : .visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Image("void")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 28)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.tutorialStep = 0
                        viewModel.showTutorial = true
                    }
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            Aptabase.shared.trackEvent("screen_view", with: ["name": "vacuo"])
            // Rebuild the SpriteKit scene on every appearance: the same `@State` instance occasionally
            // comes back paused after a navigation pop, leaving the SpriteView gray until the user taps.
            let fresh = FriendsScene(size: UIScreen.main.bounds.size, connections: Set(), sceneType: .search)
            fresh.scaleMode = .aspectFill
            fresh.backgroundColor = .clear
            fresh.onFriendTapped = { connection in
                viewModel.focusedConnection = connection
            }
            voidScene = fresh
            viewModel.allConnections = allConnections
            voidScene.updateConnections(receivedConnections: Set(viewModel.vacuumConnections))
            voidScene.updateNodeVisuals()
        }
        .onChange(of: allConnections) { _, newValue in
            viewModel.allConnections = newValue
            voidScene.updateConnections(receivedConnections: Set(viewModel.vacuumConnections))
            voidScene.updateNodeVisuals()
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            Color.vacuoBackground.ignoresSafeArea()

            Image("vacuo")
                .frame(width: 280, height: 280)
                .padding(.trailing, 80)
                .padding(.bottom, 40)

            SpriteView(scene: voidScene, options: [.allowsTransparency])
                .ignoresSafeArea()
                .id(ObjectIdentifier(voidScene))

            if viewModel.vacuumConnections.isEmpty {
                VStack {
                    Spacer()
                    Text("Você não tem nenhum\namigo no vácuo")
                        .font(.system(size: 24, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .frame(maxWidth: 300)
                        .padding(.bottom, 20)
                }
            }

            #if DEBUG
            VStack {
                Spacer()
                Button("Simular amigo no vácuo (teste)") {
                    modelContext.insert(Connection(friend: User(name: "Amigo Vácuo"), score: 0))
                }
            }
            #endif
        }
    }

    private func rescueOverlay(for connection: Connection) -> some View {
        ConfirmationOverlay(
            imageData: connection.friend?.profilePicture ?? Data(),
            preTitle: "Você deixou \(connection.friend?.name ?? "") no vácuo",
            title: "QUER RESGATAR ESSE CONTATO?",
            description: "Contatos ficam no vácuo por até 30 dias. Depois disso, a conexão é perdida e será preciso recomeçar do zero.",
            confirmIcon: "checkmark",
            confirmButtonColor: .white,
            confirmIconColor: .black,
            onCancel: { viewModel.focusedConnection = nil },
            onConfirm: {
                viewModel.rescueFocusedConnection(modelContext: modelContext)
                voidScene.updateConnections(receivedConnections: Set(viewModel.vacuumConnections))
            }
        )
    }
}

#Preview {
    VacuoView()
        .modelContainer(for: AppSchema.models, inMemory: true)
}
