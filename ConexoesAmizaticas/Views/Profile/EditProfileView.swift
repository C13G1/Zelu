//
//  EditProfileView.swift
//  ConexoesAmizaticas
//
//  Created by Dayô Araújo on 27/05/26.
//

import SwiftUI
import PhotosUI
import SwiftData

/// An interface for modifying the current user's core identity data.
///
/// `EditProfileView` is the presentational shell on top of `EditProfileViewModel`. It surfaces the user's
/// avatar and name field; the view model owns the form state and writes changes back to SwiftData on every edit.
struct EditProfileView: View {
    @AppStorage("isNotificationAllowed") var isNotificationAllowed: Bool = false
    @Environment(\.modelContext) private var modelContext
    @Binding var vm: InitialViewModel

    @State private var viewModel: EditProfileViewModel?
    @FocusState private var isNameFocused: Bool

    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height

    var body: some View {
        Group {
            if let viewModel {
                @Bindable var bindable = viewModel

                VStack(spacing: 40) {
                    EditableAvatar(imageData: viewModel.profileImageData,
                                   selection: $bindable.selectedPhoto) {
                        await viewModel.commitSelectedPhoto()
                    }

                    VStack(spacing: 2) {
                        TextField("Seu nome", text: $bindable.editableName)
                            .font(.custom("Bolota", size: 48))
                            .multilineTextAlignment(.center)
                            .focused($isNameFocused)
                            .onChange(of: viewModel.editableName) { _, _ in
                                viewModel.commitName()
                            }
                            .onSubmit { isNameFocused = false }

                        Capsule()
                            .frame(width: width * 0.75, height: 5)
                    }
                    
                    HStack {
                        Toggle("Ativar Notificações", isOn: $isNotificationAllowed)
                            .padding()
                            .font(.custom("Bolota", size: 20))
                    }

                    Spacer()
                }
                .foregroundStyle(.black)
                .onTapGesture { isNameFocused = false }
            } else {
                Color.clear
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = EditProfileViewModel(profile: vm.profile, modelContext: modelContext)
            }
        }
        .onChange(of: isNotificationAllowed) { oldValue, newValue in
            if isNotificationAllowed{
                NotificationManager.requestPermission()
                ProximityNotifier.shared.start()
            }
            else {
                NotificationManager.cancelAllNotifications()
                ProximityNotifier.shared.cancel() 
            }
        }
    }
}

#Preview {
    @Previewable @State var viewModel = InitialViewModel()
    EditProfileView(vm: $viewModel)
}
