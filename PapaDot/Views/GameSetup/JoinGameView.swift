//  Views/JoinGameView.swift
import SwiftUI

struct JoinGameView: View {
    @Environment(GameManager.self) var manager
    @Environment(\.dismiss) var dismiss
    @State private var code = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.4, blue: 0.2),
                        Color(red: 0.05, green: 0.25, blue: 0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // Icon
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.3), Color.yellow.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .overlay {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.white)
                        }
                    
                    // Title
                    VStack(spacing: 8) {
                        Text("Join a Game")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Text("Enter the 7-character code")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    // Code Input Card
                    VStack(spacing: 24) {
                        TextField("", text: $code)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.primary)
                            .padding(.vertical, 20)
                            .background(Color.white)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(code.count == 7 ? Color.green : Color.clear, lineWidth: 3)
                            )
                            .onChange(of: code) { _, new in
                                code = String(new.prefix(7)).uppercased()
                            }
                        
                        // Character indicators
                        HStack(spacing: 12) {
                            ForEach(0..<7) { index in
                                Circle()
                                    .fill(index < code.count ? Color.green : Color.white.opacity(0.3))
                                    .frame(width: 12, height: 12)
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    // Join Button
                    Button {
                        Task {
                            print("🟢 Join button tapped with code: \(code)")
                            await manager.joinGame(with: code)
                            print("🟢 Join complete - showWaitingRoom should be true")
                            // Small delay to let state propagate
                            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("Join Game")
                                .font(.headline.bold())
                        }
                        .foregroundStyle(code.count == 7 ? .white : .white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            code.count == 7 ?
                            LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .leading, endPoint: .trailing) :
                            LinearGradient(colors: [.white.opacity(0.2), .white.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(16)
                    }
                    .disabled(code.count != 7)
                    .padding(.horizontal, 40)
                    
                    Spacer()
                    Spacer()
                }
            }
            .navigationTitle("Join Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    JoinGameView()
        .environment(GameManager())
}
