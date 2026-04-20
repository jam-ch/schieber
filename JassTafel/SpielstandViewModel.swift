import Combine
import Foundation
import SwiftUI
import SwiftData

@MainActor
final class SpielstandViewModel: ObservableObject {
    private var modelContext: ModelContext?

    let MAX_STICH = 157
    let REQUIRED_SUM = 157
    let MATCH_BONUS = 100

    func setContext(_ context: ModelContext) {
        self.modelContext = context
    }

    func validateStichField(_ value: String) -> String? {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Stich erforderlich"
        }
        guard let v = Int(value) else {
            return "Nur Zahlen erlaubt"
        }
        if v < 0 {
            return "Stich dürfen nicht negativ sein"
        }
        if v > MAX_STICH {
            return "Maximal \(MAX_STICH) Stich erlaubt"
        }
        return nil
    }

    /// Validates a Weis field. Empty is allowed (treated as 0). Must be a non-negative integer.
    func validateWeisField(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        guard let v = Int(trimmed) else {
            return "Nur Zahlen erlaubt"
        }
        if v < 0 {
            return "Weis dürfen nicht negativ sein"
        }
        return nil
    }

    func validateRoundSum(_ stich: [String], teamCount: Int) -> String? {
        let values = stich.prefix(teamCount).compactMap { Int($0) }
        guard values.count == teamCount else { return nil }
        let sum = values.reduce(0, +)
        if sum != REQUIRED_SUM {
            return "Summe muss \(REQUIRED_SUM) Punkte sein (aktuell: \(sum))"
        }
        return nil
    }

    func canAdd(stich: [String], weis: [String], teamCount: Int) -> Bool {
        let activeStich = Array(stich.prefix(teamCount))
        guard activeStich.allSatisfy({ validateStichField($0) == nil }) else { return false }
        let activeWeis = Array(weis.prefix(teamCount))
        guard activeWeis.allSatisfy({ validateWeisField($0) == nil }) else { return false }
        let stichValues = activeStich.compactMap { Int($0) }
        guard stichValues.count == teamCount else { return false }
        return stichValues.reduce(0, +) == REQUIRED_SUM
    }

    @discardableResult
    func addRunde(stich: [String], weis: [String], teamCount: Int, spielart: Spielart, match: Bool = false, trumpTeamIndex: Int = -1) -> Bool {
        guard let ctx = modelContext else { return false }
        let stichValues = stich.prefix(teamCount).compactMap { Int($0) }
        guard stichValues.count == teamCount else { return false }
        guard stichValues.reduce(0, +) == REQUIRED_SUM else { return false }

        let weisValues = (0..<teamCount).map { i -> Int in
            let trimmed = weis[i].trimmingCharacters(in: .whitespacesAndNewlines)
            return Int(trimmed) ?? 0
        }

        let r = Runde(stich: stichValues, weis: weisValues, spielartRaw: spielart.rawValue, teamCount: teamCount)
        r.trumpTeamIndex = trumpTeamIndex
        if match {
            let appliedBonus = MATCH_BONUS * r.faktor
            if let matchIndex = stichValues.firstIndex(where: { $0 == REQUIRED_SUM }) {
                r.setBonus(appliedBonus, forTeam: matchIndex)
            }
        }
        ctx.insert(r)
        return true
    }

    func updateRunde(_ runde: Runde, stich: [Int], weis: [Int], spielart: Spielart, match: Bool = false, trumpTeamIndex: Int = -1) {
        let activeStich = Array(stich.prefix(runde.teamCount))
        guard activeStich.reduce(0, +) == REQUIRED_SUM else { return }

        for i in 0..<runde.teamCount {
            runde.setStich(activeStich[i], forTeam: i)
            runde.setWeis(weis.indices.contains(i) ? weis[i] : 0, forTeam: i)
        }
        runde.spielart = spielart
        runde.trumpTeamIndex = trumpTeamIndex

        for i in 0..<4 {
            runde.setBonus(0, forTeam: i)
        }
        if match {
            let appliedBonus = MATCH_BONUS * runde.faktor
            if let matchIndex = activeStich.firstIndex(where: { $0 == REQUIRED_SUM }) {
                runde.setBonus(appliedBonus, forTeam: matchIndex)
            }
        }
    }

    func delete(runde: Runde) {
        modelContext?.delete(runde)
    }

    func resetAll() {
        guard let ctx = modelContext else { return }
        do {
            let all: [Runde] = try ctx.fetch(FetchDescriptor<Runde>())
            for r in all {
                ctx.delete(r)
            }
        } catch {
            print("resetAll failed: \(error)")
        }
    }

}
