//  PapaDotWidget/PapaDotWidget.swift
import WidgetKit
import SwiftUI

// MARK: - Timeline Entry
struct LeaderboardEntry: TimelineEntry {
    let date: Date
    let players: [PlayerStanding]
    let courseName: String
    let currentHole: Int
    let isActive: Bool
}

struct PlayerStanding: Identifiable {
    let id: String
    let initials: String
    let name: String
    let dots: Int
    let isLeader: Bool
}

// MARK: - Timeline Provider
struct LeaderboardProvider: TimelineProvider {
    func placeholder(in context: Context) -> LeaderboardEntry {
        LeaderboardEntry(
            date: Date(),
            players: [
                PlayerStanding(id: "1", initials: "JP", name: "Jeff", dots: 14, isLeader: true),
                PlayerStanding(id: "2", initials: "SA", name: "Scott", dots: 12, isLeader: false),
                PlayerStanding(id: "3", initials: "YA", name: "Yelena", dots: 11, isLeader: false),
                PlayerStanding(id: "4", initials: "JA", name: "Jim", dots: 10, isLeader: false)
            ],
            courseName: "Pebble Beach",
            currentHole: 7,
            isActive: true
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (LeaderboardEntry) -> Void) {
        let entry = placeholder(in: context)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<LeaderboardEntry>) -> Void) {
        // Fetch current game from shared UserDefaults
        let entry = fetchCurrentGame()
        
        // Update every 30 seconds during active games
        let updateInterval = entry.isActive ? 30.0 : 3600.0
        let nextUpdate = Date().addingTimeInterval(updateInterval)
        
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func fetchCurrentGame() -> LeaderboardEntry {
        // Try to get current game from App Group shared container
        let sharedDefaults = UserDefaults(suiteName: "group.com.jeffpaz.PapaDot")
        
        guard let gameData = sharedDefaults?.data(forKey: "currentGame"),
              let game = try? JSONDecoder().decode(GameState.self, from: gameData) else {
            // Return placeholder data if no game
            return LeaderboardEntry(
                date: Date(),
                players: [
                    PlayerStanding(id: "1", initials: "JP", name: "Jeff", dots: 14, isLeader: true),
                    PlayerStanding(id: "2", initials: "SA", name: "Scott", dots: 12, isLeader: false),
                    PlayerStanding(id: "3", initials: "YA", name: "Yelena", dots: 11, isLeader: false),
                    PlayerStanding(id: "4", initials: "JA", name: "Jim", dots: 10, isLeader: false)
                ],
                courseName: "No Active Game",
                currentHole: 1,
                isActive: false
            )
        }
        
        // Calculate standings
        let totalDots = calculateTotalDots(game: game)
        let maxDots = totalDots.values.max() ?? 0
        
        let standings = game.players.map { player in
            let dots = totalDots[player] ?? 0
            return PlayerStanding(
                id: player.id,
                initials: getInitials(for: player.name),
                name: getFirstName(for: player.name),
                dots: dots,
                isLeader: dots == maxDots && dots > 0
            )
        }.sorted { $0.dots > $1.dots }
        
        return LeaderboardEntry(
            date: Date(),
            players: standings,
            courseName: game.golfCourse?.name ?? "Golf",
            currentHole: game.currentHole,
            isActive: game.isActive
        )
    }
    
    private func getInitials(for name: String) -> String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            let first = String(components[0].prefix(1))
            let last = String(components[components.count - 1].prefix(1))
            return "\(first)\(last)"
        }
        return String(name.prefix(1))
    }
    
    private func getFirstName(for name: String) -> String {
        String(name.split(separator: " ").first ?? name.prefix(10))
    }
}

// MARK: - Widget Views
struct LeaderboardWidgetView: View {
    let entry: LeaderboardEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            MediumWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget (2x2)
struct SmallWidgetView: View {
    let entry: LeaderboardEntry
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.2, blue: 0.1),
                    Color(red: 0.02, green: 0.15, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            VStack(spacing: 8) {
                // Header
                HStack {
                    Image(systemName: "flag.fill")
                        .foregroundStyle(.green)
                    Text("Hole \(entry.currentHole)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
                
                // Leader only
                if let leader = entry.players.first {
                    VStack(spacing: 4) {
                        Text(leader.initials)
                            .font(.title.bold())
                            .foregroundStyle(.yellow)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color.yellow.opacity(0.2)))
                        
                        Text(leader.name)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                        
                        Text(leader.dots >= 0 ? "+\(leader.dots)" : "\(leader.dots)")
                            .font(.title2.bold())
                            .foregroundStyle(.yellow)
                            .monospacedDigit()
                        
                        Image(systemName: "crown.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Medium Widget (4x2)
struct MediumWidgetView: View {
    let entry: LeaderboardEntry
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.2, blue: 0.1),
                    Color(red: 0.02, green: 0.15, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            VStack(spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.courseName)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                        Text("Hole \(entry.currentHole) of 18")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "flag.fill")
                        .foregroundStyle(.green)
                }
                
                // Top 4 players
                HStack(spacing: 4) {
                    ForEach(entry.players.prefix(4)) { player in
                        VStack(spacing: 4) {
                            Text(player.initials)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(player.isLeader ? .yellow : .white)
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle()
                                        .fill(player.isLeader ? Color.yellow.opacity(0.2) : Color.white.opacity(0.15))
                                )
                            
                            Text(player.name)
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.8))
                                .lineLimit(1)
                            
                            Text(player.dots >= 0 ? "+\(player.dots)" : "\(player.dots)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(player.isLeader ? .yellow : .white)
                                .monospacedDigit()
                            
                            if player.isLeader {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.yellow)
                            } else {
                                Spacer()
                                    .frame(height: 8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Large Widget (4x4)
struct LargeWidgetView: View {
    let entry: LeaderboardEntry
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.2, blue: 0.1),
                    Color(red: 0.02, green: 0.15, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            VStack(spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.courseName)
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                        Text("Hole \(entry.currentHole) of 18")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "flag.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
                
                // All players with full standings
                VStack(spacing: 8) {
                    ForEach(Array(entry.players.enumerated()), id: \.element.id) { index, player in
                        HStack(spacing: 12) {
                            // Rank
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(width: 20)
                            
                            // Player initials
                            Text(player.initials)
                                .font(.caption.bold())
                                .foregroundStyle(player.isLeader ? .yellow : .white)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(player.isLeader ? Color.yellow.opacity(0.2) : Color.white.opacity(0.15))
                                )
                            
                            // Player name
                            Text(player.name)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                            
                            Spacer()
                            
                            // Dots
                            Text(player.dots >= 0 ? "+\(player.dots)" : "\(player.dots)")
                                .font(.headline.bold())
                                .foregroundStyle(player.isLeader ? .yellow : .white)
                                .monospacedDigit()
                            
                            // Leader crown
                            if player.isLeader {
                                Image(systemName: "crown.fill")
                                    .font(.caption)
                                    .foregroundStyle(.yellow)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            player.isLeader ?
                            LinearGradient(
                                colors: [Color.yellow.opacity(0.2), Color.orange.opacity(0.2)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ) :
                            LinearGradient(
                                colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(10)
                    }
                }
                
                Spacer()
                
                // Tap to open prompt
                Text("Tap to open scorecard")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding()
        }
    }
}

// MARK: - Widget Configuration
@main
struct PapaDotWidget: Widget {
    let kind: String = "PapaDotWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LeaderboardProvider()) { entry in
            LeaderboardWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Live Leaderboard")
        .description("See current standings and scores during your round")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Previews
#Preview(as: .systemSmall) {
    PapaDotWidget()
} timeline: {
    LeaderboardEntry(
        date: Date(),
        players: [
            PlayerStanding(id: "1", initials: "JP", name: "Jeff", dots: 14, isLeader: true),
            PlayerStanding(id: "2", initials: "SA", name: "Scott", dots: 12, isLeader: false)
        ],
        courseName: "Pebble Beach",
        currentHole: 7,
        isActive: true
    )
}

#Preview(as: .systemMedium) {
    PapaDotWidget()
} timeline: {
    LeaderboardEntry(
        date: Date(),
        players: [
            PlayerStanding(id: "1", initials: "JP", name: "Jeff", dots: 14, isLeader: true),
            PlayerStanding(id: "2", initials: "SA", name: "Scott", dots: 12, isLeader: false),
            PlayerStanding(id: "3", initials: "YA", name: "Yelena", dots: 11, isLeader: false),
            PlayerStanding(id: "4", initials: "JA", name: "Jim", dots: 10, isLeader: false)
        ],
        courseName: "Pebble Beach",
        currentHole: 7,
        isActive: true
    )
}
