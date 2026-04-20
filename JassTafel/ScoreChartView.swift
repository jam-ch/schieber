import SwiftUI
import Charts

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let round: Int
    let team: String
    let score: Int
}

struct ScoreChartView: View {
    let runden: [Runde]
    let teamNames: [String]
    let teamCount: Int
    let targetScore: Int

    private var dataPoints: [ChartDataPoint] {
        let chronological = runden.reversed()
        var cumulative = Array(repeating: 0, count: teamCount)
        var points: [ChartDataPoint] = []

        for i in 0..<teamCount {
            points.append(ChartDataPoint(round: 0, team: teamNames[i], score: 0))
        }

        for (index, runde) in chronological.enumerated() {
            let roundNumber = index + 1
            for i in 0..<teamCount {
                cumulative[i] += runde.total(forTeam: i)
                points.append(ChartDataPoint(round: roundNumber, team: teamNames[i], score: cumulative[i]))
            }
        }
        return points
    }

    private var stats: [TeamStats] {
        (0..<teamCount).map { i in
            let totals = runden.map { $0.total(forTeam: i) }
            let total = totals.reduce(0, +)
            let best = totals.max() ?? 0
            let worst = totals.min() ?? 0
            let avg = runden.isEmpty ? 0 : total / runden.count
            let matchCount = runden.filter { $0.bonus(forTeam: i) > 0 }.count
            let trumpCount = runden.filter { $0.trumpTeamIndex == i }.count
            let trumpWins = runden.filter { r in
                r.trumpTeamIndex == i && r.total(forTeam: i) == (0..<teamCount).map({ r.total(forTeam: $0) }).max()
            }.count
            return TeamStats(
                name: teamNames[i],
                total: total,
                avg: avg,
                best: best,
                worst: worst,
                matchCount: matchCount,
                trumpCount: trumpCount,
                trumpWins: trumpWins
            )
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Chart {
                ForEach(dataPoints) { point in
                    LineMark(
                        x: .value("Runde", point.round),
                        y: .value("Punkte", point.score)
                    )
                    .foregroundStyle(by: .value("Team", point.team))

                    PointMark(
                        x: .value("Runde", point.round),
                        y: .value("Punkte", point.score)
                    )
                    .foregroundStyle(by: .value("Team", point.team))
                    .symbolSize(20)
                }

                RuleMark(y: .value("Ziel", targetScore))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text("Ziel: \(targetScore)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
            }
            .chartYScale(domain: .automatic(includesZero: true))
            .chartXAxisLabel("Runde")
            .chartYAxisLabel("Punkte")
            .frame(height: 200)

            // Statistics
            if !runden.isEmpty {
                statsView
            }
        }
    }

    private var statsView: some View {
        VStack(spacing: 8) {
            // Header row
            HStack(spacing: 0) {
                Text("")
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(stats, id: \.name) { s in
                    Text(s.name)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }

            Divider()

            statRow("Ø Runde", values: stats.map { "\($0.avg)" })
            statRow("Beste", values: stats.map { "\($0.best)" })
            statRow("Schwächste", values: stats.map { "\($0.worst)" })
            statRow("Match", values: stats.map { "\($0.matchCount)" })
            statRow("Trumpf", values: stats.map {
                $0.trumpCount > 0 ? "\($0.trumpWins)/\($0.trumpCount)" : "–"
            })
        }
        .padding(.top, 4)
    }

    private func statRow(_ label: String, values: [String]) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                Text(value)
                    .font(.caption)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct TeamStats {
    let name: String
    let total: Int
    let avg: Int
    let best: Int
    let worst: Int
    let matchCount: Int
    let trumpCount: Int
    let trumpWins: Int
}
