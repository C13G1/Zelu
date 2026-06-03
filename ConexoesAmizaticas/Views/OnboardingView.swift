//
//  OnboardingView.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 20/05/26.
//

import SwiftUI
import PhotosUI
import SwiftData


struct OnboardingView: View {
    @State private var currentPage = 0
    
    var body: some View {
        TabView(selection: $currentPage) {
            Text("bem-vindo ao Zelu, seu mais\nnovo ambiente cultivador\nde relacionamentos")
                .multilineTextAlignment(.center)
                .font(.system(size: 24))
                .fontWeight(.light)
                .foregroundStyle(.white)
                .tag(0)
            
            Text("para iniciar, vamos criar\nseu perfil")
                .multilineTextAlignment(.center)
                .font(.system(size: 24))
                .fontWeight(.light)
                .foregroundStyle(.white)

                .tag(1)
            
            CreatProfileView()
                .tag(2)
        }
        .background(Color(.clear))
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .never))
        .animation(.easeInOut, value: currentPage)
    }
}

#Preview {
    OnboardingView()
        .modelContainer(for: AppSchema.models, inMemory: true)
}
