//
//  ViewCarrouselPicture.swift
//  ConexoesAmizaticas
//
//  Created by Dayô Araújo on 02/06/26.
//

import SwiftUI

/// A reusable destructive-confirmation overlay used to gate dangerous user actions.
///
/// `ConfirmationOverlay` reproduces the visual language shared by the delete-post, delete-contact and
/// rescue-from-vacuum prompts: a dim backdrop, a red circle with the relevant avatar, a title with optional
/// preface, a long description and two circular buttons. Callers supply the copy, the icons and the closures
/// to react to cancellation and confirmation.
struct ViewCarrouselPicture: View {
    let imageData: Data?
    var cancelIcon: String = "xmark"
    var confirmIcon: String = "trash"
    var confirmButtonColor: Color = .white
    var confirmIconColor: Color = .red
    let onCancel: () -> Void
    let onConfirm: () -> Void
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    @State private var showDeleteAlert = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)
            
            VStack {
                ZStack {
                    Circle()
                        .foregroundStyle(.red)
                        .frame(width: 140, height: 140)
                    if let data = imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: width * 0.85,
                                   height: height * 0.5)
                            .clipShape(RoundedRectangle(cornerRadius: 33))
                            .overlay(
                                RoundedRectangle(cornerRadius: 33)
                                    .strokeBorder(Color.white, lineWidth: 7)
                            )
                    }
                }
                HStack(spacing: 50) {
                    Button(action: onCancel) {
                        ZStack {
                            Circle().foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
                            Image(systemName: cancelIcon)
                                .resizable().frame(width: 22, height: 22)
                                .foregroundStyle(.white).bold()
                        }
                    }
                    .frame(width: 72, height: 72)
                    .glassEffectCompat()
                    
                    Button(action: { showDeleteAlert = true }) {
                        ZStack {
                            Circle().foregroundStyle(confirmButtonColor)
                            Image(systemName: confirmIcon)
                                .resizable().frame(width: 22, height: 26)
                                .foregroundStyle(confirmIconColor).bold()
                        }
                    }
                    .frame(width: 72, height: 72)
                    .glassEffectCompat()
                }
                .padding(.top, 40)
            }
        }
        .alert("Apagar memória?", isPresented: $showDeleteAlert) {
            Button("Apagar", role: .destructive, action: onConfirm)
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Essa foto será removida permanentemente.")
        }
    }
}

private extension View {
    /// Applies the iOS 26 Liquid Glass effect when available; a no-op on earlier versions.
    @ViewBuilder
    func glassEffectCompat() -> some View {
        if #available(iOS 26.0, *) {
            glassEffect()
        } else {
            self
        }
    }
}
