// Views/ScorecardView.swift
import SwiftUI

struct ScorecardView: View {
    let historicalGame: GameState
    var isHistoryView: Bool = false

    @Environment(GameManager.self) var manager

    // Live view always reads from manager.game so edits appear instantly.
    private var game: GameState {
        isHistoryView ? historicalGame : (manager.game ?? historicalGame)
    }

    init(game: GameState, isHistoryView: Bool = false) {
        self.historicalGame = game
        self.isHistoryView = isHistoryView
    }

    @State private var editingPlayerName: String?
    @State private var editingHole: Int?
    @State private var editingStrokes: Int = 4

    private let rowH: CGFloat = 34
    private let holeW: CGFloat = 36
    private let sumW: CGFloat  = 44
    private let leftW: CGFloat = 82

    // MARK: - Data helpers

    private func par(_ hole: Int) -> Int {
        game.courseData?.holes?.first { $0.number == hole }?.par
            ?? (game.rules.par3Holes.contains(hole) ? 3 : 4)
    }

    private func holeHcp(_ hole: Int) -> Int? {
        game.courseData?.holes?.first { $0.number == hole }?.handicap
    }

    private var showHdcp: Bool { (1...18).contains { holeHcp($0) != nil } }

    private func gross(_ player: Player, _ hole: Int) -> Int? {
        game.strokeScores[hole]?[player.name]
    }

    private func netScore(_ player: Player, _ hole: Int) -> Int {
        let g = gross(player, hole) ?? par(hole)
        guard game.rules.useHandicap, player.handicap > 0,
              let info = game.courseData?.holes?.first(where: { $0.number == hole }),
              let hcp = info.handicap else { return g }
        var recv = player.handicap / 18 + (hcp <= player.handicap % 18 ? 1 : 0)
        if info.par == 3 { recv = player.handicap >= 20 ? min(recv, 1) : 0 }
        return max(1, g - recv)
    }

    // Returns explicit stroke score, or par for played holes with no explicit entry.
    private func displayGross(_ player: Player, _ hole: Int) -> Int? {
        if let g = gross(player, hole) { return g }
        let played = isHistoryView || hole < game.currentHole
        return played ? par(hole) : nil
    }

    private func grossSum(_ player: Player, _ holes: [Int]) -> Int? {
        let s = holes.compactMap { displayGross(player, $0) }
        return s.isEmpty ? nil : s.reduce(0, +)
    }

    private func netTotal(_ player: Player) -> Int? {
        let played = (1...18).filter { displayGross(player, $0) != nil }
        guard !played.isEmpty else { return nil }
        return played.reduce(0) { $0 + netScore(player, $1) }
    }

    private func plusMinus(_ player: Player) -> Int? {
        guard let n = netTotal(player) else { return nil }
        let played = (1...18).filter { displayGross(player, $0) != nil }
        return n - played.reduce(0) { $0 + par($1) }
    }

    private var parFront: Int { (1...9).reduce(0)  { $0 + par($1) } }
    private var parBack:  Int { (10...18).reduce(0) { $0 + par($1) } }
    private var parTotal: Int { game.courseData?.totalPar ?? parFront + parBack }

    private var rowCount: Int { 2 + (showHdcp ? 1 : 0) + game.players.count }
    private var gridHeight: CGFloat { rowH * CGFloat(rowCount) }

    private func teamColor(_ p: Player) -> Color {
        guard game.rules.isTeamMode else { return .white }
        switch game.teamForPlayer(p) {
        case "A": return .cyan
        case "B": return .orange
        default:  return .white
        }
    }

    private func stripeBg(_ p: Player) -> Color {
        let i = game.players.firstIndex(where: { $0.id == p.id }) ?? 0
        return i % 2 == 0 ? Color.white.opacity(0.035) : Color.clear
    }

    private func firstName(_ name: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    private var editTitle: String {
        guard let name = editingPlayerName, let hole = editingHole else { return "Edit Score" }
        return "\(name) — Hole \(hole)"
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.17, blue: 0.08).ignoresSafeArea()
            VStack(spacing: 0) {
                titleBar
                scorecardGrid
            }
        }
        .sheet(isPresented: .init(
            get: { editingPlayerName != nil },
            set: { if !$0 { editingPlayerName = nil; editingHole = nil } }
        )) {
            editSheet
        }
    }

    // MARK: - Title bar

    private var titleBar: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(game.golfCourse?.name ?? "Scorecard")
                    .font(.subheadline.bold()).foregroundStyle(.white)
                if let cd = game.courseData {
                    Text("Par \(cd.totalPar)")
                        .font(.caption2).foregroundStyle(.white.opacity(0.5))
                }
            }
            Spacer()
            if !isHistoryView {
                HStack(spacing: 4) {
                    Image(systemName: "flag.fill").font(.caption2).foregroundStyle(.yellow)
                    Text("Hole \(game.currentHole)")
                        .font(.caption.bold()).foregroundStyle(.yellow)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Capsule().fill(Color.yellow.opacity(0.12)))

                Text("Tap cell to edit")
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.28))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color.black.opacity(0.35))
    }

    // MARK: - Grid

    private var scorecardGrid: some View {
        ZStack(alignment: .topLeading) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    Color.clear.frame(width: leftW, height: gridHeight)
                    rightColumns
                }
            }
            leftColumn
        }
        .frame(height: gridHeight)
    }

    // MARK: - Left fixed column

    private var leftColumn: some View {
        VStack(spacing: 0) {
            leftCell("", fg: .white.opacity(0.5), bg: .black.opacity(0.4))
            leftCell("PAR",  fg: .white.opacity(0.45), bg: .black.opacity(0.22))
            if showHdcp {
                leftCell("HDCP", fg: .white.opacity(0.35), bg: .black.opacity(0.15))
            }
            ForEach(game.players) { p in
                HStack(spacing: 5) {
                    if game.rules.isTeamMode {
                        Circle().fill(teamColor(p).opacity(0.55)).frame(width: 5, height: 5)
                    }
                    Text(firstName(p.name))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(teamColor(p))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.leading, 8)
                .frame(width: leftW, height: rowH, alignment: .leading)
                .background(stripeBg(p))
            }
        }
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color.white.opacity(0.2)).frame(width: 1)
        }
        .frame(width: leftW)
    }

    private func leftCell(_ text: String, fg: Color, bg: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(fg)
            .padding(.leading, 8)
            .frame(width: leftW, height: rowH, alignment: .leading)
            .background(bg)
    }

    // MARK: - Right scrollable area

    private var rightColumns: some View {
        HStack(spacing: 0) {
            ForEach(1...18, id: \.self) { h in holeColumn(h) }

            Rectangle().fill(Color.white.opacity(0.22)).frame(width: 2)

            sumCol("OUT", parFront, game.players.map { grossSum($0, Array(1...9)) })
            sumCol("IN",  parBack,  game.players.map { grossSum($0, Array(10...18)) })
            sumCol("TOT", parTotal, game.players.map { grossSum($0, Array(1...18)) })
            sumCol("NET", nil,      game.players.map { netTotal($0) })
            pmCol
            dotsCol
        }
    }

    // MARK: - Hole column

    private func holeColumn(_ h: Int) -> some View {
        let cur = !isHistoryView && h == game.currentHole
        return VStack(spacing: 0) {
            Text("\(h)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(cur ? .yellow : .white.opacity(0.6))
                .frame(width: holeW, height: rowH)
                .background(cur ? Color.yellow.opacity(0.18) : Color.black.opacity(h % 2 == 0 ? 0.32 : 0.26))

            Text("\(par(h))")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: holeW, height: rowH)
                .background(cur ? Color.yellow.opacity(0.07) : Color.black.opacity(0.12))

            if showHdcp {
                Text(holeHcp(h).map { "\($0)" } ?? "—")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(width: holeW, height: rowH)
                    .background(cur ? Color.yellow.opacity(0.04) : Color.clear)
            }

            ForEach(game.players) { p in scoreCell(p, h, cur) }
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(cur ? Color.yellow.opacity(0.3) : Color.white.opacity(0.07))
                .frame(width: 1)
        }
    }

    // MARK: - Score cell

    private func scoreCell(_ p: Player, _ h: Int, _ cur: Bool) -> some View {
        let g = gross(p, h)
        let holePar = par(h)
        let editable = !isHistoryView && h <= game.currentHole

        return Button {
            guard editable else { return }
            editingPlayerName = p.name
            editingHole = h
            editingStrokes = g ?? holePar
        } label: {
            ZStack {
                if let score = g {
                    scoreMarking(score, holePar)
                    Text("\(score)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(score - holePar < 0 ? Color.black : .white)
                } else {
                    let played = isHistoryView || h < game.currentHole
                    Text(played ? "\(holePar)" : "")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.28))
                }
            }
            .frame(width: holeW, height: rowH)
            .background(cur ? Color.yellow.opacity(0.05) : stripeBg(p))
        }
        .buttonStyle(.plain)
        .disabled(!editable)
    }

    @ViewBuilder
    private func scoreMarking(_ score: Int, _ holePar: Int) -> some View {
        let d = score - holePar
        if d <= -2 {
            // Eagle or better: double gold circle
            ZStack {
                Circle().fill(Color(red: 1, green: 0.82, blue: 0).opacity(0.9)).padding(3)
                Circle().stroke(Color(red: 1, green: 0.82, blue: 0).opacity(0.55), lineWidth: 1).padding(1)
            }
        } else if d == -1 {
            // Birdie: single red circle
            Circle().fill(Color.red.opacity(0.78)).padding(4)
        } else if d == 1 {
            // Bogey: single square border
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
                .padding(4)
        } else if d >= 2 {
            // Double bogey+: double square border
            ZStack {
                RoundedRectangle(cornerRadius: 2).stroke(Color.white.opacity(0.38), lineWidth: 1).padding(2)
                RoundedRectangle(cornerRadius: 2).stroke(Color.white.opacity(0.22), lineWidth: 1).padding(6)
            }
        }
        // Par: no marking (EmptyView implicitly)
    }

    // MARK: - Summary column

    private func sumCol(_ title: String, _ parVal: Int?, _ vals: [Int?]) -> some View {
        VStack(spacing: 0) {
            sumHeader(title)
            Text(parVal.map { "\($0)" } ?? "—")
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
                .frame(width: sumW, height: rowH).background(Color.black.opacity(0.2))
            if showHdcp {
                Text("—").font(.system(size: 11)).foregroundStyle(.white.opacity(0.28))
                    .frame(width: sumW, height: rowH)
            }
            ForEach(Array(game.players.enumerated()), id: \.offset) { i, p in
                let v = i < vals.count ? vals[i] : nil
                Text(v.map { "\($0)" } ?? "—")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                    .frame(width: sumW, height: rowH).background(stripeBg(p))
            }
        }
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1)
        }
    }

    // MARK: - +/- column

    private var pmCol: some View {
        VStack(spacing: 0) {
            sumHeader("+/-")
            Text("E").font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
                .frame(width: sumW, height: rowH).background(Color.black.opacity(0.2))
            if showHdcp {
                Text("—").font(.system(size: 11)).foregroundStyle(.white.opacity(0.28))
                    .frame(width: sumW, height: rowH)
            }
            ForEach(game.players) { p in
                let d = plusMinus(p)
                let label = d.map { $0 == 0 ? "E" : $0 > 0 ? "+\($0)" : "\($0)" } ?? "—"
                let fg: Color = {
                    guard let v = d else { return .white.opacity(0.3) }
                    return v < 0 ? Color(red: 1, green: 0.45, blue: 0.45) : v > 0 ? .white.opacity(0.55) : .white
                }()
                Text(label).font(.system(size: 12, weight: .bold)).foregroundStyle(fg)
                    .frame(width: sumW, height: rowH).background(stripeBg(p))
            }
        }
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1)
        }
    }

    // MARK: - DOTS column

    private var dotsCol: some View {
        let allDots = calculateTotalDots(game: game)
        return VStack(spacing: 0) {
            sumHeader("DOTS", accent: true)
            Text("—").font(.system(size: 11)).foregroundStyle(.white.opacity(0.25))
                .frame(width: sumW, height: rowH).background(Color.black.opacity(0.2))
            if showHdcp {
                Text("—").font(.system(size: 11)).foregroundStyle(.white.opacity(0.25))
                    .frame(width: sumW, height: rowH)
            }
            ForEach(game.players) { p in
                Text("\(allDots[p] ?? 0)")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(.green.opacity(0.9))
                    .frame(width: sumW, height: rowH).background(stripeBg(p))
            }
        }
    }

    private func sumHeader(_ title: String, accent: Bool = false) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(accent ? Color.green.opacity(0.85) : .white.opacity(0.6))
            .frame(width: sumW, height: rowH)
            .background(Color.black.opacity(0.38))
    }

    // MARK: - Edit sheet

    @ViewBuilder
    private var editSheet: some View {
        if let name = editingPlayerName, let hole = editingHole {
            StrokePickerSheet(
                playerName: name,
                hole: hole,
                holePar: par(hole),
                strokes: $editingStrokes
            ) { savedName, savedHole, savedStrokes in
                manager.setStrokeScore(playerName: savedName, hole: savedHole, strokes: savedStrokes)
                editingPlayerName = nil
                editingHole = nil
            } onCancel: {
                editingPlayerName = nil
                editingHole = nil
            }
        }
    }
}

// MARK: - Stroke picker sheet (separate struct avoids Picker generic-inference ambiguity)

private struct StrokePickerSheet: View {
    let playerName: String
    let hole: Int
    let holePar: Int
    @Binding var strokes: Int
    let onSave: (String, Int, Int) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Picker("Strokes", selection: $strokes) {
                ForEach([Int](1...12), id: \.self) { n in
                    Text(strokeLabel(n)).tag(n)
                }
            }
            .pickerStyle(.wheel)
            .navigationTitle("\(playerName) — Hole \(hole)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(playerName, hole, strokes) }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }

    private func strokeLabel(_ n: Int) -> String {
        let d = n - holePar
        switch d {
        case ..<(-1): return "\(n)  (Eagle+)"
        case -1:      return "\(n)  (Birdie)"
        case  0:      return "\(n)  (Par)"
        case  1:      return "\(n)  (Bogey)"
        case  2:      return "\(n)  (Double)"
        default:      return "\(n)  (+\(d))"
        }
    }
}

#Preview {
    ScorecardView(
        game: GameState(gameID: "TEST", players: [
            Player(name: "Alice", phoneNumber: ""),
            Player(name: "Bob", phoneNumber: ""),
        ], rules: GameRules())
    )
    .environment(GameManager())
}
