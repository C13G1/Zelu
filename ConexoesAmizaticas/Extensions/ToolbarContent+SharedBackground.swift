//
//  ToolbarContent+SharedBackground.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 18/06/26.
//

import SwiftUI

extension ToolbarContent {
    /// Hides the shared (Liquid Glass) toolbar background on iOS 26+, and is a no-op on earlier versions.
    @ToolbarContentBuilder
    func hiddenSharedBackgroundIfAvailable() -> some ToolbarContent {
        if #available(iOS 26.0, *) {
            sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}
