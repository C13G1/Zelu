//
//  View+DismissKeyboard.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 17/06/26.
//

import SwiftUI
import UIKit

extension View {
    /// Dismisses the keyboard when the user taps anywhere outside the focused field.
    ///
    /// A full-screen transparent layer sits behind the content and catches taps on the empty areas,
    /// so dismissal works across the whole screen — not just the content's bounding box. The content
    /// stays on top, so buttons and the field itself keep their taps.
    func dismissKeyboardOnTap() -> some View {
        ZStack {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
                    )
                }
            self
        }
    }
}
