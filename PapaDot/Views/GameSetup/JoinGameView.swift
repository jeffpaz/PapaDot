//
//  JoinGameView.swift
//  PapaDot
//
//  Created by Jeff Pazahanick on 12/1/25.
//


import SwiftUI

struct JoinGameView: View {
    @Environment(GameManager.self) var manager
    @Environment(\.dismiss) var dismiss
    @State private var code = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 50) {
                Text("Enter 6-letter code")
                    .font(.title2)
                    .foregroundColor(.gray)
                
                TextField("ABC123", text: $code)
                    .textInputAutocapitalization(.characters)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .frame(height: 80)
                    .background(.white.opacity(0.1))
                    .cornerRadius(16)
                    .multilineTextAlignment(.center)
                    .onChange(of: code) { _, new in code = String(new.prefix(6)).uppercased() }
                
                Button("Join Game") {
                    Task { await manager.joinGame(with: code) }
                    dismiss()
                }
                .font(.title2.bold())
                .frame(height: 66)
                .frame(maxWidth: .infinity)
                .background(code.count == 6 ? .green : .gray)
                .foregroundColor(.black)
                .cornerRadius(16)
                .disabled(code.count != 6)
            }
            .padding(.horizontal, 50)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .navigationTitle("Join Game")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { dismiss() }
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

#Preview {
    JoinGameView()
        .environment(GameManager())
}