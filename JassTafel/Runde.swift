import Foundation
import SwiftData

@Model
final class Runde {
    @Attribute(.unique) var id: UUID = UUID()

    // Stich (trick points) — must sum to 157 across all teams
    var punkteTeamA: Int
    var punkteTeamB: Int
    var punkteTeamC: Int = 0
    var punkteTeamD: Int = 0

    // Weis (declaration/meld bonuses) — independent per team
    var weisTeamA: Int = 0
    var weisTeamB: Int = 0
    var weisTeamC: Int = 0
    var weisTeamD: Int = 0

    var spielartRaw: Int
    var createdAt: Date
    var teamCount: Int = 2

    // Which team called trump (-1 = not set)
    var trumpTeamIndex: Int = -1

    // Match bonus (stored pre-multiplied)
    var bonusA: Int = 0
    var bonusB: Int = 0
    var bonusC: Int = 0
    var bonusD: Int = 0

    init(punkteTeamA: Int, punkteTeamB: Int, spielartRaw: Int, createdAt: Date = Date()) {
        self.punkteTeamA = punkteTeamA
        self.punkteTeamB = punkteTeamB
        self.spielartRaw = spielartRaw
        self.createdAt = createdAt
    }

    init(stich: [Int], weis: [Int], spielartRaw: Int, teamCount: Int, createdAt: Date = Date()) {
        self.punkteTeamA = stich.indices.contains(0) ? stich[0] : 0
        self.punkteTeamB = stich.indices.contains(1) ? stich[1] : 0
        self.punkteTeamC = stich.indices.contains(2) ? stich[2] : 0
        self.punkteTeamD = stich.indices.contains(3) ? stich[3] : 0
        self.weisTeamA = weis.indices.contains(0) ? weis[0] : 0
        self.weisTeamB = weis.indices.contains(1) ? weis[1] : 0
        self.weisTeamC = weis.indices.contains(2) ? weis[2] : 0
        self.weisTeamD = weis.indices.contains(3) ? weis[3] : 0
        self.spielartRaw = spielartRaw
        self.teamCount = teamCount
        self.createdAt = createdAt
    }

    var spielart: Spielart {
        get { Spielart(rawValue: spielartRaw) ?? .normal }
        set { spielartRaw = newValue.rawValue }
    }

    var faktor: Int { spielartRaw }

    // Total = (Stich + Weis) * Faktor + Match bonus
    var totalA: Int { (punkteTeamA + weisTeamA) * faktor + bonusA }
    var totalB: Int { (punkteTeamB + weisTeamB) * faktor + bonusB }
    var totalC: Int { (punkteTeamC + weisTeamC) * faktor + bonusC }
    var totalD: Int { (punkteTeamD + weisTeamD) * faktor + bonusD }

    // MARK: - Index-based accessors

    func stich(forTeam index: Int) -> Int {
        switch index {
        case 0: return punkteTeamA
        case 1: return punkteTeamB
        case 2: return punkteTeamC
        case 3: return punkteTeamD
        default: return 0
        }
    }

    func setStich(_ value: Int, forTeam index: Int) {
        switch index {
        case 0: punkteTeamA = value
        case 1: punkteTeamB = value
        case 2: punkteTeamC = value
        case 3: punkteTeamD = value
        default: break
        }
    }

    func weis(forTeam index: Int) -> Int {
        switch index {
        case 0: return weisTeamA
        case 1: return weisTeamB
        case 2: return weisTeamC
        case 3: return weisTeamD
        default: return 0
        }
    }

    func setWeis(_ value: Int, forTeam index: Int) {
        switch index {
        case 0: weisTeamA = value
        case 1: weisTeamB = value
        case 2: weisTeamC = value
        case 3: weisTeamD = value
        default: break
        }
    }

    func bonus(forTeam index: Int) -> Int {
        switch index {
        case 0: return bonusA
        case 1: return bonusB
        case 2: return bonusC
        case 3: return bonusD
        default: return 0
        }
    }

    func setBonus(_ value: Int, forTeam index: Int) {
        switch index {
        case 0: bonusA = value
        case 1: bonusB = value
        case 2: bonusC = value
        case 3: bonusD = value
        default: break
        }
    }

    func total(forTeam index: Int) -> Int {
        switch index {
        case 0: return totalA
        case 1: return totalB
        case 2: return totalC
        case 3: return totalD
        default: return 0
        }
    }
}
