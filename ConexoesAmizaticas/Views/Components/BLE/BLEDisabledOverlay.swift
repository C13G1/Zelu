//
//  BLEDisabledOverlay.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 04/06/26.
//

import SwiftUI

/// The overlay shown when Bluetooth permission was denied/restricted or Bluetooth is powered off.
///
/// `BLEDisabledOverlay` cannot re-trigger the native prompt (the system only asks once), so it dims
/// the screen and directs the user to the Settings app via `onOpenSettings`. Dismissal is handled by
/// the surrounding `NavigationStack`, and the bottom profile avatar belongs to the `BLEView` behind it.
struct BLEDisabledOverlay: View {
    let onOpenSettings: () -> Void

    /// Gap (pt) between the settings button's bottom edge and the top of the background avatar.
    private let avatarGap: CGFloat = 75

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.85).ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    VStack(alignment: .center, spacing: 24) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 107, height: 94)
                            .foregroundColor(.bleOverlayText)
                            .opacity(0.24)

                        Text("Essa funcionalidade precisa de acesso ao Bluetooth")
                            .font(Font.custom("Sora", size: 24).weight(.semibold))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.bleOverlayText)
                            .frame(width: 249, alignment: .top)

                        Text("Abrir Ajustes >  Privacidade & Segurança e permitir acesso ao Bluetooth")
                            .font(Font.custom("Sora", size: 16).weight(.light))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.bleOverlayText)
                            .frame(maxWidth: .infinity, alignment: .top)

                        settingsButton
                    }
                    .frame(width: 265, alignment: .top)
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

    private var settingsButton: some View {
        Button(action: onOpenSettings) {
            Text("Abrir ajustes")
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
    BLEDisabledOverlay(onOpenSettings: {})
}
