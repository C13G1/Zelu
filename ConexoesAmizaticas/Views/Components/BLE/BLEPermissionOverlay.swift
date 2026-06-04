//
//  BLEPermissionOverlay.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 04/06/26.
//

import SwiftUI

/// The first-time onboarding overlay that explains *why* the app needs Bluetooth before the native
/// permission prompt is triggered.
///
/// `BLEPermissionOverlay` mirrors the explanatory style of `VacuoTutorialOverlay`: it dims the
/// screen, walks the user through the two reasons Bluetooth is used (each as an SF Symbol + text row)
/// and exposes an authorize handler that fires the system permission request. Dismissal is handled by
/// the surrounding `NavigationStack`, and the bottom profile avatar belongs to the `BLEView` behind it.
struct BLEPermissionOverlay: View {
    let onAuthorize: () -> Void

    /// Gap (pt) between the authorize button's bottom edge and the top of the background avatar.
    private let avatarGap: CGFloat = 75

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.85).ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 30) {
                        Text("Para encontrar um contato é preciso habilitar o uso do Bluetooth no Zelu")
                            .font(Font.custom("Sora", size: 24).weight(.semibold))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.bleOverlayText)
                            .frame(maxWidth: .infinity, alignment: .topLeading)

                        reasonRow(
                            symbol: "network",
                            heading: "Como você vai usar isso",
                            body: "Para encontrar novos contatos, adiciona-los no app e registrar encontros com seus amigos."
                        )

                        reasonRow(
                            symbol: "antenna.radiowaves.left.and.right",
                            heading: "Como nós vamos usar isso",
                            body: "Para permitir a visualização do seu contato no app do seu amigo, e vice e versa."
                        )

                        authorizeButton
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal, 32)
                }
                .padding(.bottom, bottomInset(for: geo.size.height))
            }
        }
    }

    /// Anchors the content above the background avatar rendered by `BLEView`, reproducing its avatar
    /// layout math so the button keeps a fixed `avatarGap` to the avatar's top edge on any screen.
    private func bottomInset(for height: CGFloat) -> CGFloat {
        let avatarRadius: CGFloat = 66
        let bottomY = height - 39 - avatarRadius
        let avatarTopEdge = bottomY - avatarRadius
        return height - avatarTopEdge + avatarGap
    }

    private func reasonRow(symbol: String, heading: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 26))
                .foregroundColor(.bleOverlayText)
                .frame(width: 36, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(heading)
                    .font(Font.custom("Sora", size: 16).weight(.semibold))
                    .foregroundColor(.bleOverlayText)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                Text(body)
                    .font(Font.custom("Sora", size: 16).weight(.light))
                    .foregroundColor(.bleOverlayText)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var authorizeButton: some View {
        Button(action: onAuthorize) {
            Text("Autorizar o Bluetooth")
                .font(Font.custom("Sora", size: 14).weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundColor(.bleOverlayText)
                .padding(.horizontal, 24)
                .frame(height: 32)
                .background(Color.bleActionBlue)
                .cornerRadius(30)
        }
    }
}

#Preview {
    BLEPermissionOverlay(onAuthorize: {})
}
