//
//  ReactionPickerView.swift
//  PapaDot
//
//  Created by Jeff Pazahanick on 4/23/26.
//


// Views/ReactionView.swift
import SwiftUI

// MARK: - Reaction Picker Sheet

struct ReactionPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(GameManager.self) var manager

    let fromPlayer: String
    let toPlayer: String
    let hole: Int
    let taskName: String

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.35, blue: 0.2), Color(red: 0.05, green: 0.2, blue: 0.1)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Context
                    VStack(spacing: 6) {
                        Text("React to \(toPlayer)'s \(taskName)")
                            .font(.headline).foregroundStyle(.white)
                        Text("Hole \(hole)")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.top, 20)

                    // Emoji grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 20) {
                        ForEach(Reaction.availableEmojis, id: \.self) { emoji in
                            Button {
                                send(emoji: emoji)
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 48))
                                    .frame(width: 72, height: 72)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.white)
                }
            }
        }
    }

    private func send(emoji: String) {
        let reaction = Reaction(
            fromPlayer: fromPlayer,
            toPlayer: toPlayer,
            emoji: emoji,
            hole: hole,
            taskName: taskName
        )
        manager.addReaction(reaction)
        dismiss()
    }
}

// MARK: - Incoming Reaction Overlay

struct ReactionOverlayView: View {
    let reaction: Reaction

    @State private var scale = 0.3
    @State private var opacity = 0.0
    @State private var yOffset = 0.0

    var body: some View {
        VStack(spacing: 8) {
            Text(reaction.emoji)
                .font(.system(size: 72))

            VStack(spacing: 4) {
                Text("\(reaction.fromPlayer) → \(reaction.toPlayer)")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                Text(reaction.taskName)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.6))
            .cornerRadius(14)
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .offset(y: yOffset)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1.0; opacity = 1.0
            }
            // Auto-dismiss after 3 seconds
            withAnimation(.easeInOut(duration: 0.4).delay(2.6)) {
                opacity = 0; yOffset = -20
            }
        }
    }
}

// MARK: - Reaction Feed (shown in stats/leaderboard tab)

struct ReactionFeedView: View {
    let reactions: [Reaction]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame.fill").foregroundStyle(.orange)
                Text("Trash Talk").font(.headline.bold()).foregroundStyle(.white)
            }

            if reactions.isEmpty {
                Text("No reactions yet — be the first to talk trash 🗑️")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.vertical, 8)
            } else {
                ForEach(reactions.reversed()) { reaction in
                    HStack(spacing: 10) {
                        Text(reaction.emoji).font(.title2)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(reaction.fromPlayer)
                                    .font(.subheadline.bold()).foregroundStyle(.white)
                                Text("reacted to")
                                    .font(.caption).foregroundStyle(.white.opacity(0.5))
                                Text(reaction.toPlayer)
                                    .font(.subheadline.bold()).foregroundStyle(.green)
                            }
                            Text("\(reaction.taskName) • Hole \(reaction.hole)")
                                .font(.caption2).foregroundStyle(.white.opacity(0.4))
                        }

                        Spacer()

                        Text(reaction.timestamp, style: .time)
                            .font(.caption2).foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(10)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
    }
}
