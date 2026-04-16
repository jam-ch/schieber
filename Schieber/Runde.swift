import Foundation
import SwiftData

@Model
final class Runde {
    @Attribute(.unique) var id: UUID = UUID()

    var punkteTeamA: Int
    var punkteTeamB: Int
    var spielartRaw: Int
    var createdAt: Date

    // Optional bonus points (e.g., Match bonus)
    var bonusA: Int = 0
    var bonusB: Int = 0

    init(punkteTeamA: Int, punkteTeamB: Int, spielartRaw: Int, createdAt: Date = Date()) {
        self.punkteTeamA = punkteTeamA
        self.punkteTeamB = punkteTeamB
        self.spielartRaw = spielartRaw
        self.createdAt = createdAt
    }

    var spielart: Spielart {
        get { Spielart(rawValue: spielartRaw) ?? .normal }
        set { spielartRaw = newValue.rawValue }
    }

    var faktor: Int { spielartRaw }
    var totalA: Int { punkteTeamA * faktor + bonusA }
    var totalB: Int { punkteTeamB * faktor + bonusB }
}
