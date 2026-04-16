import Foundation
import Combine
import SwiftUI
import SwiftData

@MainActor
final class SpielstandViewModel: ObservableObject {
    private var modelContext: ModelContext?

    let MAX_POINTS = 2500
    let REQUIRED_SUM = 157
    let MATCH_BONUS = 100

    func setContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // Fetch persisted rounds directly in the view model for totals and operations
    @Query(sort: [SortDescriptor(\Runde.createdAt, order: .reverse)])
    private var runden: [Runde]

    var gesamtA: Int { runden.map { $0.totalA }.reduce(0, +) }
    var gesamtB: Int { runden.map { $0.totalB }.reduce(0, +) }

    func validatePunkteField(_ value: String) -> String? {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Punkte erforderlich"
        }
        guard let v = Int(value) else {
            return "Nur Zahlen erlaubt"
        }
        if v < 0 {
            return "Punkte dürfen nicht negativ sein"
        }
        if v > MAX_POINTS {
            return "Maximal \(MAX_POINTS) Punkte erlaubt"
        }
        return nil
    }

    /// Validate that the sum of both teams' raw points equals the required total (157).
    /// Returns an error message when invalid, or nil when OK. If either input isn't a valid Int yet, returns nil (per-field errors handle that).
    func validateRoundSum(_ punkteA: String, _ punkteB: String) -> String? {
        guard let a = Int(punkteA), let b = Int(punkteB) else { return nil }
        let sum = a + b
        if sum != REQUIRED_SUM {
            return "Summe muss \(REQUIRED_SUM) Punkte sein (aktuell: \(sum))"
        }
        return nil
    }

    func canAdd(punkteA: String, punkteB: String) -> Bool {
        // require individual fields valid
        guard validatePunkteField(punkteA) == nil, validatePunkteField(punkteB) == nil else { return false }
        // require parsable ints
        guard let a = Int(punkteA), let b = Int(punkteB) else { return false }
        // require sum equals REQUIRED_SUM
        return a + b == REQUIRED_SUM
    }

    @discardableResult
    func addRunde(punkteA: String, punkteB: String, spielart: Spielart, match: Bool = false) -> Bool {
        guard let ctx = modelContext else { return false }
        guard let a = Int(punkteA), let b = Int(punkteB) else { return false }

        // Enforce sum invariant at insertion time as well
        guard a + b == REQUIRED_SUM else { return false }

        let r = Runde(punkteTeamA: a, punkteTeamB: b, spielartRaw: spielart.rawValue)
        // apply match bonus if requested — bonus to the team whose raw points == REQUIRED_SUM
        if match {
            let factor = r.faktor
            let appliedBonus = MATCH_BONUS * factor
            if a == REQUIRED_SUM {
                r.bonusA = appliedBonus
            } else if b == REQUIRED_SUM {
                r.bonusB = appliedBonus
            }
        }
        ctx.insert(r)
        return true
    }

    func updateRunde(_ runde: Runde, punkteA: Int, punkteB: Int, spielart: Spielart, match: Bool = false) {
        // Optionally enforce sum here as well; caller should validate before calling
        guard punkteA + punkteB == REQUIRED_SUM else { return }
        runde.punkteTeamA = punkteA
        runde.punkteTeamB = punkteB
        runde.spielart = spielart
        // set/reset match bonus as requested
        let factor = runde.faktor
        let appliedBonus = MATCH_BONUS * factor
        if match {
            if punkteA == REQUIRED_SUM {
                runde.bonusA = appliedBonus
                runde.bonusB = 0
            } else if punkteB == REQUIRED_SUM {
                runde.bonusB = appliedBonus
                runde.bonusA = 0
            } else {
                // no team has raw 157 — clear bonuses
                runde.bonusA = 0
                runde.bonusB = 0
            }
        } else {
            // if match flag not set, ensure bonuses are cleared
            runde.bonusA = 0
            runde.bonusB = 0
        }
        // SwiftData observes model changes automatically
    }

    func delete(runde: Runde) {
        modelContext?.delete(runde)
    }

    func resetAll() {
        guard let ctx = modelContext else { return }
        // Fetch all Runde objects from the stored model context and delete them explicitly.
        do {
            let all: [Runde] = try ctx.fetch(FetchDescriptor<Runde>())
            for r in all {
                ctx.delete(r)
            }
        } catch {
            print("resetAll failed: \(error)")
        }
    }

    // Codable DTO for export/import
    private struct RundeDTO: Codable {
        let id: UUID
        let punkteTeamA: Int
        let punkteTeamB: Int
        let bonusA: Int
        let bonusB: Int
        let spielartRaw: Int
        let createdAt: Date
    }

    func exportJSON(to url: URL) throws {
        let dtos = runden.map { RundeDTO(id: $0.id, punkteTeamA: $0.punkteTeamA, punkteTeamB: $0.punkteTeamB, bonusA: $0.bonusA, bonusB: $0.bonusB, spielartRaw: $0.spielartRaw, createdAt: $0.createdAt) }
        let data = try JSONEncoder().encode(dtos)
        try data.write(to: url)
    }

    func importJSON(from url: URL) throws {
        guard let ctx = modelContext else { return }
        let data = try Data(contentsOf: url)
        let dtos = try JSONDecoder().decode([RundeDTO].self, from: data)
        for dto in dtos {
            let r = Runde(punkteTeamA: dto.punkteTeamA, punkteTeamB: dto.punkteTeamB, spielartRaw: dto.spielartRaw, createdAt: dto.createdAt)
            r.bonusA = dto.bonusA
            r.bonusB = dto.bonusB
            ctx.insert(r)
        }
    }
}
