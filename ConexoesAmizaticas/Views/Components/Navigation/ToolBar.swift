//
//  ToolBar.swift
//  ConexoesAmizaticas
//
//  Created by Dayô Araújo on 26/05/26.
//

import SwiftUI

/// The custom top navigation header for the main interface.
///
/// By employing an inverted `SemiCircle`, `ToolBar` mirrors the design language of the bottom `TabBar`.
/// It encapsulates the `ProfileCircleAndName` component, anchoring the user's identity to the top of the screen.
struct ToolBar: View {
    @Binding var vm: InitialViewModel
    
    var body: some View {
        ZStack {
            // An inverted semi-circle hanging from the top edge
            SemiCircle()
                .fill(Color.themeBackground)
                .frame(width: UIScreen.main.bounds.width, height: 100)
                .rotationEffect(.degrees(180))
            
            ProfileCircleAndName(vm: $vm)
                .padding(.top, UIScreen.main.bounds.height * 0.32)
        }
    }
}

#Preview {
    @Previewable @State var viewModel = InitialViewModel()
    ToolBar(vm: $viewModel)
}

