//
//  ModeSelectionView.swift
//  PapaDot
//
//  Created by Jeff Pazahanick on 12/1/25.
//


import SwiftUI

struct ModeSelectionView: View {
    @Environment(GameManager.self) var manager
    @State private var showCreate = false
    @State private var showJoin = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Image("GolfClubs")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .opacity(0.3)
                Color.black.opacity(0.8).ignoresSafeArea()
                
                VStack(spacing: 70) {
                    Text("Papa Dot")
                        .font(.system(size: 96, weight: .black, design: .rounded))
                        .foregroundStyle(.green)
                    
                    VStack(spacing: 28) {
                        Button("Create Game") { showCreate = true }
                            .font(.title.bold())
                            .frame(maxWidth: .infinity)
                            .padding(32)
                            .background(.green.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(24)
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.green, lineWidth: 4))
                        
                        Button("Join Game") { showJoin = true }
                            .font(.title.bold())
                            .frame(maxWidth: .infinity)
                            .padding(32)
                            .background(.blue.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(24)
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.blue, lineWidth: 4))
                        
                        Button("Game History") { manager.showHistory = true }
                            .font(.title.bold())
                            .frame(maxWidth: .infinity)
                            .padding(32)
                            .background(.purple.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(24)
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.purple, lineWidth: 4))
                    }
                    .padding(.horizontal, 50)
                }
            }
            .sheet(isPresented: $showCreate) { CreateGameView() }
            .sheet(isPresented: $showJoin) { JoinGameView() }
        }
    }
}

#Preview {
    ModeSelectionView()
        .environment(GameManager())
}