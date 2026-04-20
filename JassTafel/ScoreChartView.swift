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
        // Runden are sorted newest-first; reverse for chronological order
        let chronological = runden.reversed()
        var cumulative = Array(repeating: 0, count: teamCount)
        var points: [ChartDataPoint] = []

        // Start point at 0
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

    var body: some View {
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
    }
}
