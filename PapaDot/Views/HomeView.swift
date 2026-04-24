// Views/HomeView.swift
import SwiftUI
import WeatherKit
import CoreLocation

struct HomeView: View {
    @Environment(GameManager.self) var manager
    @AppStorage("colorScheme") private var colorSchemeRaw = "system"
    @State private var showingCreateGame = false
    @State private var showingJoinGame = false
    @State private var locationManager = LocationManager()
    @State private var weather: CurrentWeather? = nil
    @State private var isLoadingWeather = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.4, blue: 0.2), Color(red: 0.05, green: 0.25, blue: 0.15)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        VStack(spacing: 12) {
                            // Dark mode toggle
                            HStack {
                                Spacer()
                                Button {
                                    switch colorSchemeRaw {
                                    case "light": colorSchemeRaw = "dark"
                                    case "dark": colorSchemeRaw = "system"
                                    default: colorSchemeRaw = "light"
                                    }
                                } label: {
                                    Image(systemName: colorSchemeIcon)
                                        .font(.title3)
                                        .foregroundStyle(.white.opacity(0.7))
                                        .frame(width: 36, height: 36)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(10)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                            Image(systemName: "figure.golf")
                                .font(.system(size: 60, weight: .light))
                                .foregroundStyle(.white)

                            Text("PapaDot")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            Text("Golf Betting Made Simple")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))

                            // Birthday badge
                            HStack(spacing: 6) {
                                Text("🎂")
                                Text("Benoit 50th Birthday Edition")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("🎂")
                            }
                            .foregroundStyle(.yellow)
                            .padding(.horizontal, 16).padding(.vertical, 6)
                            .background(Color.yellow.opacity(0.15))
                            .cornerRadius(20)

                            // Weather strip
                            if let w = weather {
                                weatherStrip(w)
                            } else if isLoadingWeather {
                                HStack(spacing: 6) {
                                    ProgressView().tint(.white).scaleEffect(0.7)
                                    Text("Loading weather…")
                                        .font(.caption).foregroundStyle(.white.opacity(0.5))
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.bottom, 32)

                        // Cards
                        VStack(spacing: 16) {
                            startGameCard()
                            HStack(spacing: 16) {
                                joinGameCard()
                                viewHistoryCard()
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .sheet(isPresented: $showingCreateGame) { CreateGameView() }
            .sheet(isPresented: $showingJoinGame) { JoinGameView() }
            .task { await loadWeather() }
        }
        .preferredColorScheme(preferredScheme)
    }

    // MARK: - Color Scheme

    private var preferredScheme: ColorScheme? {
        switch colorSchemeRaw {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private var colorSchemeIcon: String {
        switch colorSchemeRaw {
        case "light": return "sun.max.fill"
        case "dark": return "moon.fill"
        default: return "circle.lefthalf.filled"
        }
    }

    // MARK: - Weather Strip

    private func weatherStrip(_ w: CurrentWeather) -> some View {
        HStack(spacing: 16) {
            Image(systemName: w.symbolName)
                .font(.title2).foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text(w.condition.description)
                    .font(.caption.bold()).foregroundStyle(.white)
                Text("Feels like \(Int(w.apparentTemperature.converted(to: .fahrenheit).value))°F")
                    .font(.caption2).foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            Text("\(Int(w.temperature.converted(to: .fahrenheit).value))°F")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            VStack(alignment: .trailing, spacing: 2) {
                Label("\(Int(w.wind.speed.converted(to: .milesPerHour).value)) mph", systemImage: "wind")
                    .font(.caption2).foregroundStyle(.white.opacity(0.6))
                Label("\(Int(w.humidity * 100))%", systemImage: "humidity.fill")
                    .font(.caption2).foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color.white.opacity(0.1))
        .cornerRadius(14)
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    // MARK: - Cards

    private func startGameCard() -> some View {
        Button { showingCreateGame = true } label: {
            VStack(spacing: 24) {
                Circle()
                    .fill(LinearGradient(colors: [.green.opacity(0.2), .blue.opacity(0.2)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 100, height: 100)
                    .overlay {
                        Image(systemName: "flag.fill").font(.system(size: 50)).foregroundStyle(.green)
                    }
                    .padding(.top, 20)

                VStack(spacing: 8) {
                    Text("Start New Round")
                        .font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(.primary)
                    Text("Set up players and begin tracking dots")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }

                HStack {
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill").font(.title2).foregroundStyle(.green)
                }
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity).background(.white).cornerRadius(20)
            .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
        }
        .buttonStyle(.plain)
    }

    private func joinGameCard() -> some View {
        Button { showingJoinGame = true } label: {
            VStack(spacing: 16) {
                Circle().fill(Color.orange.opacity(0.1)).frame(width: 60, height: 60)
                    .overlay { Image(systemName: "person.2.fill").font(.title2).foregroundStyle(.orange) }
                VStack(spacing: 4) {
                    Text("Join Game").font(.headline.bold()).foregroundStyle(.primary)
                    Text("Enter code").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary).font(.caption)
            }
            .padding(20).frame(maxWidth: .infinity).background(.white).cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
    }

    private func viewHistoryCard() -> some View {
        Button { manager.showHistory = true } label: {
            VStack(spacing: 16) {
                Circle().fill(Color.blue.opacity(0.1)).frame(width: 60, height: 60)
                    .overlay { Image(systemName: "clock.arrow.circlepath").font(.title2).foregroundStyle(.blue) }
                VStack(spacing: 4) {
                    Text("History").font(.headline.bold()).foregroundStyle(.primary)
                    Text("Past rounds").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary).font(.caption)
            }
            .padding(20).frame(maxWidth: .infinity).background(.white).cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Weather

    private func loadWeather() async {
        guard !isLoadingWeather else { return }
        isLoadingWeather = true
        defer { isLoadingWeather = false }

        if !locationManager.isAuthorized { locationManager.requestLocation() }
        var attempts = 0
        while locationManager.location == nil && attempts < 8 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            attempts += 1
        }
        guard let loc = locationManager.location else { return }

        do {
            let w = try await WeatherService.shared.weather(for: loc)
            await MainActor.run { weather = w.currentWeather }
        } catch {
            print("⚠️ Weather failed: \(error)")
        }
    }
}

#Preview {
    HomeView().environment(GameManager())
}
